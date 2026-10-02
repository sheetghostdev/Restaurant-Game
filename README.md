# Mise en Chaos

*A cooperative restaurant-logistics game for 1–6 players, built in Godot 4.*

> Build it. Stock it. Somehow keep it running.

You and your friends run a small diner on Main Street. You aren't just cooking.
You also unload the morning delivery truck, keep the beef in the fridge before
it spoils, prep lettuce before the lunch rush, wash the plates you'll run out
of, put out grease fires, knock walls through and haul new equipment in from
the loading dock. You can hire staff and build conveyor lines. Over time the
little diner grows into a logistics machine you designed yourselves, and the
building shows every decision you made, good or bad.

The game is a polished vertical slice with an architecture meant to keep
growing: content is data, every system is network-ready, and a headless test
plays through a whole day.

---

## Running the game

* **Engine:** Godot **4.3 or newer** (tested on 4.3-stable and 4.7.2-stable).
  Standard build, no C#.
* Open `project.godot` in the editor and press **Play**, or run
  `godot --path .` from the repo root.
* Renderer: Forward+ (soft shadows, SSAO, tilt-shift depth of field). The
  Compatibility renderer also works, with fewer effects.

Command-line shortcuts, for development:

| Argument | Effect |
|---|---|
| `-- --autostart` | Skip the menu and start a new offline game |
| `-- --host` | Host an online game immediately |
| `-- --join 1.2.3.4` | Join a host |
| `-- --coop-test` | Start with two local keyboard players |

---

## Controls

All verbs are contextual. **GRAB** moves things and **USE** operates things.

| | Keyboard A | Keyboard B | Gamepad |
|---|---|---|---|
| Move | WASD (or arrows when solo) | Arrows | Left stick / D-pad |
| Grab / place / drop | Space | Enter | A |
| Use (chop, wash, take one, repair, spray) | E or F | Right Shift | X / RT |
| Rotate (build) / ping | Q | / | Y |
| Sprint | Shift | Right Ctrl | B / LT / LB |
| Pause | Esc | | Start |

* **Hold GRAB** on furniture or an appliance during a calm phase (morning or
  evening) to pick it up. Q rotates it, GRAB places it.
* **USE on a crate** takes one ingredient out. **GRAB** picks up the whole crate.
* **Tab** toggles the full-restaurant view. **+/–** or the mouse wheel zooms.
  **F5** quick-saves. **F1** opens the debug panel.
* **Local co-op:** press **Enter** to add a second keyboard player, or **A** on
  any gamepad to join, at any time during a game.

---

## How a day works

```
MORNING PREP (calm, untimed)
  The delivery truck reverses to the loading dock and drops your standing order.
  Carry crates inside (cold stock goes in the fridge), chop, arrange, plan.
  The forecast card shows expected guests, rush hours and special events.
        ↓  hold USE on the OPEN sign
SERVICE (timed, 11am–9pm in about 7 minutes)
  Guests queue outside, get seated, read the menu, wave for you to take their
  order, wait (patience shown on faces, bubbles and tickets), eat, pay and
  leave dirty plates and crumbs behind. Lunch and dinner rushes are predictable.
        ↓  9pm: doors close
CLOSING
  Finish the last tables and clean up. Hold USE on the sign to end the day.
        ↓
RESULTS
  Revenue, expenses, profit, guests served or lost, satisfaction, reputation,
  ingredient usage and waste.
        ↓
EVENING (calm, build mode)
  Buy equipment (it arrives boxed at the dock), hire staff, set tomorrow's
  standing order, build expansions at the FOR SALE signs, knock doorways
  through walls, and rearrange.
        ↓  hold USE on the sign: lights out → next morning (autosave)
```

### Recipes in the diner

| Dish | How |
|---|---|
| **Classic Burger** | Grill a patty to *Medium*; plate it with a bun. Lettuce and tomato are optional extras |
| **Garden Deluxe** (day 2+) | Bun + patty + chopped lettuce + tomato slices |
| **Crispy Fries** | Chop a potato, fry until *Crispy*, plate |
| **Garden Salad** | Chopped lettuce + tomato slices on a plate |
| **Coffee** | Put a clean mug under the machine (keep the bean hopper filled) |

Cooking passes through readable stages: raw → rare → **medium** → well done →
overcooked → burnt, then fire. You can read the stage from colour, steam and
smoke, a chime, and a ring with a marked perfect zone. Customers refuse raw,
burnt or spoiled food.

---

## Features in this build

* **Physical inventory.** Ingredients arrive in crates, sacks and cartons, and
  you can see every unit inside them. Beef and lettuce spoil outside cold
  storage. Low-stock alerts work from the actual crates.
* **Deliveries and logistics.** A delivery truck reverses to the dock every
  morning, and crates land as obstacles. Rush orders and equipment come by van,
  sometimes mid-service. The driver takes empty crates left on the dock.
* **Finite dishware.** Plates and mugs get dirty and must go through the sink
  or the hood dishwasher. If nobody washes up, you can't serve anything.
* **Customers.** Eight archetypes (townsfolk, families, work crews, business
  lunches, dates, tourists, tired travelers, food critics), each with different
  group size, appetite, patience, timing, spending and mess. Groups seat
  themselves at table clusters (push tables together for bigger groups),
  order, eat, pay and tip based on quality and speed.
* **Disasters.** Grease fires that spread and need the extinguisher, dishwasher,
  fridge and appliance breakdowns, pipe leaks that make the floor slippery,
  conveyor jams, health inspections, surprise deliveries, and crowd events
  (office lunch, street festival, big game, rainy day).
* **Build mode.** Move and rotate any fixture on a grid, knock doorways through
  walls or wall them up, and buy expansions: Dining Annex, Dish Room, Walk-in
  Cooler (everything inside stays fresh) and Sidewalk Patio.
* **Staff.** A Dish Hand, Busser, Stocker and Waiter. They follow simple,
  predictable routines through the same interaction rules as players.
* **Automation.** Conveyor belts, grabber arms (which pull single units out of
  crates) and an auto-chopper. Chain them into visible production lines.
* **Multiplayer.** Up to 6 players: local co-op with keyboards and gamepads,
  online over ENet (host/join), or a mix. The server is authoritative and
  supports late join.
* **Persistence.** One restaurant persists across days in versioned JSON saves,
  with an autosave every morning. Failure costs you reputation, stock and money
  but doesn't wipe the restaurant.
* **Presentation.** Procedural low-poly miniature-diorama art: chamfered model
  pieces, baked AO, a display plinth, a cutaway building with "section cut"
  wall caps, tilt-shift blur, and lighting that follows the time of day. There
  is layered adaptive music (prep → service → rush) and 60+ sound effects.
* **Debug panel (F1).** Spawn customers or deliveries, add money, advance time,
  start or end service, trigger disasters, show the nav grid and AI states,
  reset the restaurant.

---

## Project layout

```
res://
  scenes/            main, world, player, appliances/, furniture/, automation/
  scripts/
    core/            GameWorld (entity registry, session), Entity, EventBus, ContentDB, Main
    systems/         Day, Economy, Orders, Customers, Deliveries, Build, Events,
                     Staff, Inventory, Recipes, Audio, Saves, Settings, FX
    networking/      Net (ENet + RPC endpoints), Replicator
    interaction/     InteractionSystem, Interact rules, ItemSlot
    items/           Item, FoodItem, DishItem, CrateItem, ToolItem, PackageItem
    fixtures/        Fixture + components/ (Cooker, Processor, Sink, Dishwasher, ...)
    ai/              Customer, CustomerGroup, Worker, StaffBrain, GridNav
    player/          PlayerCharacter, input devices (local co-op)
    restaurant/      RestaurantGrid (rooms/walls/doors as data), RestaurantBuilder
    art/             MeshBuilder, Models library, CharacterRig, palette
    ui/              HUD, catalog, results, menus, theme, icon renderer
    resources/       Resource classes (ItemDef, RecipeDef, FixtureDef, ...)
  resources/         All game content as .tres (ingredients, recipes, equipment,
                     customers, events, staff, upgrades/expansions, rooms, formats, locations)
  data/layouts/      Starting restaurant layouts (same format as saves)
  shaders/           Diorama material, highlight, ghost, sky, water
  audio/             sfx/*.wav, music/*.ogg (procedurally generated placeholders)
  art/               fonts (OFL), models/ (drop-in overrides for procedural meshes)
  tests/             Headless gameplay test, two-process network test
  tools/             Content seed, screenshot runner, script checker, audio generator
  docs/              Architecture, design and content guides
```

More detail:

* [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): entities, authority and
  replication, the interaction protocol, components, saves.
* [`docs/DESIGN.md`](docs/DESIGN.md): pillars, how this differs from the genre,
  system design, roadmap.
* [`docs/CONTENT_GUIDE.md`](docs/CONTENT_GUIDE.md): adding recipes, ingredients,
  equipment, customers, events, expansions, art and audio.

---

## Testing

```bash
# Full-day gameplay test: delivery, prep, cooking, plating, customers, washing,
# build mode, disasters, staff, automation, spoilage, closing, results,
# expansion, save/load (95 checks).
godot --headless --path . res://tests/test_runner.tscn

# Network test: one host process and one client process on localhost.
godot --headless --path . res://tests/net_test.tscn -- --net-host &
godot --headless --path . res://tests/net_test.tscn -- --net-client

# Compile every script.
godot --headless --path . res://tools/dev/check_all.tscn

# Screenshots of staged scenarios (needs a display or Xvfb).
godot --path . res://tools/dev/shot_runner.tscn -- --shot=out.png --scenario=dining
```

Run `godot --headless --path . --import` once before the first headless run, so
Godot builds its class cache and imports the assets.

---

## Credits and licenses

* Code, procedural models, shaders and generated audio: original to this project.
* Fonts: **Alfa Slab One** (JM Solé) and **Rubik** (The Rubik Project Authors),
  both under the SIL Open Font License 1.1. See `art/fonts/OFL-*.txt`.
* Audio is synthesized by `tools/audio/generate_audio.py` (numpy + ffmpeg). The
  files are placeholders meant to be replaced by recordings under the same names.
