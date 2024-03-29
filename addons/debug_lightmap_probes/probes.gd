@tool
extends MultiMeshInstance3D


func draw_probes(lm_node: LightmapGI, points: PackedVector3Array) -> void:
	_init_mesh()

	multimesh.instance_count = points.size()

	for i in points.size():
		# Probes are positioned relative to the LightmapGI node. This node
		# is top level, so we don't have to compensate for our own position.
		multimesh.set_instance_transform(i, lm_node.global_transform.translated(points[i]))


func _init_mesh() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	var mesh := SphereMesh.new()
	mesh.material = material
	mesh.radius = 0.15
	mesh.height = 0.3
	mesh.rings = 16

	multimesh = MultiMesh.new()
	multimesh.resource_local_to_scene = true
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
