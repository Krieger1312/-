extends CharacterBody3D
## Networked player controller. Authority pattern adapted from
## devmoreir4/godot-3d-multiplayer-template: the node's name is the peer id,
## authority is derived from it, and only the owning peer reads input or
## enables its own camera. Position/rotation reach other peers through the
## sibling MultiplayerSynchronizer, not through direct references.

const SPEED: float = 6.0
const SPRINT_SPEED: float = 10.0
const JUMP_VELOCITY: float = 7.5

@export var interact_range: float = 3.0
@export var interact_collision_mask: int = 1

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D
@onready var _grab_component: PhysicalGrabComponent = $PhysicalGrabComponent


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	_camera.current = is_multiplayer_authority()
	_grab_component.camera = _camera


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
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

	if Input.is_action_just_pressed("interact"):
		_handle_interact()


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


func _find_component(component_script: Script) -> Node:
	var body: Variant = _raycast_collider()
	if body == null:
		return null
	for child in (body as Node).get_children():
		if is_instance_of(child, component_script):
			return child
	return null


func _raycast_collider() -> Variant:
	var space_state: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_transform.basis.z * interact_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = interact_collision_mask
	var result: Dictionary = space_state.intersect_ray(query)
	return result.get("collider")
