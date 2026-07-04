class_name VAZ2107Frame
extends Node3D
## Disassembled VAZ2107 sitting in the home garage (My Summer Car style):
## a non-drivable shell with PartSlot children (4 wheels, engine, battery,
## found via get_children() -- see below). Once every slot reports
## installed, its InteractableComponent's prompt switches to "Assemble" and
## interacting swaps this frame for a fully drivable VAZ2107.tscn instance
## at the same transform. Same any_peer -> authority broadcast pattern as
## PartSlot, for the same reason: nobody owns this frame the way a peer
## owns their own car or cargo bed.

@export var assembled_scene: PackedScene

var _slots: Array[PartSlot] = []

@onready var _interactable: InteractableComponent = $InteractableComponent


func _ready() -> void:
	for child in get_children():
		if child is PartSlot:
			_slots.append(child)
			child.installed.connect(_update_prompt)
	_interactable.on_interact.connect(_on_interact)
	_update_prompt()


func _installed_count() -> int:
	var count: int = 0
	for slot in _slots:
		if slot.is_installed:
			count += 1
	return count


func _all_installed() -> bool:
	return _installed_count() == _slots.size()


func _update_prompt() -> void:
	_interactable.prompt_text = (
		"Assemble VAZ-2107"
		if _all_installed()
		else "Assemble VAZ-2107 (%d/%d parts)" % [_installed_count(), _slots.size()]
	)


func _on_interact(_interactor: Node) -> void:
	if not _all_installed():
		return
	request_assemble.rpc()


## call_local for the same reason as PartSlot.request_install -- otherwise
## the common case (the caller already is the server) never runs at all.
@rpc("any_peer", "call_local", "reliable")
func request_assemble() -> void:
	if not multiplayer.is_server() or not _all_installed():
		return
	_apply_assemble.rpc()


@rpc("authority", "call_local", "reliable")
func _apply_assemble() -> void:
	var assembled: Node3D = assembled_scene.instantiate()
	var parent: Node = get_parent()
	var xform: Transform3D = global_transform
	parent.add_child(assembled)
	assembled.global_transform = xform
	queue_free()
