extends Node
## Lets a player repair and refuel the vehicle this is attached to by
## interacting with it directly. Placeholder for real fuel/repair points --
## gating this to actual gas stations/garages placed in the map is
## content-phase work, not solved here.

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _vehicle: VehicleController = get_parent()


func _ready() -> void:
	_interactable.on_interact.connect(_on_interact)


func _on_interact(_interactor: Node) -> void:
	_vehicle.refuel()
	_vehicle.repair()
