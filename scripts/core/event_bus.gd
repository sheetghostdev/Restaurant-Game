extends Node
## Autoload "Events": global signals for decoupled communication between
## gameplay systems, UI and audio. Gameplay state lives on the server; these
## signals fire on every peer when the corresponding state is applied.

signal toast(text: String, kind: StringName, color: Color)
signal world_ready(world: Node)
signal world_closed()
signal phase_changed(phase: int)
signal clock_changed(hour: float)
signal money_changed(amount: float, delta: float)
signal reputation_changed(value: float, delta: float)
signal orders_changed()
signal order_served(recipe_id: StringName, quality: float, position: Vector3)
signal customer_left(happy: bool, position: Vector3)
signal player_joined(player: Node)
signal player_left(player: Node)
signal day_results(results: Dictionary)
signal alert(id: StringName, text: String, active: bool)
signal coins_popped(amount: float, position: Vector3)
signal ping(position: Vector3, color: Color)
signal catalog_requested(player: Node, tab: String)
signal build_changed()


func notify(text: String, kind: StringName = &"info", color := Color(0, 0, 0, 0)) -> void:
	toast.emit(text, kind, color)
	Net.relay_toast(text, kind, color)
