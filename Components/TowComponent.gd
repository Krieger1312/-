class_name TowComponent
extends Node3D
## Lets its owning vehicle hitch a nearby immobilized VehicleBody3D and tow
## it with a PinJoint3D, mirroring PhysicalGrabComponent's grab/drop pattern.
##
## Known limitation: physics for each vehicle only runs on its own
## multiplayer authority (see VehicleController), so a PinJoint3D between two
## vehicles only behaves correctly when both share the same authority. This
## works for towing an immobilized vehicle that has no active driver of its
## own; hitching a vehicle that is actively being driven by a different peer
## is not supported yet -- that needs an authority handoff this component
## does not implement.

@export var hitch_point: Node3D
@export var tow_range: float = 4.0
@export var collision_mask: int = 1
@export var joint_bias: float = 0.3
@export var joint_damping: float = 1.0

var _towed_vehicle: VehicleBody3D
var _joint: PinJoint3D


func _enter_tree() -> void:
	set_multiplayer_authority(get_parent().get_multiplayer_authority())


func is_towing() -> bool:
	return _towed_vehicle != null


## Hitches whatever towable vehicle is behind the hitch point, or releases
## the one currently towed. Only the owning peer may act; replicated to everyone.
func toggle_tow() -> void:
	if not is_multiplayer_authority():
		return
	if _towed_vehicle:
		request_unhitch.rpc()
	else:
		var target: VehicleBody3D = _find_towable_vehicle()
		if target:
			request_hitch.rpc(target.get_path())


@rpc("authority", "call_local", "reliable")
func request_hitch(vehicle_path: NodePath) -> void:
	var vehicle: Node = get_node_or_null(vehicle_path)
	if vehicle is VehicleBody3D and _towed_vehicle == null:
		_hitch(vehicle)


@rpc("authority", "call_local", "reliable")
func request_unhitch() -> void:
	unhitch()


func unhitch() -> void:
	if _joint:
		_joint.queue_free()
		_joint = null
	_towed_vehicle = null


func _find_towable_vehicle() -> VehicleBody3D:
	if hitch_point == null:
		return null
	var owner_body: Node3D = get_parent()
	var space_state: PhysicsDirectSpaceState3D = hitch_point.get_world_3d().direct_space_state
	var from: Vector3 = hitch_point.global_position
	var to: Vector3 = from - owner_body.global_transform.basis.z * tow_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	query.exclude = [owner_body.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	var body: Variant = result.get("collider")
	return body if body is VehicleBody3D and body != owner_body else null


func _hitch(vehicle: VehicleBody3D) -> void:
	_towed_vehicle = vehicle

	_joint = PinJoint3D.new()
	_joint.bias = joint_bias
	_joint.damping = joint_damping
	add_child(_joint)
	_joint.global_position = hitch_point.global_position
	_joint.node_a = get_parent().get_path()
	_joint.node_b = _towed_vehicle.get_path()
