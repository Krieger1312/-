extends Node
## Global signal bus. All cross-system communication should go through here
## instead of direct node references, keeping components decoupled.

## Emitted by NetworkManager when a player is registered on the server.
signal player_connected(peer_id: int, player_name: String)
## Emitted by NetworkManager when a player disconnects.
signal player_disconnected(peer_id: int)
## Emitted by TimeServer every tick with the current in-game hour.
signal time_updated(current_hour: float)
## Emitted by an InteractableComponent when it gains focus.
signal interactable_focused(interactable: Node)
## Emitted by an InteractableComponent when it loses focus.
signal interactable_unfocused(interactable: Node)
