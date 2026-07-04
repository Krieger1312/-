class_name PlayerSpawner
extends Node
## Spawns each connected peer's Player.tscn once their personal scooter
## assignment is known (see NetworkManager.scooter_assignment), placing them
## next to whichever of the two scooters they got. Reacts to
## EventBus.player_spawn_ready rather than player_connected -- the latter
## fires before the (randomized) scooter assignment exists, so there'd be
## nowhere sensible yet to place the new Player.
##
## Known limitation: this game's co-op loop is built for exactly two
## players, matching the two personal scooters -- a 3rd+ peer never gets a
## scooter assignment (see NetworkManager) and so never spawns here.
## Known limitation: like PhysicalGrabComponent/CargoSlot/TowComponent
## elsewhere in this project, spawning runs identically (not through a
## MultiplayerSpawner) on every peer reacting to the same replicated event,
## relying on every peer's scene tree staying symmetric rather than a
## single authoritative spawn being replicated to the rest -- correct for
## this project's current solo-host/symmetric-simulation stage, not real
## server-authoritative spawning.

const PLAYER_SCENE: PackedScene = preload("res://Player/Player.tscn")

@export var vortex_spawn_path: NodePath
@export var escooter_spawn_path: NodePath


func _ready() -> void:
	EventBus.player_spawn_ready.connect(_on_player_spawn_ready)


func _on_player_spawn_ready(peer_id: int, scooter_type: String) -> void:
	if has_node(str(peer_id)):
		return
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	add_child(player)
	player.global_position = _spawn_position_for(scooter_type)


func _spawn_position_for(scooter_type: String) -> Vector3:
	var spawn_path: NodePath = vortex_spawn_path if scooter_type == "vortex" else escooter_spawn_path
	var spawn_node: Node3D = get_node(spawn_path)
	return spawn_node.global_position
