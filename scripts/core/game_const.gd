class_name GameConst
## Shared enums and tuning constants.

enum Verb { GRAB, USE }
enum Phase { MORNING, SERVICE, CLOSING, RESULTS, EVENING }

const PHASE_NAMES := ["Morning Prep", "Service", "Closing", "Results", "Evening"]

const CELL := 1.0
const MAX_PLAYERS := 6
const COUNTER_H := 0.8

# Physics layers (bit values)
const L_WORLD := 1
const L_FIXTURE := 2
const L_FLOOR_ITEM := 4
const L_PLAYER := 8
const L_NPC := 16

const SAVE_VERSION := 1


static func is_calm(phase: int) -> bool:
	return phase == Phase.MORNING or phase == Phase.EVENING


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


static func dir_from_rot(rot: int) -> Vector2i:
	# rot 0 faces +Z (toward the camera), increasing rot turns counter-clockwise
	# when seen from above: 1 -> +X, 2 -> -Z, 3 -> -X.
	match posmod(rot, 4):
		0: return Vector2i(0, 1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, -1)
		_: return Vector2i(-1, 0)


static func rot_from_dir(d: Vector2i) -> int:
	if d == Vector2i(0, 1): return 0
	if d == Vector2i(1, 0): return 1
	if d == Vector2i(0, -1): return 2
	return 3


static func money(v: float) -> String:
	return ("-$%d" % absi(roundi(v))) if v < 0 else ("$%d" % roundi(v))


static func clock_text(hour: float) -> String:
	var h := int(floor(hour))
	var m := int(floor((hour - h) * 60.0)) / 5 * 5
	h = posmod(h, 24)
	var suffix := "am" if h < 12 else "pm"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d%s" % [h12, m, suffix]
