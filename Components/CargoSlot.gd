extends Node3D
## Attach point for locking cargo onto a vehicle -- e.g. loading a prop
## released by a PhysicalGrabComponent into the Ford Transit's bed for
## delivery. Pins the cargo with a PinJoint3D instead of reparenting it, so
## it keeps its own collision shape and mass while riding along.

@export var joint_bias: float = 0.3
@export var joint_damping: float = 1.0

var _cargo: RigidBody3D
var _joint: PinJoint3D


func _enter_tree() -> void:
	set_multiplayer_authority(get_parent().get_multiplayer_authority())


func is_loaded() -> bool:
	return _cargo != null


## Locks `body` to this slot. Only the owning peer may act; replicated to everyone.
func load_cargo(body: RigidBody3D) -> void:
	if not is_multiplayer_authority() or _cargo:
		return
	request_load.rpc(body.get_path())


## Releases whatever cargo is currently locked to this slot.
func unload_cargo() -> void:
	if not is_multiplayer_authority():
		return
	request_unload.rpc()


@rpc("authority", "call_local", "reliable")
func request_load(body_path: NodePath) -> void:
	var body: Node = get_node_or_null(body_path)
	if body is RigidBody3D and _cargo == null:
		_lock(body)


@rpc("authority", "call_local", "reliable")
func request_unload() -> void:
	_unlock()


func _lock(body: RigidBody3D) -> void:
	_cargo = body

	_joint = PinJoint3D.new()
	_joint.bias = joint_bias
	_joint.damping = joint_damping
	add_child(_joint)
	_joint.global_position = global_position
	_joint.node_a = get_parent().get_path()
	_joint.node_b = _cargo.get_path()


func _unlock() -> void:
	if _joint:
		_joint.queue_free()
		_joint = null
	_cargo = null
