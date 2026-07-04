class_name VehicleController
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

## Speed governor (m/s): cuts forward throttle once reached. 0 disables it
## (unlimited top speed), which is the default for vehicles that don't need one.
@export var max_speed: float = 0.0

## Fuel drains with engine load and cuts the throttle at zero; refilled via refuel().
@export var fuel_capacity: float = 40.0
@export var fuel_consumption_rate: float = 2.0

## Deceleration above this (m/s^2) is treated as a crash impact rather than
## normal braking -- real cars rarely exceed ~10 m/s^2 under braking alone.
@export var max_health: float = 100.0
@export var min_impact_deceleration: float = 40.0
@export var damage_per_deceleration_unit: float = 0.15

var current_fuel: float
var current_health: float
var _is_immobilized: bool = false
var _previous_speed: float = 0.0


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	freeze = not is_multiplayer_authority()
	current_fuel = fuel_capacity
	current_health = max_health


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var throttle_input: float = (
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	)
	if _is_immobilized or current_fuel <= 0.0:
		throttle_input = 0.0
	var current_speed: float = linear_velocity.length()
	if max_speed > 0.0 and current_speed >= max_speed:
		throttle_input = minf(throttle_input, 0.0)
	if current_speed > 0.0 and current_speed < low_speed_threshold:
		# Capped: uncapped, this blows up toward the near-zero speeds right
		# off a standing start and destabilizes the lerp below (its weight
		# can exceed 1 -- see that comment) into a multi-tick oscillation
		# that briefly sends engine_force to absurd magnitudes.
		throttle_input *= clampf(low_speed_threshold / current_speed, 1.0, 4.0)
	# lerp()'s weight must stay within [0, 1]; engine_response * delta alone
	# can exceed 1 (e.g. 100 * 1/60 = 1.67), which turns lerp into a
	# diverging extrapolation instead of smoothing toward the target.
	var engine_weight: float = clampf(engine_response * delta, 0.0, 1.0)
	engine_force = lerp(engine_force, throttle_input * engine_power, engine_weight)

	var steer_input: float = (
		Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	)
	var steer_weight: float = clampf(steer_response * delta, 0.0, 1.0)
	steering = lerp(steering, steer_input * steer_angle, steer_weight)

	var brake_input: float = Input.get_action_strength("brake")
	var brake_target: float = brake_power if brake_input > 0.0 else 0.0
	var brake_weight: float = clampf(brake_response * delta, 0.0, 1.0)
	brake = lerp(brake, brake_target, brake_weight)

	_consume_fuel(delta)
	_check_collision_damage(delta)


func _consume_fuel(delta: float) -> void:
	if current_fuel <= 0.0 or engine_power <= 0.0:
		return
	var load_ratio: float = absf(engine_force) / engine_power
	current_fuel = maxf(current_fuel - fuel_consumption_rate * load_ratio * delta, 0.0)
	EventBus.vehicle_fuel_changed.emit(self, current_fuel)
	if current_fuel <= 0.0:
		EventBus.vehicle_out_of_fuel.emit(self)


func _check_collision_damage(delta: float) -> void:
	var current_speed: float = linear_velocity.length()
	if delta > 0.0:
		var deceleration: float = (_previous_speed - current_speed) / delta
		if deceleration > min_impact_deceleration:
			_apply_damage((deceleration - min_impact_deceleration) * damage_per_deceleration_unit)
	_previous_speed = current_speed


func _apply_damage(amount: float) -> void:
	if amount <= 0.0 or _is_immobilized:
		return
	current_health = maxf(current_health - amount, 0.0)
	EventBus.vehicle_damaged.emit(self, current_health)
	if current_health <= 0.0:
		_is_immobilized = true
		EventBus.vehicle_immobilized.emit(self)


## Restores health (fully, or by `amount`) and clears the immobilized state.
## Called by a repair interaction once that content exists.
func repair(amount: float = -1.0) -> void:
	current_health = max_health if amount < 0.0 else minf(current_health + amount, max_health)
	if current_health > 0.0:
		_is_immobilized = false


## Refills fuel (fully, or by `amount`). Called by a refuel interaction once
## that content exists.
func refuel(amount: float = -1.0) -> void:
	current_fuel = fuel_capacity if amount < 0.0 else minf(current_fuel + amount, fuel_capacity)
