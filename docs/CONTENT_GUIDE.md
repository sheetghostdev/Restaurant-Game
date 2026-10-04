# Content guide

Most new content needs no code. Create a resource under `res://resources/`
(in the editor: *New Resource → ItemDef / RecipeDef / ...*) and
`ContentDB` picks it up at startup.

---

## A new ingredient

1. **Item.** `resources/ingredients/cheese.tres` (`ItemDef`):
   * `id = &"cheese"`, `item_class = "food"`, `model = &"cheese"`, a `color`.
   * `tags`: the station tags it works with:
     * `choppable`: needs `chop_into` and `chop_work`
     * `grillable` / `fryable` / `ovenable`: needs a `cook_profile` with `heat`
       set to `grill`, `fryer` or `oven`. Something with an `oven` profile
       can also bake on a plate (the dough under a pizza): the oven accepts
       the whole plate
     * `plateable`: can go on a plate (or into a mug, if a mug recipe uses it)
     * `prepared`: discarded at the end of the day (it doesn't keep)
   * `perishable` and `spoil_seconds`, if it needs cold storage.
   * `made_from`: the raw ingredient it comes from when it isn't chopped
     (coffee from beans, beer from kegs). The menu board crosses that off.
   * `grow_seconds`: if above 0, hydroponic planters in orbit can grow it.
2. **Supply.** `resources/supplies/supply_cheese.tres` (`SupplyDef`): the
   container style (`crate`, `crate_cold`, `sack`, `carton`), the quantity, the
   price and `default_order`.
3. **Model.** Add a case to `ModelsFood.build()` that draws the shape at about
   0.25 m, resting on y = 0. The cheese model already exists.

Add the supply to each restaurant type that should sell it (the format's
`supplies` list). It then appears in the catalog's Supplies tab, arrives on
the truck, is sold at train stops, can be printed in orbit, and shows up in
inventory counts.

Drinks poured by a machine (coffee, soda, beer) are items with a cook profile
(how far the pour has got) and a `CoffeeBrewer` component on the machine:
`product` is what it pours and `refill` is what goes in the hopper.

## A new recipe

`resources/recipes/cheeseburger.tres` (`RecipeDef`):

```
id = &"cheeseburger"
display_name = "Cheeseburger"
container = "plate"                 # or "mug"
required = [&"bun", &"patty", &"cheese"]
optional = [&"lettuce_chopped", &"tomato_sliced"]
price = 13.0
menu_weight = 1.0
eat_time = 12.0
plating = "burger"                  # burger | fries | salad | drink | generic
```

Then add its id to a format's `menu` (`resources/formats/*.tres`).
`DishPlating` stacks burger components in the order listed in `BURGER_ORDER`.

## A new appliance or furniture piece

1. **Model.** Add a builder in `ModelsKitchen` or `ModelsFurniture`. Work in a
   1 × 1 m footprint centred on the origin, with the working face toward +Z.
   Counters are 0.8 m high.
2. **Scene.** `scenes/appliances/oven.tscn`:
   * root `Node3D` with `scripts/fixtures/fixture.gd`
   * a `Model` (`ProceduralModel`) set to your model key
   * `ItemSlot` markers where items sit, with `accept` tags
   * component nodes, for example `Cooker` (heat `oven`), `Flammable`, `Breakable`
3. **Definition.** `resources/equipment/oven.tres` (`FixtureDef`): the scene,
   category, price, `collision_height`, `flammable`, `can_break`, `unlock_day`.

It now shows in the catalog and arrives boxed at the dock. Players place it,
and staff and automation can use it.

If no existing component fits, write a new `FixtureComponent`: implement
`query`, `perform`, `server_tick`, `get_state` and `set_state`, and call
`fixture.mark_dirty()` when its state changes.

## A new customer type

`resources/customers/student.tres` (`CustomerArchetype`) has these fields:
group size, `child_chance`, `patience`, `dishes_min`/`dishes_max`,
`drink_chance`, `recipe_weights` (recipe id → multiplier), `spend`, `tip`,
`eat_speed`, `mess`, `strictness`, `reputation_weight`, `spawn_weight`,
`min_day`, `min_reputation`, `hour_weights` (hour → multiplier, with `-1` as
the default), `outfit_colors` and `accessory` (`hard_hat`, `tie`, `camera`,
`beret`, `backpack`, `bow`, `bowtie`, `scarf`, `glasses`, `jersey`,
`bandana`). Add its id to each format's `archetypes`.

## A new kind of restaurant

`resources/formats/<id>.tres` (`RestaurantFormatDef`):

* `menu`, `open_hour` / `close_hour` (24 means midnight), `hourly_demand`,
  `base_groups`, `archetypes`.
* `stations`: the kitchen equipment, one fixture id per station slot of the
  layout, in order (`counter` for a plain worktop). Every location's layout
  lists the same number of `stations` slots.
* `pantry`: opening stock on the storage shelves (`{"supply", "units"}`, in
  shelf order); `opening`: crates in the free day-one delivery.
* `supplies`: what the supplier sells (empty means everything).
* `food_chance` and `drink_bonus` tune how often guests order food at all and
  how often they add a drink; `extra_mugs` for drink-heavy places.
* `default_name`, `sign_text` (the street sign), `accent` and `tagline` for
  the new-game screen.

It appears on the new-game screen automatically.

## A new event

`resources/events/power_cut.tres` (`EventDef`), with `kind` set to `disaster`
or `inspection`. It is scheduled during service between `params.hour_min` and
`params.hour_max`. For a new behaviour, add a case to `EventManager.trigger()`.
Inspections are announced in the morning forecast via `warning_text`.

## A new expansion

`resources/upgrades/expansion_bakery.tres` (`ExpansionDef`) holds a room type,
a `rect` on the grid, a price, `doors` (each a `Vector4i(ax, az, bx, bz)`
pair of adjacent cells), `starter_fixtures` and `requires`. Add its id to the
location's `expansions`. A plot with a FOR SALE sign appears next to the
building.

## A new room type

`resources/rooms/*.tres` (`RoomTypeDef`) sets the floor style (`planks`,
`tile_checker`, `concrete`, `cold_tile`, `patio`, `loading`, `carpet`, `deck`,
`grate`, or `none` when a theme draws its own floor), the floor and wall
colours, the flags `outdoor`, `cold`, `customer_area` and `has_windows`, plus
a light colour.

## A new location or layout

`data/layouts/<name>.json` uses the same format as the `layout` section of a
save file: `lot`, `rooms`, `openings`, `front_door`, `delivery_zone`,
`street` (customer spawn and exit points, queue start and direction, player
and staff spawns, the truck path, the pole sign), `ground` rectangles, `props`,
`fixtures`, and starting `items`. It also lists the kitchen's `stations`
(`[x, z, rot]` slots the restaurant type fills) and its `pantry` shelves.
Optional looks: `facade` (outside wall colour), `window_step` (a window every
N cells), `ground_style: "space"` (no plinth: a floating hull). Train layouts
add `market_cells` (where stalls set up) and `street.inside_door`.

Point a `LocationDef` at it and set:

* `theme`: `street`, `train` (adds the timetable and sliding platform) or
  `space` (starfield, planet, space lighting).
* `supply_mode`: `truck` (order at the manager's desk), `market` (stalls at
  train stops) or `grow` (planters and the food printer, which are fixtures
  with `only_theme = "space"`).
* `stops` (train station names), `expansions`, `accent`, `tagline`.

Openings of type `train_door` or `airlock` get sliding doors; the train locks
`train_door`s between stations.

---

## Replacing placeholder art

Drop `res://art/models/<key>.tscn` (or a `.res` mesh) and `Models` uses it
instead of the procedural mesh. The key is the same one used by `ItemDef.model`,
`FixtureDef.model` or `ProceduralModel.model_key`. Match the conventions:
items rest on y = 0, and fixtures are 1 × 1 m facing +Z.

## Replacing placeholder audio

Put a `.wav` or `.ogg` with the same name in `res://audio/sfx/` or
`res://audio/music/`. Names ending in `_loop` should loop seamlessly. The three
music stems must share length and tempo. To rebuild the placeholders, run
`python3 tools/audio/generate_audio.py` (it needs numpy, scipy and ffmpeg).

## Regenerating the default content

`godot --headless --path . res://tools/dev/content_seed.tscn` rewrites the
default `.tres` set from `tools/dev/content_seed.gd`. It overwrites edits made
in the inspector, so commit first.
