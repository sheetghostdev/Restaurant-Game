extends Node
## Autoload "Saves": versioned JSON save files in user://saves/.
##
## A save is the world's entity records plus manager data (see
## GameWorld.make_save). Every file carries a "version"; `migrate()` upgrades
## older saves step by step so format changes don't break existing games.

const DIR := "user://saves"
const DEFAULT_SLOT := "restaurant"

## Tests redirect saves to their own slot so they never touch the player's game.
var active_slot := DEFAULT_SLOT

signal saved(path: String)


func path_for(slot := "") -> String:
	if slot == "":
		slot = active_slot
	return "%s/%s.json" % [DIR, slot]


func has_save(slot := "") -> bool:
	return FileAccess.file_exists(path_for(slot))


func save_game(world: GameWorld, slot := "") -> bool:
	if world == null or not Net.is_authority():
		return false
	DirAccess.make_dir_recursive_absolute(DIR)
	var data := world.make_save()
	var f := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if f == null:
		push_error("Saves: cannot write %s" % path_for(slot))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	saved.emit(path_for(slot))
	return true


func autosave(world: GameWorld) -> void:
	save_game.call_deferred(world)


func load_data(slot := "") -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(path_for(slot), FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("Saves: corrupt save %s" % path_for(slot))
		return {}
	return migrate(parsed)


func meta(slot := "") -> Dictionary:
	var d := load_data(slot)
	return d.get("meta", {})


func delete(slot := "") -> void:
	if has_save(slot):
		DirAccess.remove_absolute(path_for(slot))


## Upgrades old save data to the current format.
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v < 1:
		# v0 (prototype) saves had no versioned manager sections.
		d["economy"] = d.get("economy", {"money": d.get("meta", {}).get("money", 250.0), "reputation": d.get("meta", {}).get("reputation", 1.0)})
		d["day"] = d.get("day", {"day": d.get("meta", {}).get("day", 1)})
		v = 1
	# Future: if v < 2: ...
	d["version"] = v
	return d
