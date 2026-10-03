# Architecture

This document explains how the game is put together, so new systems can be
added without rewriting the core. The short version:

1. **Everything in the world is an entity** with a `net_id`. It can serialise
   its state, and it is spawned through one function.
2. **Only the authority mutates gameplay state.** In offline play and on a host
   that is the local machine; on a client it is the server. Clients render
   replicated state.
3. **Players, staff and machines interact through one protocol.** The two verbs,
   GRAB and USE, run through the same rules for all of them.
4. **Content is data.** Recipes, ingredients, equipment, customers, events,
   rooms, staff and expansions are `.tres` resources, and layouts are JSON.

---

## Scene tree at runtime

```
Main (scripts/core/main.gd)             menu ↔ game, offline/host/join
└── GameWorld (scenes/world/game_world.tscn)
    ├── Lighting       LightingRig: sun, sky, environment, time-of-day keys
    ├── Builder        RestaurantBuilder: plinth, floors, walls, doors, props, room lights
    ├── Fixtures       all Fixture entities (grid-placed)
    ├── Items          loose items on the floor (items in slots live under their slot)
    ├── Actors         players, customers, staff
    ├── Effects        messes, trucks, plots, particles, ambience, wall handles
    ├── Limbo          hidden parking spot for detached items
    ├── Camera         DioramaCamera
    ├── Systems/       managers (see below)
    └── UI/HUD         HUD and its modal screens
```

Autoloads: `Events` (signal bus), `Content` (ContentDB), `Settings`, `Inputs`
(local co-op devices), `Net` (multiplayer), `Audio`, `Saves`.

### Managers (`GameWorld/Systems`)

| Node | Class | Owns |
|---|---|---|
| Grid | `RestaurantGrid` | rooms, openings, walls (derived), fixture occupancy, `GridNav` |
| Day | `DayManager` | phases, clock, daily stats, results |
| Economy | `EconomyManager` | money, reputation, ledger |
| Orders | `OrderManager` | active tickets (replicated as a compact list) |
| Customers | `CustomerManager` | arrival schedule, queue, table clusters, seating |
| Deliveries | `DeliveryManager` | supply orders (one-off / auto), rush orders, packages, trucks |
| Build | `BuildManager` | lifting and placing, unpacking, purchases, expansions, wall edits |
| Disasters | `EventManager` | daily events, fires, mess, hand tools, inspections |
| Staff | `StaffManager` | hiring, wages |
| Inventory | `InventoryManager` | stock counts from crates, low-stock alerts |
| Interaction | `InteractionSystem` | targeting, hints, highlights, button handling |
| Replicator | `Replicator` | spawn, despawn, state, motion and shared channels |
| FX | `FeedbackFX` | particles, popups, coins, pings (mirrored to clients) |

Managers hold state that has no physical home: the schedule, money, the
ledger. Anything with a place in the world is an entity, and its behaviour
lives on the entity or its components. "Is the grill cooking?" is answered
by the grill, not by a manager.

---

## Entities

`Entity` (Node3D) is the base for items, fixtures, customers, staff, messes,
trucks and expansion plots. `PlayerCharacter` (a CharacterBody3D) implements
the same interface by duck typing:

```gdscript
var net_id: int                      # assigned by GameWorld
var def_id: StringName               # which data definition it came from
func get_kind() -> StringName        # "item", "fixture", "customer", ...
func get_state() -> Dictionary       # replicated + saved state
func set_state(d: Dictionary)
func get_location() -> Dictionary    # slot ref, floor position or grid cell
func set_location(d: Dictionary)
func server_tick(delta)              # authority only, called by GameWorld
func mark_dirty()                    # "my state changed, replicate me"
```

All creation goes through `GameWorld.spawn_entity(kind, def_id, state, loc, id)`.
Gameplay, save loading and network replication use this same function, so a
save file and a late-join snapshot have the same format: a list of
`{k, id, def, st, loc}` records.

### Items and slots

* An `Item` is held by exactly one `ItemSlot`, lies loose on the floor, or sits
  in limbo. Slots are markers on fixtures (counter tops, grill plates, shelves,
  table settings) and the actor's hands. Moving an item reparents it.
* An item's location is `{"slot": [owner_net_id, slot_index]}` or
  `{"floor": [x, y, z, yaw]}`. Clients resolve it with `GameWorld.place_item`.
* Item classes: `FoodItem` (cook and chop progress), `DishItem` (plate or mug,
  contents, stacks, dirty flag), `CrateItem` (supply plus unit count, spoilage),
  `ToolItem` (extinguisher, mop), `PackageItem` (boxed fixture), `TrashItem`.
* Food placed on a dish is absorbed into the dish's `contents` array; it is no
  longer an entity. Recipes match against that array (see `RecipeManager`).

### Fixtures and components

A fixture scene is a `Fixture` root with three kinds of child:

* `ProceduralModel` nodes, which show a mesh from the `Models` library.
* `ItemSlot` markers.
* `FixtureComponent` nodes, which are the behaviour.

```
Grill (Fixture)
├── Model (ProceduralModel "grill")
├── Glow  (ProceduralModel "grill_glow")
├── Slot  (ItemSlot accept=["grillable"])
├── Flammable   ← blocks everything while burning
├── Breakable   ← USE repairs while broken
└── Cooker      ← heat="grill", passive cooking, ding/smoke/fire
```

Components implement `query(actor, verb)`, `perform(actor, verb, delta)`,
`server_tick`, `get_state`/`set_state`, `blocks_interaction()`,
`blocks_function()` and `status_text()`. The fixture asks components in tree
order and falls back to default slot behaviour. Behaviours are reusable:
`Processor` serves both the manual cutting board and the auto-chopper.

Components shipped: Cooker, Processor, Breakable, Flammable, Sink, Dishwasher,
DishRack, TrashBin (also the dumpster), CoffeeBrewer, Conveyor, Grabber,
FridgeDoor, SeatingTable, Chair, OpenSign, Terminal, ToolRack.

---

## The interaction protocol

`InteractionSystem` picks a target for each player every physics frame:

* Candidates are fixtures within two cells, nearby loose items, and anything
  in the `interactables` group (expansion signs, wall handles).
* Each candidate is scored by its distance to a probe point in front of the
  player, with targets behind the player rejected. Candidates that can accept
  the current action get a bonus. This is what makes targeting forgiving.

Verbs:

| Verb | Meaning |
|---|---|
| GRAB | pick up, put down, combine (food onto a plate, plate onto food, stack dishes, return to crate) |
| USE  | operate: chop, wash, repair, take one from a crate, take an order, wipe, start a machine, flip the sign |
| hold GRAB | lift a fixture (calm phases only) |
| ALT  | rotate a carried fixture, or ping |

`Interact` holds the shared rules: `grab_slot_query/perform` and
`grab_item_query/perform`. `Automation.try_insert/try_extract` applies the
same rules for conveyors and grabbers. `Worker` (staff) calls the same
`interact_query/interact_perform` as players, so automation and NPCs can never
do something a person couldn't.

Queries return `{label, hold, progress, anim, blocked}`. The HUD shows the
label as a hint, `hold` actions run every frame while USE is held, and `anim`
drives the procedural character animation.

---

## Authority and replication

```
               client                                  server
 local input ──► PlayerCharacter (moves locally)
              ├─ _c_motion  (unreliable, 30 Hz) ────►  remote player position
              └─ _c_buttons (reliable, on change) ──►  set_input → InteractionSystem
                                                        ↓ gameplay mutates state
              ◄── _s_spawn / _s_despawn (reliable, every frame)
              ◄── _s_state  (reliable, 15 Hz, dirty entities: [id, state, location])
              ◄── _s_motion (unreliable, 20 Hz, players/customers/staff/vehicles)
              ◄── _s_shared (reliable, manager state: day, economy, orders, layout...)
              ◄── _s_fx / _s_sfx / _s_toast (effects mirrored from authority code paths)
```

* `Net.is_authority()` is true offline (Godot's OfflineMultiplayerPeer) and on
  the host, so single player, local co-op and online all run the same code.
* Effects called from authority-only code paths (perform, tick) are mirrored.
  Effects driven by `_process`, which runs on every peer, pass `local = true`.
* Late join: when a client says hello, the host sends `_s_world_init` (location,
  format, layout), a full snapshot of entity records, and every published
  shared state. Then it spawns the client's player.
* Clients move their own player locally (client-authoritative movement, which
  is acceptable for co-op) and send button states. Interactions always run on
  the server.

Tested by `tests/net_test.tscn`: one host and one client process. The client
checks entity parity, players, phase, money, items held by the host, customer
movement, and a grab performed by the client itself.

---

## Local co-op input

Godot's InputMap merges all devices, so `Inputs` polls devices directly:
keyboard scheme A (WASD), keyboard scheme B (arrows), and every gamepad.
`device_join_requested` fires on Enter or a gamepad's A button; `GameWorld`
then spawns a player bound to that device. UI actions (pause, debug, zoom)
still use InputMap actions, registered at startup.

---

## Content pipeline

`Content` (ContentDB) scans `res://resources/**` at startup and indexes every
resource by class:

| Class | Folder | Examples |
|---|---|---|
| `ItemDef` (+ `CookProfile`) | ingredients/ | patty, lettuce, fries, coffee |
| `SupplyDef` | supplies/ | beef tub ×12, potato sack ×10 |
| `RecipeDef` | recipes/ | burger, deluxe, fries, salad, coffee |
| `FixtureDef` | equipment/ | grill, conveyor, table (points at a scene) |
| `CustomerArchetype` | customers/ | family, work crew, critic |
| `EventDef` | events/ | grease fire, power cut, inspection |
| `ExpansionDef`, `UpgradeDef` | upgrades/ | walk-in cooler, extra plates |
| `StaffDef` | staff/ | dish hand, busser, stocker, waiter |
| `RoomTypeDef` | rooms/ | dining (planks), kitchen (checker), cooler (cold) |
| `RestaurantFormatDef` | formats/ | diner: menu, hours, demand curve |
| `LocationDef` | locations/ | main street: layout JSON, expansions |

`tools/dev/content_seed.gd` can regenerate the default set. After the first
generation the `.tres` files are the source of truth; edit them in the
inspector.

---

## Rendering and art pipeline

* `MeshBuilder` generates flat-shaded low-poly geometry: chamfered boxes,
  prisms, frustums, icospheres, extrusions and wavy discs, with optional
  deterministic "handmade" jitter. It bakes ambient occlusion into vertex alpha.
* `Models` caches one mesh per key. Builders live in `ModelsFood`,
  `ModelsKitchen`, `ModelsFurniture` and `ModelsProps`. A file at
  `res://art/models/<key>.tscn` or `.res` overrides the procedural version, so
  authored art can replace placeholders one model at a time.
* Nearly everything shares one `diorama.gdshader` material. Per-instance
  uniforms (`mult`, `tint`, `flash`) recolour cooking food, spoiled stock and
  feedback without breaking batching.
* `RestaurantBuilder` derives walls from room data. Walls facing the camera are
  cut low, back and side walls stand tall with a dark section-cut cap, and
  windows, door frames and swing doors are generated where they belong.
* `CharacterRig` builds people from blocks and animates them procedurally:
  walk, carry, chop, scrub, repair, wipe, spray, sit, eat, wave, cheer, upset,
  and facial mood.
* `IconRenderer` renders the real 3D models into textures for tickets and the
  catalog.

---

## Saves

`Saves` writes `user://saves/restaurant.json`:

```json
{
  "version": 1,
  "meta": {"name", "location", "format", "day", "money", "reputation", "saved_at"},
  "layout": {rooms, openings, front_door, delivery_zone, street, built_expansions},
  "entities": [{"k": "fixture", "id": 12, "def": "grill", "st": {...}, "loc": {"cell": [10, 0], "rot": 0}}, ...],
  "economy": {...}, "deliveries": {"order", "auto", "pending"}, "staff": {}, "build": {"upgrades"},
  "day": {"day": 3}, "unlocks": []
}
```

Customers, trucks and players are not saved. The game autosaves each morning,
before the restaurant opens, so the dining room is empty. `Saves.migrate()`
upgrades older versions step by step; bump `GameConst.SAVE_VERSION` and add a
step when the format changes.

---

## Adding a new system: checklist

1. Does it have a physical home? Make it an entity or a fixture component.
   Otherwise add a manager under `Systems/` and reach it via `world.<name>`.
2. Mutate state only when `Net.is_authority()` is true. Call `mark_dirty()` on
   entities, or `world.replicator.publish(key, data)` for manager state, and
   handle that key in `Replicator.apply_shared`.
3. Persist it: entity state is automatic. For a manager, add `save_data` and
   `load_data` and wire them into `GameWorld.make_save` and `load_save`.
4. Add a check to `tests/test_runner.gd`.
