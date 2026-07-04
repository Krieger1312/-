class_name VehicleSeat
extends Node
## Lets a player enter/exit this vehicle through its own InteractableComponent:
## hands the vehicle multiplayer authority for the interacting peer (so its
## VehicleController reads that peer's input) and tells their
## PlayerController to hide and hand off to this vehicle's camera.
##
## Known limitation: this runs locally on whichever peer interacts, the same
## way PhysicalGrabComponent/CargoSlot/TowComponent's local-only pieces do --
## it is not replicated via RPC, so it's correct for the driver's own peer
## and for solo/host testing, but another peer watching from outside won't
## yet see who's currently driving. Fixing that needs the same kind of
## authority-handoff RPC work TowComponent's docstring already flags as
## unsolved for towing an actively-driven vehicle.

@export var exit_side_offset: float = 2.0

var _driver: PlayerController = null

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _vehicle: VehicleController = get_parent()
@onready var _vehicle_camera: Camera3D = _vehicle.get_node("SpringArm3D/Camera3D")


func _ready() -> void:
	_interactable.on_interact.connect(_on_interact)


func is_occupied() -> bool:
	return _driver != null


## Called by the driver's own PlayerController when it presses interact
## while seated.
func exit() -> void:
	if _driver == null:
		return
	var driver: PlayerController = _driver
	_driver = null
	_vehicle_camera.current = false
	_vehicle.set_multiplayer_authority(0)
	_vehicle.freeze = true
	var exit_position: Vector3 = (
		_vehicle.global_position + _vehicle.global_transform.basis.x * exit_side_offset + Vector3.UP
	)
	driver.exit_vehicle(exit_position)


func _on_interact(interactor: Node) -> void:
	if _driver != null or not (interactor is PlayerController):
		return
	_driver = interactor
	_vehicle.set_multiplayer_authority(interactor.get_multiplayer_authority())
	_vehicle.freeze = not _vehicle.is_multiplayer_authority()
	_vehicle_camera.current = interactor.is_multiplayer_authority()
	interactor.enter_vehicle(self)
