extends Node
## Server-authoritative networking core built on ENetMultiplayerPeer.
## The server (peer id 1) is always authoritative; clients only ever
## request registration and never mutate shared state directly.

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 16

var connected_players: Dictionary = {} # peer_id (int) -> player_name (String)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


## Starts an ENet server. The host is always multiplayer authority.
func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to host on port %d (error %d)." % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	connected_players[multiplayer.get_unique_id()] = "Host"
	return OK


## Connects to a remote server as a client.
func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	if err != OK:
		push_error("NetworkManager: failed to join %s:%d (error %d)." % [ip, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Server-side bookkeeping when any peer joins the session.
func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		print("NetworkManager: peer %d connected." % peer_id)


## Server-side cleanup when a peer leaves the session.
func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	connected_players.erase(peer_id)
	EventBus.player_disconnected.emit(peer_id)


## Fires only on a client once its handshake with the server completes;
## the client then asks the server to register it.
func _on_connected_to_server() -> void:
	register_player.rpc_id(1, str(multiplayer.get_unique_id()))


## Server-authoritative RPC: clients call this to register themselves.
## The server is the sole source of truth for connected_players.
@rpc("any_peer", "reliable")
func register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	connected_players[sender_id] = player_name
	EventBus.player_connected.emit(sender_id, player_name)
