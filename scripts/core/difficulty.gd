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
##   prep_seconds - morning prep time before the doors open by themselves

enum { RELAXED, NORMAL, HECTIC }

const NAMES := ["Relaxed", "Normal", "Hectic"]
const BLURBS := [
	"Patient guests, fewer of them, longer prep, a forgiving grill and rare disasters.",
	"A busy restaurant: guests won't wait forever. Recommended.",
	"The full rush: impatient crowds, short prep, quick burns and frequent disasters.",
]
const PRESETS := [
	{"patience": 1.35, "groups": 0.7, "overcook": 0.5, "disasters": 0.35, "rep_loss": 0.6, "spoil": 1.6, "first_disaster_day": 3, "prep_seconds": 130.0},
	{"patience": 1.0, "groups": 0.85, "overcook": 0.7, "disasters": 0.65, "rep_loss": 1.0, "spoil": 1.25, "first_disaster_day": 2, "prep_seconds": 100.0},
	{"patience": 0.8, "groups": 1.0, "overcook": 1.0, "disasters": 1.0, "rep_loss": 1.25, "spoil": 1.0, "first_disaster_day": 1, "prep_seconds": 75.0},
]


static func level() -> int:
	var v = Settings.get_value("difficulty") if Settings else NORMAL
	return clampi(int(v) if v != null else NORMAL, 0, PRESETS.size() - 1)


static func factor(key: String) -> float:
	return float(PRESETS[level()].get(key, 1.0))


static func first_disaster_day() -> int:
	return int(PRESETS[level()].get("first_disaster_day", 1))
