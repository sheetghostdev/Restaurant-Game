class_name Automation
## Shared rules for machines that move items between fixtures (conveyors,
## grabbers, staff). They use the same insertion rules as players so
## automation never does anything a person couldn't.


## Tries to put `it` into `f`. Returns true if the fixture took it.
static func try_insert(f: Fixture, it: Item) -> bool:
	if f == null or it == null or not f.is_working() or f.lifted:
		return false
	for c in f.components:
		if c.has_method("auto_insert"):
			if c.auto_insert(it):
				# A partial insert (rack fills up mid-stack) leaves the rest
				# with the caller, which puts it back where it came from.
				return _absorbed(it)
	var s := f.primary_slot()
	if s == null:
		return false
	if s.item == null:
		if s.can_hold(it):
			s.put(it)
			it.mark_dirty()
			return true
		return false
	if s.item.can_receive(it):
		# Pouring a crate into a fuller one may leave units behind.
		s.item.receive(it)
		return _absorbed(it)
	if not (s.item is CrateItem) and it.can_receive(s.item):
		# e.g. a plate arriving at a counter holding finished fries. (Never a
		# crate pouring backwards: that would ping-pong units between belts.)
		var inner := s.item
		it.receive(inner)
		if inner.slot == s:
			return false
		s.put(it)
		it.mark_dirty()
		return true
	return false


## True once `it` is gone (despawned into its target) or placed somewhere real.
static func _absorbed(it: Item) -> bool:
	if not is_instance_valid(it) or it.is_queued_for_deletion():
		return true
	var parent := it.get_parent()
	return parent != null and not (GameWorld.current and parent == GameWorld.current.limbo)


## Tries to take one item out of `f` for transport.
static func try_extract(f: Fixture) -> Item:
	if f == null or f.lifted or f.is_blocked():
		return null
	for c in f.components:
		if c.has_method("auto_extract"):
			var got: Item = c.auto_extract()
			if got:
				return got
	var s := f.primary_slot()
	if s == null or s.item == null:
		return null
	var it := s.item
	# Never pull food that is still being prepared.
	var cook := f.get_component("Cooker") as Cooker
	if cook:
		var k := cook.cooking()
		if not k.is_empty() and k["item"] == it:
			var p: CookProfile = k["profile"]
			if p.stage_index(Cooker.cook_of(k)) < p.perfect_stage:
				return null
	var proc := f.get_component("Processor") as Processor
	if proc and proc.work_item() == it:
		return null
	if it is CrateItem:
		return (it as CrateItem).take_one() if (it as CrateItem).count > 0 else null
	if f.get_component("Conveyor") and not (f.get_component("Conveyor") as Conveyor).ready_to_pass():
		return null
	return s.take()
