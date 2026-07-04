extends Node3D
## Lets its owner pick up a RigidBody3D in front of a camera and carry it
## with a PinJoint3D instead of reparenting it, so the object keeps its own
## collision shape and mass while held and reacts physically while carried.

@export var camera: Camera3D
@export var grab_range: float = 3.0
@export var hold_distance: float = 2.0
@export var collision_mask: int = 1
@export var joint_bias: float = 0.3
@export var joint_damping: float = 1.0

var _anchor: StaticBody3D
var _joint: PinJoint3D
var _grabbed_body: RigidBody3D


func _enter_tree() -> void:
	set_multiplayer_authority(get_parent().get_multiplayer_authority())


func _ready() -> void:
	_anchor = StaticBody3D.new()
	_anchor.top_level = true
	add_child(_anchor)


func _physics_process(_delta: float) -> void:
	if _grabbed_body and is_multiplayer_authority():
		_anchor.global_position = _hold_position()


func is_holding() -> bool:
	return _grabbed_body != null


## Grabs whatever the camera is looking at, or releases the held object.
## Only the owning peer may act; the result is replicated to everyone.
func toggle_grab() -> void:
	if not is_multiplayer_authority():
		return
	if _grabbed_body:
		request_drop.rpc()
	else:
		var target: RigidBody3D = _raycast_target()
		if target:
			request_grab.rpc(target.get_path())


@rpc("authority", "call_local", "reliable")
func request_grab(body_path: NodePath) -> void:
	var body: Node = get_node_or_null(body_path)
	if body is RigidBody3D:
		_grab(body)


@rpc("authority", "call_local", "reliable")
func request_drop() -> void:
	drop()


func drop() -> void:
	if _joint:
		_joint.queue_free()
		_joint = null
	_grabbed_body = null


func _raycast_target() -> RigidBody3D:
	if camera == null:
		return null
	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_transform.basis.z * grab_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	var result: Dictionary = space_state.intersect_ray(query)
	var body: Variant = result.get("collider")
	return body if body is RigidBody3D else null


func _grab(body: RigidBody3D) -> void:
	_grabbed_body = body
	_anchor.global_position = _hold_position()

	_joint = PinJoint3D.new()
	_joint.bias = joint_bias
	_joint.damping = joint_damping
	add_child(_joint)
	_joint.global_position = _anchor.global_position
	_joint.node_a = _anchor.get_path()
	_joint.node_b = _grabbed_body.get_path()


func _hold_position() -> Vector3:
	return camera.global_position - camera.global_transform.basis.z * hold_distance
