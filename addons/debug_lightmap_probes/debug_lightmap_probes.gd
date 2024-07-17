@tool
extends Node3D

## Only show in-editor and not when running the scene
@export var editor_only: bool = true
## How far outside the tetrahedron can we be before we show it in red
@export var tolerance := 0.5
## Print an alert in addition to changing the color
@export var print_alerts: bool = false

@export_group("Sweep entire scene")
## How many coordinates in the scene to check
@export var sample_points: int = 3000000
## Set this if you don't want to scan the full height of the lightmap (which
## can become higher than the rest of the scene)
@export var max_height: float = 0
## In addition to a summary at the end, also print every miss
@export var print_sweep_alerts: bool = false
## Print BSP tree stats before sweep (this can take some time)
@export var print_tree_stats: bool = false
## Start sweep of entire scene (uncheck to stop), which is probably completely
## useless to you unless you're working on debugging Godot itself
@export var sweep_now: bool = false:
	set(v):
		sweep_now = v
		if sweep_now and !sweeping and lm_node:
			await get_tree().process_frame
			sweep()


var lm_node: LightmapGI
var points: PackedVector3Array
var tetrahedra: PackedInt32Array
var bsp: PackedInt32Array
var bounds: AABB

var sweeping = false


func _ready() -> void:
	_load_scene()

	if editor_only and !Engine.is_editor_hint():
		return

	lm_node = _find_lightmap_node()
	if !lm_node:
		return

	_read_lightmap_data()

	_draw_probes()
	_draw_tetrahedron(global_position)

	@warning_ignore("return_value_discarded")
	# At the moment, this does nothing since LightmapGIData unfortunately
	# doesn't emit a changed signal.
	lm_node.light_data.changed.connect(_read_lightmap_data)

	set_notify_transform(true)


func _notification(event: int) -> void:
	if event == NOTIFICATION_TRANSFORM_CHANGED and !sweeping:
		var distance := _draw_tetrahedron(global_position)
		if print_alerts and distance > tolerance:
			print("Outside tetrahedron by %.4f at %v" % [distance, global_position])


func _draw_tetrahedron(pos: Vector3) -> float:
	@warning_ignore("unsafe_method_access")
	return $Tetrahedron.draw_tetrahedron(pos, lm_node, bsp, tetrahedra, points, bounds, tolerance)


func _draw_probes() -> void:
	@warning_ignore("unsafe_method_access")
	$Probes.draw_probes(lm_node, points)


func _find_lightmap_node() -> LightmapGI:
	var scene: Node
	if Engine.is_editor_hint():
		scene = get_tree().edited_scene_root
	else:
		scene = get_tree().current_scene

	for node: LightmapGI in scene.find_children("", "LightmapGI"):
		# If there are multiple lightmaps in the scene we just pick the first
		# valid one.
		if node.light_data:
			return node

	print("No baked lightmaps found in scene")

	return null


func _read_lightmap_data() -> void:
	if !lm_node.light_data:
		return

	var lm_data: RID = lm_node.light_data.get_rid()
	bsp = RenderingServer.lightmap_get_probe_capture_bsp_tree(lm_data)
	points = RenderingServer.lightmap_get_probe_capture_points(lm_data)
	tetrahedra = RenderingServer.lightmap_get_probe_capture_tetrahedra(lm_data)

	# I can't find a way to get the lightmap's actual AABB from GDScript so we
	# have to recreate it ourselves.
	bounds = AABB()
	bounds.position = lm_node.global_transform * points[0]
	for point in points:
		bounds = bounds.expand(lm_node.global_transform * point)


## Godot plugin custom types and named classes can't be scenes. This is
## a workaround. It will load a scene with the same path and basename as this
## script and then steal all the children from the root node.
func _load_scene() -> void:
	if scene_file_path:  # We're loaded as part of our scene, not stand-alone
		return

	var script_path: String = get_script().resource_path
	var scene_path: String = script_path.get_basename() + ".tscn"
	var scene: Node = (load(scene_path) as PackedScene).instantiate()

	for child in scene.get_children():
		child.set_owner(null)
		child.reparent(self, false)

	scene.queue_free()


func sweep() -> void:
	sweeping = true

	_read_lightmap_data()
	_draw_probes()

	var sweep_bounds := bounds
	if max_height > 0:
		sweep_bounds.size.y = min(sweep_bounds.size.y, max_height)

	var step_size: float = (sweep_bounds.size.x * sweep_bounds.size.y * sweep_bounds.size.z / sample_points) ** (1.0/3)
	print("Sweep started with step size %0.3f m" % step_size)

	if print_tree_stats:
		var stats := _tree_stats(bsp)
		print("Tree min depth: ", stats[1], ", max depth: ", stats[2], ", nodes: ", stats[0],
				", probes: ", points.size(), ", tetrahedra: ", tetrahedra.size() / 4,
				", mem: ", bsp.size() * 4 / 1048576, " MB")

	var frame_time := Time.get_ticks_usec()

	var misses := 0
	var total_distance := 0.0
	var scanned_positions := 0

	var y := sweep_bounds.position.y
	while y <= sweep_bounds.position.y + sweep_bounds.size.y:
		var x := sweep_bounds.position.x
		while x <= sweep_bounds.position.x + sweep_bounds.size.x:
			var z := sweep_bounds.position.z
			while z <= sweep_bounds.position.z + sweep_bounds.size.z:
				if !sweep_now:
					_print_sweep_result(misses, scanned_positions, total_distance, sweep_bounds)
					sweeping = false
					return

				var pos := Vector3(x, y, z)
				var distance := _draw_tetrahedron(pos)

				if distance > tolerance:
					misses += 1
					total_distance += distance
					if print_sweep_alerts:
						print("Outside tetrahedron by %.4f at %v" % [distance, pos])

				scanned_positions += 1

				var now := Time.get_ticks_usec()
				if now - frame_time > 32000:
					await get_tree().process_frame
					frame_time = now

				z += step_size
			x += step_size
		y += step_size

	_print_sweep_result(misses, scanned_positions, total_distance, sweep_bounds)
	sweep_now = false
	sweeping = false


func _print_sweep_result(misses: int, scanned_positions: int, distance: float, sweep_bounds: AABB) -> void:
	var distance_avg: float = distance / misses if distance > 0 else 0.0
	var misses_proc: float = float(misses * 100) / scanned_positions
	var version := Engine.get_version_info()

	print(misses, " misses",
			" (%.2f m tolerance)" % tolerance,
			" out of ", scanned_positions,
			" (%.3f%%)" % misses_proc,
			" by %.2f m average" % distance_avg,
			" for ", points.size(), " probes",
			" inside %.1v" % sweep_bounds.size,
			" with %d.%d.%s %s" % [version.major, version.minor, version.status, version.hash.left(8)])


## Returns an array with size 3, holding [node count, min depth, max depth]
func _tree_stats(tree: PackedInt32Array, node: int = 0) -> Array[int]:
	if node < 0:
		# This is not an actual node, it's a reference to a tetrahedron.
		return [0, 0, 0]

	var over := _tree_stats(tree, tree[node * 6 + 4])
	var under := _tree_stats(tree, tree[node * 6 + 5])

	return [1 + over[0] + under[0], 1 + min(over[1], under[1]), 1 + max(over[2], under[2])]

