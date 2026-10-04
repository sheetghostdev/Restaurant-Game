# Design

## The fantasy

> "We built this restaurant ourselves, we organised it ourselves, and now we
> have to somehow keep it running."

The game isn't about cooking fast. It's about running a physical place
together: stock, storage, layout, staff, machines and the occasional
catastrophe. Stories should come from systems colliding, not from scripted
jokes. Somebody shouts "we're out of potatoes!". Plates sit on the pass with
nobody looking. Delivery boxes block the hallway. The grill catches fire
during the dinner rush.

### Pillars

Cooperative chaos · physical inventory · restaurant building · logistics ·
food preparation · automation · visual restaurant growth · readable low-poly
art · responsive controls · emergent multiplayer stories.

---

## How this differs from the genre

The genre gives us the broad idea: cooperative restaurant management. These
are deliberate departures from it:

| Area | This game |
|---|---|
| Ingredients | No infinite dispensers. Every unit sits in a crate you can see, came off a truck, and can spoil. |
| Logistics | Deliveries arrive on a timetable and as physical obstacles. Storage location matters (cold vs. warm). Empty crates are clutter. |
| Day structure | An untimed prep phase with a demand forecast, then a timed service, then an evening build phase. |
| Progression | One persistent restaurant that grows physically: rooms, doorways, layouts, staff, machines. Failure costs reputation and stock, not the whole run. |
| Purchases | A supplier catalog at the manager's desk. Equipment arrives boxed at the loading dock and you carry it into place. No card drafting. |
| Customers | Archetypes with real operational differences in size, timing, appetite, spend, mess and strictness, plus visible queues outside and seating clusters you can build. |
| Look | A miniature diorama: a model on a display plinth, cutaway walls with section-cut caps, tilt-shift blur, chamfered block characters (no bean shapes), and a warm terracotta/teal/cream palette with saturated food. |
| UI | Warm paper cards with ink outlines and slab-serif headings. The restaurant itself carries most of the information. |

---

## Core loop

```
MORNING PREP → (truck) → unload & organise → prep → arrange → OPEN
→ SERVICE (waves) → CLOSE → clean → RESULTS → EVENING: buy / expand / automate → next day
```

**Morning prep** is calm and untimed, and the sign is the only way to start
service. The tension comes from information: the forecast card shows expected
groups, rush hours and special events. Prepared food doesn't keep overnight,
so over-prepping is waste and under-prepping is panic.

**Service** compresses 11am–9pm into about seven real minutes. Demand follows a
curve per format with lunch and dinner rushes. The day's groups are shared out
by that curve, so the rushes are always the busy hours; only arrival minutes
and who turns up vary. Archetypes have their own hour preferences. Work crews
come at lunch, dates in the evening, tourists in the afternoon.

**Closing and results** come next. The doors close at 9pm, so the people in
the queue leave and the seated tables finish. The ledger shows revenue,
expenses, satisfaction, reputation change, ingredients used and waste.

In the **evening** you plan. Build mode is open, the catalog sells
equipment, staff, supplies and upgrades, and the FOR SALE plots around the
building are available.

---

## Systems

### Physical inventory and freshness
* Supplies are crates, cold tubs, sacks and cartons holding 4–12 units. The
  units are rendered inside, so stock levels can be seen at a glance.
* GRAB moves the whole container. USE takes one unit out, and you can put an
  untouched unit back.
* Perishables (beef, lettuce, tomatoes) have a freshness timer that only runs
  outside cold storage. Cold storage means a working fridge slot or anything
  inside a walk-in cooler room. A fridge failure makes this urgent.
* `InventoryManager` counts units in crates and alerts on low stock using
  thresholds set per supply.

### Deliveries
* Each morning the truck brings exactly what was ordered in the catalog: a
  quantity per supply, either one-off or marked *Auto* to repeat every day.
  Nothing arrives that nobody ordered. It is paid on delivery; day one brings
  a free opening stock.
* Rush orders cost 50% more and arrive by van in about 20 seconds. Equipment
  also comes by van.
* Crates drop onto marked dock pads and spill onto the floor nearby when the
  pads are full. They block movement until somebody hauls them in.
* The driver takes empty crates left in the loading area, for a deposit.

### Places and their supply chains

Where the restaurant is changes how ingredients reach the kitchen, which
changes the whole rhythm of a day:

* **Main Street: plan ahead.** Order tomorrow's crates in the evening. The
  skill is forecasting.
* **Dining Car Express: shop on the clock.** There is no truck. The depot
  market is open all morning, and during service the train stops three times
  for about 40 seconds. Each stop sells a few things, one of them at a
  discount, so you buy what's cheap and what you're about to run out of,
  then sprint back before the whistle. What's left on the platform stays
  there. Between stops the doors are locked: you're on your own. Passengers
  board at every stop, so stops are also mini-rushes.
* **Orbital Galley: grow and print.** Nothing is delivered. Planters grow
  vegetables for free but slowly and only a few at a time; the food printer
  makes anything, one portion every few seconds, for credits. The tension is
  free-but-slow versus fast-but-costly, and choosing crops for the day's menu.

### Kinds of restaurant

The diner, coffee shop, pizza parlor and bar share every system but play
differently: the coffee shop is many tiny, quick drink orders and a sharp
early rush; the pizza parlor is assembly (build on the plate, bake the whole
plate) with big evening tables; the bar is pours that must be taken at the
right moment, kegs to swap and late-night crowds. Each has its own regulars,
hours and starting kitchen.

### Cooking, quality and recipes
* `CookProfile` defines stages, quality per stage, colour per stage, a perfect
  stage, a smoke threshold and a fire threshold. Feedback is colour, steam, a
  ding on perfect, smoke and crackle when overcooking, and a ring indicator
  with the perfect zone marked. There is no precise meter to stare at.
* Chopping is held work (Processor). Grilling, frying and brewing are passive
  (Cooker, CoffeeBrewer).
* Plates match recipes by their contents, where
  required ⊆ contents ⊆ required ∪ optional. The recipe with the most required
  items wins. You can only add an ingredient if some recipe can still be
  completed.
* Every order names its extras (burger + tomato, no lettuce), each adding to
  the price. A dish with the wrong extras is still accepted but costs
  satisfaction; tickets show the extras as pictures, unwanted ones crossed
  out.
* The menu board crosses raw ingredients off (tomato covers sliced tomato,
  potato covers fries). Dishes that need them leave the menu and they are
  never asked for as extras. Guests who wanted them lose some satisfaction
  (less for an extra than for a whole dish).
* A customer refuses a dish that is raw, burnt or spoiled (quality 0). Above
  that, satisfaction = quality × 0.65 + remaining patience × 0.35 − strictness.
  Tips scale with satisfaction squared.

### Customers
* Groups arrive by schedule, walk to a physical queue outside the front door,
  and balk if the line is too long.
* They seat themselves at the smallest free cluster that fits. A cluster is a
  set of connected tables plus the chairs facing them, so players can build
  big family tables.
* Flow: browse, then wave for service (a player or waiter takes the order),
  then wait (tickets show the table number and patience), then eat, pay, tip,
  and leave plates, crumbs and sometimes spills.
* Patience appears on faces (mouth and brows), as steam when angry, in thought
  bubbles that show the actual 3D dish, and as ticket bars. Decor in customer
  areas adds patience.
* Reputation changes with every group. It drives volume, unlocks archetypes
  (critics from 2.5★) and multiplies tips through satisfaction.

### Dishes
Plates and mugs are finite. They go dirty on the table and get cleared in
stacks. Then they are hand-washed in the sink (hold USE per dish) or run
through the hood dishwasher, which takes up to 10 dishes, auto-starts when
full, and sometimes breaks. Clean dishes go back on the racks.

### Disasters
Disasters are rolled each morning, so they stay occasional. Nothing outside
the restaurant changes demand (no festivals or weather): it keeps the day
readable.
* **Grease fire.** A random cooker ignites, or food left too long on heat
  catches. The fire spreads to flammable neighbours every 10 seconds and wrecks
  the equipment after about 28 seconds. Grab the extinguisher (it refills on
  its stand) and spray.
* **Breakdowns.** The dishwasher, the fridge or an appliance stops working.
  Hold USE to repair it.
* **Pipe leak.** Puddles make the floor slippery and change movement
  physics. Mop them up.
* **Conveyor jam.** Automation stops until someone clears it.
* **Health inspection.** In 25 seconds the inspector grades mess, dirty
  tables, full bins and spoiled stock. The result is a reputation change or a
  fine.

### Staff
Employees use the same interaction protocol as players, at roughly 60–80%
speed, with predictable routines. NPCs handle the repetitive work so players
can handle the chaos.
* **Dish Hand:** washes, runs and unloads the dishwasher, puts dishes away.
* **Busser:** clears dirty tables, wipes crumbs, drops dishes at the sink or
  dishwasher.
* **Stocker:** carries delivered crates to shelves, cold stock first.
* **Waiter:** takes orders as soon as tables are ready, and buses in between.

### Automation
Conveyors push items into the fixture they face. Grabbers move one item from
behind to the front, and pull single units out of crates. The auto-chopper
preps slowly without hands. They all use the same insertion rules as players
(`Automation.try_insert/try_extract`), so a line reads like a sentence:
*shelf → grabber → auto-chopper → conveyor → pass counter.*

### Build mode
In calm phases, hold GRAB to lift any fixture. Carry it with a green or red
ghost preview showing where it will land, rotate with ALT, and place on the
grid. Placement never blocks a doorway or the dock pads. Wall handles let you
knock doorways through or wall them up. Expansions are rooms bought at plots
next to the building. They add walls automatically, open doorways, and move
any fixture that blocks a new door.

### Difficulty
Three presets in Settings, defined in one table in `scripts/core/difficulty.gd`.
Systems on the host multiply their base numbers by the preset's factors:
guest patience, groups per day, how fast food goes from perfect to burnt (and
coffee to overflowing), disaster chance, reputation lost for unhappy guests,
and how long perishables last. *Relaxed* also has no disasters before day 3,
*Normal* none before day 2. *Hectic* is the raw tuning.

---

## Art direction

* A miniature model on a display plinth, viewed from about 54° with a
  telephoto-ish FOV and a subtle tilt-shift blur.
* Chamfered, slightly angular pieces: thick doors, oversized handles, chunky
  knobs, exaggerated burners. Shapes read before textures do; there are no
  textures at all.
* Architecture and furniture use calm colours (cream plaster, oak, sage and
  cream tiles, teal facade, walnut trim). Food and player colours are the most
  saturated things on screen.
* Characters are about 70% human and 30% cartoon: a larger angular head,
  short torso, stubby legs and mitten hands. Each player has a dominant colour
  on apron, hat, shoes, floor ring and name tag.
* Lighting is time-of-day keyed: soft morning, bright noon, golden late
  afternoon, then a blue evening with glowing windows and street lamps. Room
  lights keep interiors readable.

## Audio direction

Music is three synchronised stems. *Base* plays alone during prep, *groove*
joins for service, and *rush* is added at rush hour. Separate tracks cover
closing and the menu. Sounds carry information: a ding means perfect, a
crackle means burning, the alarm means fire, the reverse beeper means a
delivery, and a grumble means someone is unhappy. The crowd murmur swells with
the number of guests.

---

## Roadmap (beyond the vertical slice)

* **More formats:** Food Truck (one cramped room), Stadium Stand (huge
  short rushes), takeout and delivery for the pizza parlor.
* **More locations:** beach shack, ski lodge, a riverboat. Each is a layout
  JSON plus a `LocationDef`; the train and space station show how a theme
  node can add its own rules.
* **Train extras:** a second dining car, a lounge car, stations with
  special events (a market festival, a delayed departure).
* **Space extras:** micrometeor hull breaches, low-gravity mess, a cargo
  shuttle you can call in for a price.
* **Regulars** with persistent identities and favourite orders.
* **Counter service and takeout:** order at a register, pickup shelf.
* **Bigger automation:** dish-return belts, dumbwaiters for upstairs seating,
  ingredient chutes from the loading dock.
* **Upstairs and rooftop seating** (multi-level grid).
* **Cosmetics** unlocked through progression.
* **Restrooms** (and the clogged-toilet disaster).
* **Hardcore mode:** roguelike runs on top of the persistent restaurant.
