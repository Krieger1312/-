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
## Emitted by VehicleController every physics tick with its current fuel level.
signal vehicle_fuel_changed(vehicle: Node, current_fuel: float)
## Emitted by VehicleController when its fuel reaches zero.
signal vehicle_out_of_fuel(vehicle: Node)
## Emitted by VehicleController when a crash impact damages it.
signal vehicle_damaged(vehicle: Node, current_health: float)
## Emitted by VehicleController when its health reaches zero and it stops responding to input.
signal vehicle_immobilized(vehicle: Node)
