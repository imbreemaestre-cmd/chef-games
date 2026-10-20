@tool
extends Node3D
## Fills a rectangle centred on this node with wind-animated grass clumps (and optional flowers)
## using chunked MultiMeshInstance3D nodes. Blades are generated geometry (no textures).
## Ground height comes from `terrain` (any node with get_height(x, z), e.g. nature-terrain),
## else from physics ray casts onto colliders (use_physics_ray), else this node's Y.

@export var size: Vector2 = Vector2(40, 40): set = _set_size
## Grass clumps per square metre (each clump is 10 blades over ~0.5 m). 8 is a lush lawn, 3 is sparse.
@export_range(0.0, 30.0, 0.1) var density: float = 8.0: set = _set_density
@export var blade_height: float = 0.42: set = _set_height
@export_range(0.0, 1.0) var height_variation: float = 0.45: set = _set_hvar
@export var base_color: Color = Color(0.05, 0.1, 0.03): set = _set_base
@export var tip_color: Color = Color(0.3, 0.42, 0.11): set = _set_tip
@export var dry_color: Color = Color(0.5, 0.45, 0.2): set = _set_dry
## 0 = all lush, 1 = lots of dry patches.
@export_range(0.0, 1.0) var dryness: float = 0.35: set = _set_dryness
@export var wind_strength: float = 1.0: set = _set_wind
@export var wind_direction: Vector2 = Vector2(1, 0.4): set = _set_wind_dir
## Flowers per square metre (0 = none) and their petal colours (one MultiMesh per colour).
@export_range(0.0, 5.0, 0.05) var flower_density: float = 0.6: set = _set_fdensity
@export var flower_colors: PackedColorArray = PackedColorArray([Color(0.95, 0.92, 0.85), Color(0.98, 0.78, 0.2), Color(0.75, 0.42, 0.85), Color(0.95, 0.38, 0.32)]): set = _set_fcolors
## Leave a bare circle of this radius at the centre (spawn point, paths). 0 = none.
@export var clear_radius: float = 0.0: set = _set_clear
@export var chunk_size: float = 10.0: set = _set_chunk
## Chunks farther than this from the camera are hidden (metres).
@export var visibility_range: float = 70.0: set = _set_vis
@export var field_seed: int = 3: set = _set_seed
@export var terrain: NodePath: set = _set_terrain
@export var use_physics_ray: bool = false: set = _set_ray

const GRASS_SHADER := preload("res://starter/nature-grass-field/grass.gdshader")
const FLOWER_SHADER := preload("res://starter/nature-grass-field/flower.gdshader")

static var _clump_mesh: ArrayMesh
static var _flower_mesh: ArrayMesh
var _grass_mat: ShaderMaterial
var _pending := false
var _built: Array[Node] = []

func _ready() -> void:
	_queue()

func _set_size(v: Vector2) -> void: size = v; _queue()
func _set_density(v: float) -> void: density = v; _queue()
func _set_height(v: float) -> void: blade_height = v; _queue()
func _set_hvar(v: float) -> void: height_variation = v; _queue()
func _set_base(v: Color) -> void: base_color = v; _update_material()
func _set_tip(v: Color) -> void: tip_color = v; _update_material()
func _set_dry(v: Color) -> void: dry_color = v; _update_material()
func _set_dryness(v: float) -> void: dryness = v; _update_material()
func _set_wind(v: float) -> void: wind_strength = v; _update_material()
func _set_wind_dir(v: Vector2) -> void: wind_direction = v; _update_material()
func _set_fdensity(v: float) -> void: flower_density = v; _queue()
func _set_fcolors(v: PackedColorArray) -> void: flower_colors = v; _queue()
func _set_clear(v: float) -> void: clear_radius = v; _queue()
func _set_chunk(v: float) -> void: chunk_size = maxf(v, 2.0); _queue()
func _set_vis(v: float) -> void: visibility_range = v; _queue()
func _set_seed(v: int) -> void: field_seed = v; _queue()
func _set_terrain(v: NodePath) -> void: terrain = v; _queue()
func _set_ray(v: bool) -> void: use_physics_ray = v; _queue()

func _queue() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_build.call_deferred()

func _update_material() -> void:
	if _grass_mat == null:
		return
	_grass_mat.set_shader_parameter("base_color", base_color)
	_grass_mat.set_shader_parameter("tip_color", tip_color)
	_grass_mat.set_shader_parameter("dry_color", dry_color)
	_grass_mat.set_shader_parameter("dryness", dryness)
	_grass_mat.set_shader_parameter("wind_strength", wind_strength)
	_grass_mat.set_shader_parameter("wind_dir", wind_direction.normalized() if wind_direction.length() > 0.001 else Vector2(1, 0))

static func _make_clump() -> ArrayMesh:
	## 10 curved, tapered blades spread over a 0.5 m patch; UV.y = 0 root, 1 tip. Unit height.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	for b in 10:
		var a := float(b) / 10.0 * TAU + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var root := dir * rng.randf_range(0.02, 0.17) + side * rng.randf_range(-0.08, 0.08)
		var h := rng.randf_range(0.55, 1.0)
		var lean := rng.randf_range(0.1, 0.32)
		var w := rng.randf_range(0.02, 0.03)
		var rows := 3
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for r in rows + 1:
			var t := float(r) / rows
			var c := root + Vector3.UP * h * t + dir * lean * t * t * h
			var half := w * (1.0 - t * 0.92)
			var l := c - side * half
			var rr := c + side * half
			if r > 0:
				var t0 := float(r - 1) / rows
				var n := side.cross(Vector3.UP * h + dir * lean * 2.0 * t * h).normalized()
				if n.y < 0.0:
					n = -n
				n = (n + Vector3.UP * 1.5).normalized()
				st.set_normal(n)
				st.set_uv(Vector2(0, t0)); st.add_vertex(prev_l)
				st.set_uv(Vector2(1, t0)); st.add_vertex(prev_r)
				st.set_uv(Vector2(0, t)); st.add_vertex(l)
				st.set_uv(Vector2(1, t0)); st.add_vertex(prev_r)
				st.set_uv(Vector2(1, t)); st.add_vertex(rr)
				st.set_uv(Vector2(0, t)); st.add_vertex(l)
			prev_l = l
			prev_r = rr
	return st.commit()

static func _make_flower() -> ArrayMesh:
	## Thin stem (UV.y < 0.5) plus a horizontal petal disc quad (UV in 0.5..1 encodes the head).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 1.0
	var sw := 0.006
	for k in 2:
		var side := Vector3(sw, 0, 0) if k == 0 else Vector3(0, 0, sw)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(-side)
		st.set_uv(Vector2(0.1, 0.0)); st.add_vertex(side)
		st.set_uv(Vector2(0.0, 0.45)); st.add_vertex(Vector3(0, h, 0) - side)
		st.set_uv(Vector2(0.1, 0.0)); st.add_vertex(side)
		st.set_uv(Vector2(0.1, 0.45)); st.add_vertex(Vector3(0, h, 0) + side)
		st.set_uv(Vector2(0.0, 0.45)); st.add_vertex(Vector3(0, h, 0) - side)
	var r := 0.075
	var c := Vector3(0, h, 0)
	var tilt := Vector3(0, 0.03, 0)
	var p := [c + Vector3(-r, 0, -r) - tilt, c + Vector3(r, 0, -r) + tilt, c + Vector3(r, 0, r) + tilt, c + Vector3(-r, 0, r) - tilt]
	var uv := [Vector2(0.5, 0.5), Vector2(1.0, 0.5), Vector2(1.0, 1.0), Vector2(0.5, 1.0)]
	st.set_normal(Vector3.UP)
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i])
		st.add_vertex(p[i])
	return st.commit()

func _height_at(x: float, z: float) -> float:
	var t: Node = get_node_or_null(terrain) if not terrain.is_empty() else null
	if t != null and t.has_method("get_height"):
		return t.call("get_height", x, z)
	if use_physics_ray and not Engine.is_editor_hint():
		var from := Vector3(x, global_position.y + 100.0, z)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 200.0))
		if not hit.is_empty():
			return hit.position.y
	return global_position.y

func _build() -> void:
	_pending = false
	for n: Node in _built:
		if is_instance_valid(n):
			n.queue_free()
	_built.clear()
	if use_physics_ray and terrain.is_empty() and not Engine.is_editor_hint():
		await get_tree().physics_frame
		await get_tree().physics_frame
	if _clump_mesh == null:
		_clump_mesh = _make_clump()
	if _flower_mesh == null:
		_flower_mesh = _make_flower()
	if _grass_mat == null:
		_grass_mat = ShaderMaterial.new()
		_grass_mat.shader = GRASS_SHADER
	_update_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	var cx := maxi(1, ceili(size.x / chunk_size))
	var cz := maxi(1, ceili(size.y / chunk_size))
	var csx := size.x / cx
	var csz := size.y / cz
	var origin := global_position
	var inv := global_transform.affine_inverse()
	var flower_mats: Array[ShaderMaterial] = []
	for col: Color in flower_colors:
		var fm := ShaderMaterial.new()
		fm.shader = FLOWER_SHADER
		fm.set_shader_parameter("petal_color", col)
		fm.set_shader_parameter("wind_strength", wind_strength)
		flower_mats.append(fm)
	for j in cz:
		for i in cx:
			var x0 := -size.x * 0.5 + i * csx
			var z0 := -size.y * 0.5 + j * csz
			# Jittered grid gives even coverage (pure random leaves bald spots).
			var gstep := 1.0 / sqrt(maxf(density, 0.01))
			var gx := maxi(1, int(round(csx / gstep)))
			var gz := maxi(1, int(round(csz / gstep)))
			var xf: Array[Transform3D] = []
			for k in gx * gz:
				var lx := x0 + (float(k % gx) + rng.randf()) * csx / gx
				var lz := z0 + (float(k / gx) + rng.randf()) * csz / gz
				if clear_radius > 0.0:
					var d := Vector2(lx, lz).length()
					if d < clear_radius or (d < clear_radius + 1.5 and rng.randf() > (d - clear_radius) / 1.5):
						continue
				var wp := global_transform * Vector3(lx, 0, lz)
				var hy := _height_at(wp.x, wp.z)
				var s := blade_height * (1.0 - height_variation * rng.randf())
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(blade_height * 2.2, s, blade_height * 2.2))
				xf.append(inv * Transform3D(basis, Vector3(wp.x, hy, wp.z)))
			if not xf.is_empty():
				_add_chunk("Grass_%d_%d" % [i, j], _clump_mesh, _grass_mat, xf, blade_height * 1.3)
			if flower_mats.is_empty() or flower_density <= 0.0:
				continue
			var per: Array = []
			for m in flower_mats.size():
				per.append([] as Array[Transform3D])
			var fn := int(round(flower_density * csx * csz))
			for k in fn:
				var lx := x0 + rng.randf() * csx
				var lz := z0 + rng.randf() * csz
				if clear_radius > 0.0 and Vector2(lx, lz).length() < clear_radius + 0.5:
					continue
				var wp := global_transform * Vector3(lx, 0, lz)
				var hy := _height_at(wp.x, wp.z)
				var s := blade_height * rng.randf_range(0.75, 1.1)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(blade_height * 2.2, s, blade_height * 2.2))
				(per[rng.randi() % flower_mats.size()] as Array[Transform3D]).append(inv * Transform3D(basis, Vector3(wp.x, hy, wp.z)))
			for m in flower_mats.size():
				if not (per[m] as Array).is_empty():
					_add_chunk("Flowers_%d_%d_%d" % [i, j, m], _flower_mesh, flower_mats[m], per[m], blade_height * 1.6)

func _add_chunk(nm: String, mesh: Mesh, mat: Material, xf: Array[Transform3D], h: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	var box := AABB()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k])
		var b := AABB(xf[k].origin - Vector3(0.3, 0.05, 0.3), Vector3(0.6, h + 0.1, 0.6))
		box = b if k == 0 else box.merge(b)
	mm.custom_aabb = box
	var node := MultiMeshInstance3D.new()
	node.name = nm
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = visibility_range
	node.visibility_range_end_margin = 8.0
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(node, false, Node.INTERNAL_MODE_FRONT)
	_built.append(node)
