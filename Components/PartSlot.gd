class_name PartSlot
extends Node3D
## One install point on a disassembled vehicle (My Summer Car style): accepts
## exactly one CarPart matching `part_id`, dropped in via the same "hold +
## look at it + interact" gesture PlayerController already uses for CargoSlot
## (see PlayerController._try_load_held_into_slot). Routed through the
## server (any_peer request -> authority broadcast) rather than inheriting
## authority from a parent the way CargoSlot does -- a disassembled vehicle
## sitting in a garage isn't owned by any one peer the way a car or its own
## cargo bed is, so there's no single trusted authority to hand this to.

signal installed

@export var part_id: String = ""

var is_installed: bool = false


func accepts(part: CarPart) -> bool:
	return not is_installed and part != null and part.part_id == part_id


## Called by PlayerController when it drops a held part onto this slot.
func install(part: CarPart) -> void:
	if not accepts(part):
		return
	request_install.rpc(part.get_path())


## call_local matters here in a way register_player.rpc_id() upstream didn't
## need it: NetworkManager's host bypasses its own RPC entirely for the
## host's own registration, but PartSlot has no such bypass, so without
## call_local the common single-host-acting-on-their-own-world case (the
## caller already is peer 1/the server) would silently never run at all.
@rpc("any_peer", "call_local", "reliable")
func request_install(part_path: NodePath) -> void:
	if not multiplayer.is_server() or is_installed:
		return
	var part: Node = get_node_or_null(part_path)
	if not (part is CarPart) or not accepts(part):
		return
	_apply_installed.rpc(part_path)


## Broadcast so every peer frees its own copy of the part and agrees the
## slot is filled, not just the server that validated the request.
@rpc("authority", "call_local", "reliable")
func _apply_installed(part_path: NodePath) -> void:
	is_installed = true
	var part: Node = get_node_or_null(part_path)
	if part:
		part.queue_free()
	installed.emit()
