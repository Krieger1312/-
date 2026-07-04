class_name PlayerController
extends CharacterBody3D
## Networked player controller. Authority pattern adapted from
## devmoreir4/godot-3d-multiplayer-template: the node's name is the peer id,
## authority is derived from it, and only the owning peer reads input or
## enables its own camera. Position/rotation reach other peers through the
## sibling MultiplayerSynchronizer, not through direct references.

const SPEED: float = 6.0
const SPRINT_SPEED: float = 10.0
const JUMP_VELOCITY: float = 7.5
const PITCH_LIMIT: float = deg_to_rad(80.0)

@export var interact_range: float = 3.0
@export var interact_collision_mask: int = 1
@export var mouse_sensitivity: float = 0.003

## The VehicleSeat currently riding us, or null when on foot. Set by
## VehicleSeat itself via enter_vehicle()/exit_vehicle() -- see there for
## why this isn't replicated to other peers yet.
var current_seat: VehicleSeat = null

## The InteractableComponent currently under our crosshair, or null. Updated
## every physics frame on foot so the HUD can show an interaction prompt;
## cleared while seated since there's nothing to raycast for from inside a
## vehicle.
var focused_interactable: InteractableComponent = null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D
@onready var _grab_component: PhysicalGrabComponent = $PhysicalGrabComponent
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	_camera.current = is_multiplayer_authority()
	_grab_component.camera = _camera
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Mouse-look: yaw turns the whole body (so movement/aim/facing all agree),
## pitch only tilts the SpringArm3D so the model itself never tips over.
## Without this the camera/interact raycast were both stuck dead-horizontal
## at eye height, unable to aim at anything shorter (a parked car's roofline
## sits below eye level) -- found by testing the seat/interact raycast at a
## realistic standing distance instead of calling interact() directly.
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_spring_arm.rotation.x = clampf(
			_spring_arm.rotation.x - event.relative.y * mouse_sensitivity, -PITCH_LIMIT, PITCH_LIMIT
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)


## Called by a VehicleSeat when we get in: hide, stop walking, and let the
## seat's own camera take over. Disabling our own collision matters here --
## a hidden-but-still-solid capsule left standing where the vehicle needs to
## move would just block it.
func enter_vehicle(seat: VehicleSeat) -> void:
	current_seat = seat
	visible = false
	_collision_shape.disabled = true
	_camera.current = false
	_set_focused_interactable(null)


## Called by a VehicleSeat when we get out: reappear at `exit_position` and
## take our own camera back.
func exit_vehicle(exit_position: Vector3) -> void:
	current_seat = null
	global_position = exit_position
	visible = true
	_collision_shape.disabled = false
	_camera.current = is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if current_seat != null:
		if Input.is_action_just_pressed("interact"):
			current_seat.exit()
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed: float = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	_set_focused_interactable(_find_component(InteractableComponent) as InteractableComponent)

	if Input.is_action_just_pressed("interact"):
		_handle_interact()


## Tracks whichever InteractableComponent is under the crosshair so the HUD
## can show its prompt_text; on_focus/on_unfocus fire so other systems (e.g.
## a future highlight outline) can react the same way they would to interact().
func _set_focused_interactable(interactable: InteractableComponent) -> void:
	if interactable == focused_interactable:
		return
	if focused_interactable != null:
		focused_interactable.unfocus(self)
	focused_interactable = interactable
	if focused_interactable != null:
		focused_interactable.focus(self)


## Cargo-in-hand takes priority (drop into a slot if we're facing one),
## then a direct InteractableComponent, then falls back to grabbing
## whatever we're looking at.
func _handle_interact() -> void:
	if _grab_component.is_holding():
		_try_load_held_into_slot()
		return

	var interactable: InteractableComponent = (
		_find_component(InteractableComponent) as InteractableComponent
	)
	if interactable:
		interactable.interact(self)
		return

	_grab_component.toggle_grab()


func _try_load_held_into_slot() -> void:
	var held: RigidBody3D = _grab_component.get_grabbed_body()
	var slot: CargoSlot = _find_component(CargoSlot) as CargoSlot
	_grab_component.toggle_grab()
	if slot and held and not slot.is_loaded():
		slot.load_cargo(held)


## Breadth-first so a component closer to the raycasted body's root wins
## over one nested deeper (e.g. a vehicle's direct Seat before its
## ServicePoint/InteractableComponent) -- searches the whole subtree, not
## just direct children, since components are often wrapped in a holder node.
func _find_component(component_script: Script) -> Node:
	var body: Variant = _raycast_collider()
	if body == null:
		return null
	var queue: Array[Node] = [body as Node]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		for child in node.get_children():
			if is_instance_of(child, component_script):
				return child
			queue.append(child)
	return null


## Casts from the SpringArm3D's own (un-extended) anchor rather than the
## Camera3D's tip -- the chase-cam arm pulls the camera several meters
## behind and above the player whenever unobstructed (spring_length=4 here,
## more on some vehicles), which put anything within interact_range of the
## player's actual body entirely out of the ray's reach. Direction still
## matches the camera exactly since nothing here ever rotates the camera
## independently of the player body (no separate mouse-look pitch).
func _raycast_collider() -> Variant:
	var space_state: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var from: Vector3 = _spring_arm.global_position
	var to: Vector3 = from - _spring_arm.global_transform.basis.z * interact_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = interact_collision_mask
	# The SpringArm3D anchor sits on our own vertical centerline at eye
	# height, inside our own capsule's top cap -- without this the ray can
	# self-intersect and never reach past our own body.
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	return result.get("collider")
