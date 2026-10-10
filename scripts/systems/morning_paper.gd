class_name MorningPaper
## The Morning Paper. From day 2, every morning's paper has three stories and
## the crew picks one before the prep clock starts. Each is a trade-off that
## makes the day different: a coach party booked for lunch, a food critic in
## town, rain (fewer guests, bigger tips), a craze for one dish, an
## equipment clearance... If nobody picks before the doors open, the paper
## goes in the bin and it's an ordinary day.
##
## A headline is a Dictionary {id, kind, title, text, fx, icon?}; DayManager
## keeps the offers and applies the chosen fx (see DayManager.choose_headline).

const FIRST_DAY := 2


## Today's three stories, seeded by the day so every player sees the same.
static func offers(world: GameWorld, day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, String(world.format.id), String(world.location.id), world.restaurant_name])
	var pool := _pool(world, day, rng)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	# Three different kinds of story where possible.
	var out := []
	var kinds := {}
	for h in pool:
		if out.size() < 3 and not kinds.has(h["kind"]):
			out.push_back(h)
			kinds[h["kind"]] = true
	for h in pool:
		if out.size() < 3 and not out.has(h):
			out.push_back(h)
	return out


static func _pool(world: GameWorld, day: int, rng: RandomNumberGenerator) -> Array:
	var fmt := world.format
	var open_h := fmt.open_hour
	var close_h := fmt.close_hour
	var mid := rng.randi_range(open_h + 1, maxi(open_h + 1, close_h - 3))
	var late := rng.randi_range(maxi(open_h + 2, close_h - 4), maxi(open_h + 2, close_h - 2))
	var menu := Content.menu_for(fmt, day)
	var pool := []
	var coach := 2 + mini(day / 3, 2)
	var coach_bonus := 40.0 * coach + 10.0
	pool.push_back({"id": "coach", "kind": "Booking", "title": "Coach party at %s" % GameConst.clock_text(mid),
		"text": "A coach tour stops here: %d groups arrive together at %s. Seat and serve them all for a %s bonus." % [coach, GameConst.clock_text(mid), GameConst.money(coach_bonus)],
		"fx": {"burst": coach, "hour": mid, "bonus": coach_bonus}})
	pool.push_back({"id": "party", "kind": "Booking", "title": "Birthday party tonight",
		"text": "A party of six at %s. Push tables together for them: %s if they leave happy." % [GameConst.clock_text(late), GameConst.money(70.0)],
		"fx": {"party": 6, "hour": late, "bonus": 70.0}})
	if fmt.archetypes.has(&"critic"):
		pool.push_back({"id": "critic", "kind": "News", "title": "Food critic in town",
			"text": "Reviews count double today: every star you win or lose counts twice. And a critic is coming.",
			"fx": {"rep_mult": 2.0, "critic": true, "hour": mid}})
	pool.push_back({"id": "famous", "kind": "News", "title": "We made the papers!",
		"text": "A glowing write-up: about a third more guests today. Busier, and richer.",
		"fx": {"groups_mult": 1.35}})
	pool.push_back({"id": "rain", "kind": "Weather", "title": "Rain all day",
		"text": "Fewer guests (about 30% fewer), but the ones who come tip double.",
		"fx": {"groups_mult": 0.7, "tips_mult": 2.0}})
	var drinks := menu.filter(func(r): return r.container == "mug")
	if not drinks.is_empty():
		pool.push_back({"id": "heat", "kind": "Weather", "title": "Heatwave!",
			"text": "Everyone's thirsty: drinks are ordered twice as often and sell for 30% more.",
			"fx": {"drinks": 2.0, "drink_price": 1.3}})
	if not menu.is_empty():
		var r: RecipeDef = menu[rng.randi_range(0, menu.size() - 1)]
		pool.push_back({"id": "craze", "kind": "Trend", "title": "%s craze" % r.display_name,
			"text": "Everybody wants %s: ordered three times as often, and it sells for 25%% more." % r.display_name.to_lower(),
			"fx": {"recipe": String(r.id), "weight": 3.0, "price": 1.25}, "icon": "recipe:%s" % r.id})
	pool.push_back({"id": "clearance", "kind": "Deal", "title": "Supplier clearance",
		"text": "Equipment is 30% off until tomorrow morning: a good day to build.",
		"fx": {"equip_mult": 0.7}})
	if world.location and world.location.supply_mode == "truck":
		var sups := Content.supplies_for(fmt)
		if not sups.is_empty():
			var s: SupplyDef = sups[rng.randi_range(0, sups.size() - 1)]
			pool.push_back({"id": "surplus", "kind": "Deal", "title": "Farmer's surplus",
				"text": "Two free crates of %s, on the truck this morning." % s.display_name.to_lower(),
				"fx": {"free": String(s.id), "crates": 2}})
	pool.push_back({"id": "ad", "kind": "Local", "title": "Advertise with us",
		"text": "The paper pays %s to put an ad in your window. An ordinary day otherwise." % GameConst.money(60.0),
		"fx": {"cash": 60.0}})
	return pool
