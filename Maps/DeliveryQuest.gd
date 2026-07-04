extends Node3D
## Content-level wiring for one delivery quest: registers `cargo` with
## QuestManager on ready, using this node's own position as the dropoff.
## Drop this into a map scene next to an already-placed cargo prop; it does
## not spawn or place anything itself.

@export var cargo: NodePath
@export var reward: int = 50
@export var complete_radius: float = 3.0


func _ready() -> void:
	if not is_multiplayer_authority():
		return
	var cargo_node: Node3D = get_node_or_null(cargo)
	if cargo_node == null:
		push_warning("DeliveryQuest: cargo not found at %s" % cargo)
		return
	QuestManager.start_delivery(cargo_node, self, reward, complete_radius)
