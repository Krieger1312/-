class_name CarPart
extends RigidBody3D
## Grabbable car part for the VAZ2107 disassembly/assembly minigame.
## `part_id` is matched against PartSlot.part_id -- see PartSlot.gd.

@export var part_id: String = ""
