extends Node
## Server-authoritative day/night clock. Only the multiplayer authority
## (the server) advances time; it broadcasts updates through EventBus so
## clients stay in sync without simulating time themselves.

@export var day_length_seconds: float = 1200.0
@export var start_hour: float = 6.0

var current_hour: float = start_hour

var _tick_timer: Timer


func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.one_shot = false
	add_child(_tick_timer)
	_tick_timer.timeout.connect(_on_tick)
	if is_multiplayer_authority():
		_tick_timer.start()


## Advances the clock by one tick and notifies the rest of the game.
func _on_tick() -> void:
	if not is_multiplayer_authority():
		return
	var hours_per_tick: float = 24.0 / day_length_seconds
	current_hour = fmod(current_hour + hours_per_tick, 24.0)
	EventBus.time_updated.emit(current_hour)
