extends Node
## Server-authoritative networking core built on ENetMultiplayerPeer.
## The server (peer id 1) is always authoritative; clients only ever
## request registration and never mutate shared state directly.
## Registration flow adapted from devmoreir4/godot-3d-multiplayer-template:
## a joining client registers itself with the server, which echoes back
## the full roster so every peer converges on the same player list.

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 16
const MAX_NICK_LENGTH: int = 24
const MAX_ADDRESS_LENGTH: int = 253
const SCOOTER_TYPES: Array[String] = ["vortex", "escooter"]

var connected_players: Dictionary = {} # peer_id (int) -> player_name (String)

## Which of the two personal scooters (Stels Vortex / electric kick scooter)
## each of the first two connected peers starts next to this session,
## peer_id (int) -> "vortex"/"escooter". Rolled once per hosting session
## (see host_game()) so it's random which peer gets which each time, not a
## fixed assignment. Peers beyond the first two get no personal scooter.
var scooter_assignment: Dictionary = {}

var _scooter_pool: Array[String] = []
var _pending_nickname: String = "Player"


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Starts an ENet server. The host is always multiplayer authority (peer id 1).
func host_game(nickname: String = "Host", port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to host on port %d (error %d)." % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	_scooter_pool = SCOOTER_TYPES.duplicate()
	_scooter_pool.shuffle()
	var host_id: int = multiplayer.get_unique_id()
	connected_players[host_id] = _sanitize_nickname(nickname, "Host")
	EventBus.player_connected.emit(host_id, connected_players[host_id])
	_assign_and_broadcast_scooter(host_id)
	return OK


## Connects to a remote server as a client.
func join_game(ip: String, nickname: String = "Player", port: int = DEFAULT_PORT) -> Error:
	var address: String = _sanitize_address(ip)
	if address.is_empty():
		return ERR_INVALID_PARAMETER
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: failed to join %s:%d (error %d)." % [address, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	_pending_nickname = nickname
	return OK


## Server-side bookkeeping when any peer joins the ENet session.
func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		print("NetworkManager: peer %d connected." % peer_id)


## Runs on every peer when a peer leaves; the server is the source of truth
## but clients also drop the stale entry from their local roster copy.
func _on_peer_disconnected(peer_id: int) -> void:
	connected_players.erase(peer_id)
	EventBus.player_disconnected.emit(peer_id)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	connected_players.clear()


## Fires only on the connecting client once its handshake completes; it then
## asks the server to register it and add it to the shared roster.
func _on_connected_to_server() -> void:
	var self_id: int = multiplayer.get_unique_id()
	var sanitized: String = _sanitize_nickname(_pending_nickname, "Player_%d" % self_id)
	connected_players[self_id] = sanitized
	EventBus.player_connected.emit(self_id, sanitized)
	register_player.rpc_id(1, sanitized)


## Server-authoritative RPC: a client calls this on the server to register
## itself; the server then echoes the full roster back to that client alone.
@rpc("any_peer", "reliable")
func register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0 or connected_players.has(sender_id):
		return
	var sanitized: String = _sanitize_nickname(player_name, "Player_%d" % sender_id)
	connected_players[sender_id] = sanitized
	EventBus.player_connected.emit(sender_id, sanitized)
	for peer_id: int in connected_players:
		_sync_roster_entry.rpc_id(sender_id, peer_id, connected_players[peer_id])
	_sync_roster_entry.rpc(sender_id, sanitized)
	# Separate from the roster sync above (and its "already have it" guard,
	# which the joining client's own early self-registered entry would
	# always trip) -- this is the only path that tells a client its own
	# scooter assignment, so it can't be skipped that way.
	for peer_id: int in scooter_assignment:
		_broadcast_scooter_assignment.rpc_id(sender_id, peer_id, scooter_assignment[peer_id])
	_assign_and_broadcast_scooter(sender_id)


## Authority-only RPC: replicates one roster entry to clients that don't have it yet.
@rpc("authority", "reliable")
func _sync_roster_entry(peer_id: int, player_name: String) -> void:
	if connected_players.has(peer_id):
		return
	connected_players[peer_id] = player_name
	EventBus.player_connected.emit(peer_id, player_name)


## Rolls the next scooter off this session's shuffled pool for `peer_id`
## (only the first two callers get one) and broadcasts it to every peer.
func _assign_and_broadcast_scooter(peer_id: int) -> void:
	if scooter_assignment.has(peer_id) or _scooter_pool.is_empty():
		return
	var scooter_type: String = _scooter_pool.pop_front()
	_broadcast_scooter_assignment.rpc(peer_id, scooter_type)


## call_local so the server (which is a peer too, and may itself be one of
## the two assigned peers) applies its own broadcast instead of only ever
## sending it to others.
@rpc("authority", "call_local", "reliable")
func _broadcast_scooter_assignment(peer_id: int, scooter_type: String) -> void:
	scooter_assignment[peer_id] = scooter_type
	EventBus.player_spawn_ready.emit(peer_id, scooter_type)


func _sanitize_nickname(nickname: String, fallback: String) -> String:
	var clean: String = nickname.strip_edges()
	if clean.is_empty():
		clean = fallback
	return clean.substr(0, MAX_NICK_LENGTH)


func _sanitize_address(address: String) -> String:
	var clean: String = address.strip_edges()
	if clean.is_empty() or clean.length() > MAX_ADDRESS_LENGTH:
		return ""
	if clean.contains("://") or clean.contains("/") or clean.contains("\\") or clean.contains(":"):
		return ""
	return clean
