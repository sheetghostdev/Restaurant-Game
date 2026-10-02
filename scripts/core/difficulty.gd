class_name Difficulty
## Difficulty presets (Settings "difficulty"). Systems on the host multiply
## their base tuning by these factors, so balance stays in one place.
##   patience   - how long guests wait (queue, ordering, food)
##   groups     - how many groups come per day
##   overcook   - cooking speed once food is past perfect (lower = more time
##                before it overcooks, burns or catches fire)
##   disasters  - chance of each random disaster or event per day
##   rep_loss   - reputation lost for upset or unhappy guests
##   spoil      - how long perishables last outside the fridge
##   first_disaster_day - no disasters before this day

enum { RELAXED, NORMAL, HECTIC }

const NAMES := ["Relaxed", "Normal", "Hectic"]
const BLURBS := [
	"Patient guests, fewer of them, a forgiving grill and rare disasters.",
	"A busy diner with room to learn. Recommended.",
	"The full rush: impatient crowds, quick burns and frequent disasters.",
]
const PRESETS := [
	{"patience": 1.7, "groups": 0.65, "overcook": 0.5, "disasters": 0.35, "rep_loss": 0.5, "spoil": 1.6, "first_disaster_day": 3},
	{"patience": 1.35, "groups": 0.82, "overcook": 0.7, "disasters": 0.65, "rep_loss": 0.75, "spoil": 1.25, "first_disaster_day": 2},
	{"patience": 1.0, "groups": 1.0, "overcook": 1.0, "disasters": 1.0, "rep_loss": 1.0, "spoil": 1.0, "first_disaster_day": 1},
]


static func level() -> int:
	var v = Settings.get_value("difficulty") if Settings else NORMAL
	return clampi(int(v) if v != null else NORMAL, 0, PRESETS.size() - 1)


static func factor(key: String) -> float:
	return float(PRESETS[level()].get(key, 1.0))


static func first_disaster_day() -> int:
	return int(PRESETS[level()].get("first_disaster_day", 1))
