extends Node3D
## Builds the city/forest ground zones, road network, and river from real
## OpenStreetMap geometry baked into Maps/data/novozybkov_map.json (fetched
## via the Overpass API and reprojected to local meters by the one-off
## script Maps/data/build_novozybkov_data.py -- that script does not run in
## engine, only its JSON output is checked in). One unit here is one meter,
## centered on the town per the JSON's origin_lat/origin_lon.
##
## Roads and the river are each a single merged mesh (built with
## SurfaceTool) rather than one node per segment, since the real road
## network is thousands of segments -- one StaticBody3D per segment would
## bloat the scene tree for no benefit.

const DATA_PATH := "res://Maps/data/novozybkov_map.json"

@export var road_color: Color = Color(0.12, 0.12, 0.13, 1.0)
@export var river_color: Color = Color(0.15, 0.35, 0.6, 1.0)
@export var city_color: Color = Color(0.55, 0.55, 0.58, 1.0)
@export var forest_color: Color = Color(0.22, 0.42, 0.2, 1.0)
@export var ground_thickness: float = 1.0
@export var ground_padding: float = 1500.0
@export var road_height: float = 0.05
@export var river_height: float = 0.03
@export var river_width: float = 12.0


func _ready() -> void:
	var data: Dictionary = _load_data()
	if data.is_empty():
		return
	_build_ground_zone("CityGround", data.get("city_bounds", {}), city_color)
	_build_ground_zone("ForestGround", data.get("forest_bounds", {}), forest_color)
	_build_roads(data.get("roads", []))
	_build_river(data.get("river_lines", []))


func _load_data() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("OsmMapBuilder: missing %s" % DATA_PATH)
		return {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _build_ground_zone(zone_name: String, bounds: Dictionary, color: Color) -> void:
	if bounds.is_empty():
		return
	var min_x: float = bounds["min_x"] - ground_padding
	var max_x: float = bounds["max_x"] + ground_padding
	var min_z: float = bounds["min_z"] - ground_padding
	var max_z: float = bounds["max_z"] + ground_padding
	var size := Vector3(max_x - min_x, ground_thickness, max_z - min_z)
	var center := Vector3((min_x + max_x) / 2.0, -ground_thickness / 2.0, (min_z + max_z) / 2.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = color

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material

	var shape := BoxShape3D.new()
	shape.size = size

	var body := StaticBody3D.new()
	body.name = zone_name
	body.position = center
	add_child(body)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)


func _build_roads(roads: Array) -> void:
	if roads.is_empty():
		return
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision_faces := PackedVector3Array()

	for road in roads:
		var points: Array = road["points"]
		var width: float = road["width"]
		for i in range(points.size() - 1):
			var quad: Array = _segment_quad(points[i], points[i + 1], width, road_height)
			if quad.is_empty():
				continue
			_add_quad(surface_tool, quad)
			collision_faces.append_array(_quad_triangles(quad))

	var material := StandardMaterial3D.new()
	material.albedo_color = road_color
	surface_tool.set_material(material)
	var mesh: ArrayMesh = surface_tool.commit()

	var body := StaticBody3D.new()
	body.name = "Roads"
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	if not collision_faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = shape
		body.add_child(collision)


func _build_river(lines: Array) -> void:
	if lines.is_empty():
		return
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for line in lines:
		var points: Array = line
		for i in range(points.size() - 1):
			var quad: Array = _segment_quad(points[i], points[i + 1], river_width, river_height)
			if quad.is_empty():
				continue
			_add_quad(surface_tool, quad)

	var material := StandardMaterial3D.new()
	material.albedo_color = river_color
	surface_tool.set_material(material)
	var mesh: ArrayMesh = surface_tool.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "River"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)


## Returns [p0, p1, p2, p3] forming a flat quad strip segment between two
## (x, z) points at the given width and height, or [] if the points coincide.
func _segment_quad(point_a: Array, point_b: Array, width: float, height: float) -> Array:
	var a := Vector2(point_a[0], point_a[1])
	var b := Vector2(point_b[0], point_b[1])
	var direction: Vector2 = b - a
	if direction.length() < 0.01:
		return []
	direction = direction.normalized()
	var normal: Vector2 = Vector2(-direction.y, direction.x) * (width / 2.0)

	return [
		Vector3(a.x + normal.x, height, a.y + normal.y),
		Vector3(a.x - normal.x, height, a.y - normal.y),
		Vector3(b.x - normal.x, height, b.y - normal.y),
		Vector3(b.x + normal.x, height, b.y + normal.y),
	]


func _add_quad(surface_tool: SurfaceTool, quad: Array) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		surface_tool.set_normal(Vector3.UP)
		surface_tool.add_vertex(quad[index])


func _quad_triangles(quad: Array) -> PackedVector3Array:
	var triangles := PackedVector3Array()
	for index in [0, 1, 2, 0, 2, 3]:
		triangles.append(quad[index])
	return triangles
