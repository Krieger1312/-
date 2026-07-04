class_name Hud
extends CanvasLayer
## Per-player local HUD: shared money, current vehicle's fuel/health (only
## while seated), and an interaction prompt. Instanced under Player.tscn, so
## every peer's own copy exists on every other peer's screen too -- guarded
## off for anyone but the owning peer in _ready(), the same way
## PlayerController gates its camera.

var _player: PlayerController
var _tracked_vehicle: VehicleController = null

@onready var _money_label: Label = $Margin/VBox/MoneyLabel
@onready var _vehicle_stats: Control = $Margin/VBox/VehicleStats
@onready var _fuel_bar: ProgressBar = $Margin/VBox/VehicleStats/FuelBar
@onready var _health_bar: ProgressBar = $Margin/VBox/VehicleStats/HealthBar
@onready var _prompt_label: Label = $Margin/VBox/PromptLabel


func _ready() -> void:
	_player = get_parent() as PlayerController
	visible = _player.is_multiplayer_authority()
	if not visible:
		return
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.vehicle_fuel_changed.connect(_on_vehicle_fuel_changed)
	EventBus.vehicle_damaged.connect(_on_vehicle_damaged)
	_money_label.text = "$%d" % QuestManager.money
	_vehicle_stats.visible = false
	_prompt_label.visible = false


func _process(_delta: float) -> void:
	var seat: VehicleSeat = _player.current_seat
	var seat_vehicle: VehicleController = seat.get_vehicle() if seat != null else null
	if seat_vehicle != _tracked_vehicle:
		_tracked_vehicle = seat_vehicle
		_vehicle_stats.visible = _tracked_vehicle != null
		if _tracked_vehicle != null:
			_fuel_bar.max_value = _tracked_vehicle.fuel_capacity
			_health_bar.max_value = _tracked_vehicle.max_health
			_fuel_bar.value = _tracked_vehicle.current_fuel
			_health_bar.value = _tracked_vehicle.current_health

	if seat != null:
		_prompt_label.visible = true
		_prompt_label.text = "Press E to exit"
	elif _player.focused_interactable != null:
		_prompt_label.visible = true
		_prompt_label.text = _player.focused_interactable.prompt_text
	else:
		_prompt_label.visible = false


func _on_money_changed(amount: int) -> void:
	_money_label.text = "$%d" % amount


func _on_vehicle_fuel_changed(vehicle: Node, current_fuel: float) -> void:
	if vehicle == _tracked_vehicle:
		_fuel_bar.value = current_fuel


func _on_vehicle_damaged(vehicle: Node, current_health: float) -> void:
	if vehicle == _tracked_vehicle:
		_health_bar.value = current_health
