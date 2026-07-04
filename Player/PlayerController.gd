extends CharacterBody3D
## Networked player controller. Authority pattern adapted from
## devmoreir4/godot-3d-multiplayer-template: the node's name is the peer id,
## authority is derived from it, and only the owning peer reads input or
## enables its own camera. Position/rotation reach other peers through the
## sibling MultiplayerSynchronizer, not through direct references.

const SPEED: float = 6.0
const SPRINT_SPEED: float = 10.0
const JUMP_VELOCITY: float = 7.5

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	_camera.current = is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed: float = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
