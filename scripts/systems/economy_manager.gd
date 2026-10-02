class_name EconomyManager
extends Node
## Money and reputation. Every change goes through here so the day's ledger and
## the HUD stay consistent.

var world: GameWorld
var money := 250.0
var reputation := 1.0          ## 0..5 stars
var ledger: Array = []         ## today's [{label, amount}]
var lifetime_earned := 0.0


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


func setup_new(start_money: float, start_rep: float) -> void:
	money = start_money
	reputation = start_rep
	ledger.clear()
	_publish(0.0, 0.0)


func can_afford(amount: float) -> bool:
	return money >= amount - 0.001


func spend(amount: float, label: String) -> bool:
	if not can_afford(amount):
		Events.notify("Not enough money for %s" % label, &"error")
		Audio.play_ui(&"error")
		return false
	money -= amount
	ledger.push_back({"label": label, "amount": -amount})
	world.day.stats_add(&"expenses", amount)
	Audio.play_ui(&"money_spend")
	_publish(-amount, 0.0)
	return true


## Charges even if it puts the restaurant in debt (wages, bills).
func charge(amount: float, label: String) -> void:
	money -= amount
	ledger.push_back({"label": label, "amount": -amount})
	world.day.stats_add(&"expenses", amount)
	_publish(-amount, 0.0)


func earn(amount: float, label: String) -> void:
	money += amount
	lifetime_earned += amount
	ledger.push_back({"label": label, "amount": amount})
	_publish(amount, 0.0)


func add_sale(amount: float, at: Vector3) -> void:
	if amount <= 0.0:
		return
	money += amount
	lifetime_earned += amount
	world.day.stats_add(&"revenue", amount)
	Audio.play_at(&"cash_register", at)
	world.fx.coins(at, amount)
	_publish(amount, 0.0)


func change_reputation(delta: float) -> void:
	var old := reputation
	reputation = clampf(reputation + delta, 0.0, 5.0)
	if floor(reputation * 2.0) > floor(old * 2.0):
		Audio.play_ui(&"level_up")
	_publish(0.0, reputation - old)


func _publish(dm: float, dr: float) -> void:
	Events.money_changed.emit(money, dm)
	if dr != 0.0:
		Events.reputation_changed.emit(reputation, dr)
	if world and world.replicator:
		world.replicator.publish(&"economy", {"m": money, "r": reputation, "dm": dm, "dr": dr})


func apply_shared(d: Dictionary) -> void:
	money = d.get("m", money)
	var old := reputation
	reputation = d.get("r", reputation)
	Events.money_changed.emit(money, d.get("dm", 0.0))
	if reputation != old:
		Events.reputation_changed.emit(reputation, reputation - old)


func save_data() -> Dictionary:
	return {"money": money, "reputation": reputation, "lifetime": lifetime_earned}


func load_data(d: Dictionary) -> void:
	money = d.get("money", money)
	reputation = d.get("reputation", reputation)
	lifetime_earned = d.get("lifetime", 0.0)
	_publish(0.0, 0.0)
