extends Node
## Server-authoritative delivery-quest tracking and the shared money pool
## that rewards them. Only the authority checks completion each tick; the
## reward pool is broadcast through EventBus so clients stay in sync without
## simulating it themselves. Deliveries don't care how the cargo got there
## (carried by hand, riding in a CargoSlot, whatever) -- completion is just
## a distance check against the dropoff point, so this stays decoupled from
## PhysicalGrabComponent/CargoSlot.

@export var default_reward: int = 50

var money: int = 0

var _active: Array[Dictionary] = []


func _ready() -> void:
	money = SaveManager.load_game().get("money", 0)


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var still_active: Array[Dictionary] = []
	for delivery in _active:
		var cargo: Node3D = delivery["cargo"]
		var dropoff: Node3D = delivery["dropoff"]
		if cargo == null or dropoff == null:
			continue
		if cargo.global_position.distance_to(dropoff.global_position) <= delivery["radius"]:
			_complete_delivery(delivery)
		else:
			still_active.append(delivery)
	_active = still_active


## Registers a delivery: reaching `dropoff` with `cargo` grants `reward`.
## Content-level API -- call from a map's setup code, e.g. DeliveryQuest.gd.
func start_delivery(
	cargo: Node3D, dropoff: Node3D, reward: int = default_reward, radius: float = 3.0
) -> void:
	_active.append({"cargo": cargo, "dropoff": dropoff, "reward": reward, "radius": radius})


func _complete_delivery(delivery: Dictionary) -> void:
	money += delivery["reward"]
	EventBus.delivery_completed.emit(delivery["cargo"], delivery["reward"])
	EventBus.money_changed.emit(money)
	SaveManager.save_game({"money": money})
