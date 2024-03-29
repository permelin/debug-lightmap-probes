@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("DebugLightmapProbes", "Node3D", preload("debug_lightmap_probes.gd"), preload("tetrahedron.svg"))

func _exit_tree() -> void:
	remove_custom_type("DebugLightmapProbes")

