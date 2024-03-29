@tool
extends MeshInstance3D

@export var color1 := Color(0.27, 0.27, 0.6, 0.05)
@export var color2 := Color(0.33, 0.33, 0.6, 0.05)
@export var color3 := Color(0.40, 0.40, 0.6, 0.05)
@export var color4 := Color(0.47, 0.47, 0.6, 0.05)
@export var color_alert := Color.RED

const EMPTY_LEAF := 2 ** 31 - 1

var imesh: ImmediateMesh
var actually_draw := true


func _process(_dt: float) -> void:
	actually_draw = true


func draw_tetrahedron(
	pos: Vector3,
	lm_node: LightmapGI,
	bsp: PackedInt32Array,
	tetrahedra: PackedInt32Array,
	points: PackedVector3Array,
	bounds: AABB,
	tolerance: float
) -> float:

	if !(bounds).has_point(pos):
		if actually_draw: imesh.clear_surfaces()
		return 0

	var tracked_position := pos * lm_node.global_transform

	if !mesh: _init_mesh()

	var tetra_id := _bsp_search(bsp, tracked_position)
	if tetra_id == EMPTY_LEAF:
		print("Empty leaf in BSP tree. This should not happen.")
		return 0

	var tetra := tetrahedra.slice(tetra_id * 4, tetra_id * 4 + 4)
	var vertices: Array[Vector3] = [points[tetra[0]], points[tetra[1]], points[tetra[2]], points[tetra[3]]]

	var distance := distance_to_tetrahedron(vertices, tracked_position)

	if !actually_draw and distance == 0:
		# We've already drawn this frame. This is an optimization for when
		# programmatically checking many points in succession.
		return distance

	imesh.clear_surfaces()
	imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	var face_colors: Array[Color] = [color1, color2, color3, color4]

	for i in 4:
		imesh.surface_set_color(face_colors[i] if distance <= tolerance else color_alert)
		imesh.surface_add_vertex(lm_node.global_transform * vertices[i])
		imesh.surface_add_vertex(lm_node.global_transform * vertices[(i + 1) % 4])
		imesh.surface_add_vertex(lm_node.global_transform * vertices[(i + 2) % 4])

	imesh.surface_end()

	actually_draw = false

	return distance


func _init_mesh() -> void:
	imesh = ImmediateMesh.new()
	imesh.resource_local_to_scene = true
	mesh = imesh


# This function mimics LightStorage::lightmap_tap_sh_light() in the engine so
# hopefully we'll find the same node as it does
func _bsp_search(tree: PackedInt32Array, pos: Vector3) -> int:
	var node := 0

	# Root node is zero. Negative ids are references to a tetrahedron.
	while node >= 0:
		# struct BSPNode {
		#     Plane plane;
		#     int32_t over;
		#     int32_t under;
		# }
		var plane_data := tree.slice(node * 6, node * 6 + 4).to_byte_array().to_float32_array()
		var normal := Vector3(plane_data[0], plane_data[1], plane_data[2])
		var plane := Plane(normal, plane_data[3])

		if plane.is_point_over(pos):
			node = tree[node * 6 + 4]
		else:
			node = tree[node * 6 + 5]

	return abs(node) - 1


func distance_to_tetrahedron(vertices: Array[Vector3], point: Vector3) -> float:
	for i in 4:
		var plane := Plane(vertices[i], vertices[(i + 1) % 4], vertices[(i + 2) % 4])
		# The vertices don't follow any dependable order, so the plane can get
		# a flipped normal, but we know that the unused vertex of the
		# tetrahedron must be on the same side as the point if it is inside.
		var d = plane.distance_to(point)
		var e = plane.distance_to(vertices[(i + 3) % 4])
		if sign(d) != sign(e):
			return abs(d)

	return 0

