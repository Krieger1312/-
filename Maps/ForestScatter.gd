extends Node3D
## Greybox placeholder for forest cover: scatters simple trunk+canopy cylinder
## "trees" across a rectangular area at load time. Deterministic per seed_value
## so the layout is stable across runs until real forest assets replace it.

@export var area_size: Vector2 = Vector2(250.0, 300.0)
@export var tree_count: int = 60
@export var seed_value: int = 1312


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for i in tree_count:
		var x: float = rng.randf_range(-area_size.x / 2.0, area_size.x / 2.0)
		var z: float = rng.randf_range(-area_size.y / 2.0, area_size.y / 2.0)

		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.15
		trunk_mesh.bottom_radius = 0.2
		trunk_mesh.height = 2.0
		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.position = Vector3(x, 1.0, z)
		add_child(trunk)

		var canopy_mesh := CylinderMesh.new()
		canopy_mesh.top_radius = 0.05
		canopy_mesh.bottom_radius = 1.2
		canopy_mesh.height = 3.0
		var canopy := MeshInstance3D.new()
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(x, 3.0, z)
		add_child(canopy)
