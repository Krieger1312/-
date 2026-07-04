extends VehicleBody3D
## Standalone car physics component, isolated from gameplay/network code.
## Driving feel (engine/steer/brake curves) adapted from the VehicleBody3D
## setup in 32kda/vehicle_sample, stripped of that project's weapons/health/
## audio systems so it only depends on VehicleBody3D + VehicleWheel3D.
##
## Only the multiplayer authority (the driver) reads input and simulates
## physics; other peers freeze their copy and follow the transform that
## arrives through the sibling MultiplayerSynchronizer, so two peers never
## simulate the same car at once.

@export var engine_power: float = 200.0
@export var engine_response: float = 100.0
@export var steer_angle: float = deg_to_rad(30.0)
@export var steer_response: float = 2.5
@export var brake_power: float = 160.0
@export var brake_response: float = 16.0
@export var low_speed_threshold: float = 10.0


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	freeze = not is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var throttle_input: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var current_speed: float = linear_velocity.length()
	if current_speed > 0.0 and current_speed < low_speed_threshold:
		throttle_input *= low_speed_threshold / current_speed
	engine_force = lerp(engine_force, throttle_input * engine_power, engine_response * delta)

	var steer_input: float = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	steering = lerp(steering, steer_input * steer_angle, steer_response * delta)

	var brake_input: float = Input.get_action_strength("brake")
	var brake_target: float = brake_power if brake_input > 0.0 else 0.0
	brake = lerp(brake, brake_target, brake_response * delta)
