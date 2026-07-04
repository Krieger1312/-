class_name InteractableComponent
extends Node
## Reusable interaction component. Attach as a child of any object to make
## it interactable without coupling that object to player or UI code.
## Communicates only through its own signals and EventBus.

signal on_interact(interactor: Node)
signal on_focus(interactor: Node)
signal on_unfocus(interactor: Node)

@export var prompt_text: String = "Interact"
@export var interaction_range: float = 2.0


## Called by whatever detects focus (e.g. a player's interaction raycast).
func focus(interactor: Node) -> void:
	on_focus.emit(interactor)
	EventBus.interactable_focused.emit(self)


## Called by whatever loses focus on this interactable.
func unfocus(interactor: Node) -> void:
	on_unfocus.emit(interactor)
	EventBus.interactable_unfocused.emit(self)


## Triggers the interaction; the owning node listens to on_interact to react.
func interact(interactor: Node) -> void:
	on_interact.emit(interactor)
