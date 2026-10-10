class_name Tour
## The Franchise Tour: one kind of restaurant taken across all three places,
## Main Street, then the Dining Car Express, then the Orbital Galley. Each
## leg lasts DAYS days; finish it at or above the leg's star target and you
## franchise to the next place, taking your money and your name (reputation)
## with you. Miss it and the tour ends there. With One Strike on, a single
## table walking out ends the tour that night.
##
## The state is a plain Dictionary on GameWorld.tour (empty in Career):
## {leg, strike, earned, struck, fmt}. It is saved and shared with clients.

const LEGS: Array[StringName] = [&"main_street", &"express", &"orbital"]
const DAYS := 4
const TARGETS := [1.5, 2.0, 2.5]
const FRANCHISE_BONUS := 300.0     ## per leg reached: the new place's opening budget
const SCORE_PER_STAR := 250.0


static func start(strike: bool) -> Dictionary:
	return {"leg": 0, "strike": strike, "earned": 0.0}


static func leg(t: Dictionary) -> int:
	return clampi(int(t.get("leg", 0)), 0, LEGS.size() - 1)


static func location(t: Dictionary) -> StringName:
	return LEGS[leg(t)]


static func next_location(t: Dictionary) -> StringName:
	return LEGS[leg(t) + 1] if leg(t) + 1 < LEGS.size() else &""


static func target(t: Dictionary) -> float:
	return TARGETS[leg(t)]


static func place_name(id: StringName) -> String:
	var l: LocationDef = Content.locations.get(id)
	return l.display_name if l else String(id)


## "" while the leg is still going, else "franchised", "complete",
## "missed" (below the star target) or "struck" (One Strike).
static func verdict(t: Dictionary, day: int, rep: float) -> String:
	if t.get("struck", false):
		return "struck"
	if day < DAYS:
		return ""
	if rep + 0.001 < target(t):
		return "missed"
	return "complete" if leg(t) >= LEGS.size() - 1 else "franchised"


static func is_over(v: String) -> bool:
	return v in ["missed", "struck", "complete"]


## The state for the next leg; `money` and `rep` travel with it.
static func next_leg(t: Dictionary, money: float, rep: float) -> Dictionary:
	var n := t.duplicate()
	n["leg"] = leg(t) + 1
	n["money"] = money + FRANCHISE_BONUS * (leg(t) + 1)
	n["rep"] = rep
	n.erase("struck")
	return n


static func score(t: Dictionary, rep: float) -> int:
	return roundi(float(t.get("earned", 0.0)) + SCORE_PER_STAR * rep * (leg(t) + 1))


## Top-left HUD line: "Tour 1/3 · day 2 of 4 · goal 1.5★".
static func status_line(t: Dictionary, day: int) -> String:
	var s := "Tour %d/%d · day %d of %d · goal %.1f★" % [leg(t) + 1, LEGS.size(), mini(day, DAYS), DAYS, target(t)]
	if t.get("strike", false):
		s += " · One Strike"
	return s


static func best_score() -> int:
	return int(Settings.get_value("best_tour") if Settings.get_value("best_tour") != null else 0)


static func record(score_value: int) -> bool:
	if score_value > best_score():
		Settings.set_value("best_tour", score_value)
		return true
	return false
