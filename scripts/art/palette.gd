class_name Pal
## The game's colour language. All authored in sRGB.
## Architecture and furniture use calm, warm tones so that food,
## interactive objects and player colours read clearly on top.

# --- Architecture -----------------------------------------------------------
const PLASTER := Color("f2e6d3")
const PLASTER_SHADE := Color("e3d3bb")
const BASEBOARD := Color("8a5a3f")
const WALL_CAP := Color("3a302b")
const FACADE := Color("2f7f7a")        # exterior siding (deep teal)
const FACADE_TRIM := Color("f2e6d3")
const BRICK := Color("b9573a")
const WINDOW_GLASS := Color("a9d8e2")
const WINDOW_FRAME := Color("f7f1e6")
const DOOR_WOOD := Color("9a6a45")

# --- Floors -------------------------------------------------------------------
const TILE_CREAM := Color("efe4cf")
const TILE_SAGE := Color("a9c39a")
const PLANK_A := Color("c39466")
const PLANK_B := Color("b5865a")
const PLANK_C := Color("cc9f72")
const CONCRETE := Color("aeaaa0")
const CONCRETE_DARK := Color("98948b")
const COLD_TILE := Color("cfe3ea")
const HAZARD := Color("e9b23a")
const DIRT := Color("b59a74")

# --- Exterior ----------------------------------------------------------------
const GRASS := Color("8fbf68")
const GRASS_DARK := Color("78a957")
const SIDEWALK := Color("d9d2c4")
const CURB := Color("bdb5a6")
const ASPHALT := Color("4d4f56")
const ROAD_LINE := Color("f1e7c8")
const PLINTH := Color("5b3f2e")
const PLINTH_TOP := Color("d8cbb3")
const LEAF := Color("5f9e4f")
const LEAF_LIGHT := Color("7cb85d")
const TRUNK := Color("7a5236")

# --- Materials ---------------------------------------------------------------
const WALNUT := Color("6b4a35")
const OAK := Color("c08f5e")
const OAK_LIGHT := Color("d7ad7c")
const STEEL := Color("c3cacd")
const STEEL_DARK := Color("858e93")
const CHARCOAL := Color("3d4147")
const RUBBER := Color("2c2e33")
const TEAL := Color("2f7f7a")
const MUSTARD := Color("e3b23c")
const DINER_RED := Color("d24a3c")
const CREAM := Color("f6eedf")
const BUTCHER := Color("d9b382")
const CRATE := Color("c79c66")
const CRATE_DARK := Color("a77d4c")
const CARDBOARD := Color("c9a272")
const SACK := Color("cdb489")
const PLATE := Color("faf6ec")
const PLATE_RIM := Color("e8e0cf")
const MUG := Color("2f8f88")
const DIRTY := Color("a8956f")
const FIRE_RED := Color("e8412f")
const WARNING := Color("f0c02f")
const GLOW_WARM := Color("ffd59a")

# --- Food (deliberately the most saturated things on screen) -------------------
const BUN := Color("e6a955")
const BUN_TOP := Color("d98b36")
const SESAME := Color("f7ecd2")
const PATTY_RAW := Color("e37b7e")
const PATTY_COOKED := Color("7a4a2c")
const PATTY_BURNT := Color("2b211d")
const LETTUCE := Color("6cc24a")
const LETTUCE_DARK := Color("4fa23a")
const TOMATO := Color("e8412f")
const TOMATO_IN := Color("f2735e")
const STEM := Color("3f8f3a")
const POTATO := Color("c9a46b")
const POTATO_CUT := Color("f3e3b0")
const FRIES := Color("f2c14e")
const COFFEE := Color("4a2c1d")
const COFFEE_CREMA := Color("b07a4a")
const BEANS := Color("5a3622")
const CHEESE := Color("f5c431")
const SPOILED := Color("8c9a55")

# --- People --------------------------------------------------------------------
const SKIN_TONES := [
	Color("f3d2b3"), Color("e8b98f"), Color("c98e62"),
	Color("a96c45"), Color("7c4a2d"), Color("5a3520"),
]
const HAIR_COLORS := [
	Color("2b2119"), Color("5a3b22"), Color("8b5a2b"),
	Color("d9a650"), Color("b5492e"), Color("9a9a9a"), Color("e8e2d6"),
]
const CLOTH_COLORS := [
	Color("4f6d8f"), Color("7a8f5a"), Color("b07a4a"), Color("8c5a7a"),
	Color("d6c49a"), Color("5f5f6e"), Color("c96f5a"), Color("6a9a9a"),
	Color("e0d6c2"), Color("3f4f5f"),
]

## Distinct, saturated player identity colours (used on aprons, hats, shoes,
## floor rings and UI). Index = player slot.
const PLAYER_COLORS := [
	Color("e8553e"),  # tomato
	Color("3e8fe8"),  # sky
	Color("f2c230"),  # sunflower
	Color("35b87e"),  # mint
	Color("9b5de5"),  # violet
	Color("f06eaa"),  # flamingo
]
const PLAYER_COLOR_NAMES := ["Tomato", "Sky", "Sunflower", "Mint", "Violet", "Flamingo"]

# --- UI ------------------------------------------------------------------------
const UI_PAPER := Color("f6eedf")
const UI_PAPER_DARK := Color("e8dcc6")
const UI_INK := Color("2e2622")
const UI_INK_SOFT := Color("6b5d52")
const UI_ACCENT := Color("2f7f7a")
const UI_GOOD := Color("3e9c5a")
const UI_WARN := Color("e39b2c")
const UI_BAD := Color("d24a3c")
const UI_MONEY := Color("3e9c5a")
const UI_STAR := Color("f2b630")


static func player_color(index: int) -> Color:
	return PLAYER_COLORS[posmod(index, PLAYER_COLORS.size())]


static func darken(c: Color, amount: float) -> Color:
	return c.darkened(amount)


static func pick(arr: Array, rng: RandomNumberGenerator) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]
