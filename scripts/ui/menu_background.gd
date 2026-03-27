## MenuBackground — 3D showroom scene for the main menu.
## Displays the player's vehicle on a lit platform with a neon city skyline.
## Camera orbits smoothly based on mouse position.
extends Node3D

# ─── Camera orbit ──────────────────────────────────────────────────────────────
var _camera: Camera3D
var _cam_pivot: Node3D
var _target_yaw: float   = 0.0   # Driven by mouse X position
var _target_pitch: float = -0.18 # Driven by mouse Y position
var _current_yaw: float  = 0.0
var _current_pitch: float = -0.18

const CAM_DISTANCE   := 14.0
const CAM_HEIGHT     := 3.5
const CAM_LERP_SPEED := 2.5
const YAW_RANGE      := 0.6    # Radians of orbit from center mouse
const PITCH_RANGE    := 0.25

# ─── Vehicle display ──────────────────────────────────────────────────────────
var _vehicle_mesh: Node3D
var _bob_time: float = 0.0

# ─── Materials (cached) ──────────────────────────────────────────────────────
var _vehicle_color: Color
var _accent_color: Color = Color(0.3, 0.85, 1.0)

func _ready() -> void:
	_vehicle_color = GameManager.selected_vehicle_color
	_build_environment()
	_build_lighting()
	_build_ground()
	_build_vehicle()
	_build_city_backdrop()
	_build_camera()

# ─── Environment ──────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.007, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.10, 0.16, 0.38)
	env.ambient_light_energy = 0.80
	env.fog_enabled      = true
	env.fog_density      = 0.008
	env.fog_light_color  = Color(0.04, 0.09, 0.26)
	env.fog_sun_scatter  = 0.0
	env.glow_enabled     = true
	env.glow_normalized  = true
	env.glow_intensity   = 0.85
	env.glow_bloom       = 0.10
	env.glow_blend_mode  = Environment.GLOW_BLEND_MODE_ADDITIVE
	var gl := [0.0, 0.6, 1.0, 0.8, 0.4, 0.2, 0.0]
	for i in gl.size():
		env.set_glow_level(i, gl[i])
	env_node.environment = env
	add_child(env_node)

func _build_lighting() -> void:
	# No sun/moon — all lighting comes from track neons
	pass

# ─── Ground platform ─────────────────────────────────────────────────────────
func _build_ground() -> void:
	# Large dark ground plane
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	ground.mesh = pm
	ground.position = Vector3.ZERO
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color     = Color(0.015, 0.02, 0.035)
	gmat.emission_enabled = true
	gmat.emission         = Color(0.01, 0.015, 0.03)
	gmat.emission_energy_multiplier = 0.3
	gmat.metallic  = 0.8
	gmat.roughness = 0.4
	ground.material_override = gmat
	add_child(ground)

	# Neon ring around vehicle platform
	var ring_color := _accent_color
	for i in range(36):
		var angle := float(i) / 36.0 * TAU
		var r := 6.0
		var pos := Vector3(cos(angle) * r, 0.01, sin(angle) * r)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 0.04, 0.08)
		seg.mesh = bm
		seg.position = pos
		seg.rotation.y = angle + PI * 0.5
		seg.material_override = _neon_mat(ring_color, 4.0)
		add_child(seg)

	# Cross lines on platform
	for angle in [0.0, PI * 0.5]:
		var line := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(12.0, 0.03, 0.04)
		line.mesh = lm
		line.position = Vector3(0, 0.01, 0)
		line.rotation.y = angle
		line.material_override = _neon_mat(ring_color, 2.0)
		add_child(line)

	# Spotlight on the vehicle from above
	var spot := OmniLight3D.new()
	spot.light_color      = Color(0.6, 0.8, 1.0)
	spot.light_energy     = 4.0
	spot.omni_range       = 18.0
	spot.omni_attenuation = 1.2
	spot.position         = Vector3(0, 8, 0)
	add_child(spot)

# ─── Vehicle display mesh ─────────────────────────────────────────────────────
func _build_vehicle() -> void:
	_vehicle_mesh = Node3D.new()
	_vehicle_mesh.position = Vector3(0, 1.0, 0)
	# Nose faces +Z, camera is at +Z — nose toward camera
	add_child(_vehicle_mesh)

	var body_mat   := _make_body_material()
	var accent_mat := _make_accent_material()
	var engine_mat := _make_engine_material()
	var canopy_mat := _make_canopy_material()
	var dark_mat   := _make_dark_panel_material()
	var carbon_mat := _make_carbon_material()

	# Central monocoque
	_box(Vector3(1.8, 0.24, 4.8), Vector3(0, 0.08, 0), body_mat)
	_box(Vector3(0.6, 0.08, 3.6), Vector3(0, 0.22, -0.2), dark_mat)
	_box(Vector3(1.5, 0.06, 4.4), Vector3(0, -0.06, 0), carbon_mat)

	# Nose
	_box(Vector3(1.3, 0.18, 1.2), Vector3(0, 0.05, 2.8), body_mat)
	_box(Vector3(0.9, 0.14, 0.8), Vector3(0, 0.02, 3.5), body_mat)
	_box(Vector3(0.45, 0.08, 0.6), Vector3(0, 0.0, 4.0), accent_mat)
	_box(Vector3(2.2, 0.03, 0.5), Vector3(0, -0.06, 3.2), carbon_mat)
	_box(Vector3(0.15, 0.10, 0.25), Vector3(0, 0.14, 3.9), accent_mat)

	# Front wing
	_box(Vector3(3.6, 0.03, 0.45), Vector3(0, -0.08, 3.5), accent_mat)
	_box(Vector3(3.2, 0.03, 0.25), Vector3(0, -0.04, 3.2), accent_mat)
	for side: int in [-1, 1]:
		_box(Vector3(0.03, 0.18, 0.55), Vector3(side * 1.8, -0.02, 3.4), accent_mat)

	# Sidepods
	for side: int in [-1, 1]:
		var sx := float(side) * 1.2
		_box(Vector3(0.55, 0.22, 2.8), Vector3(sx, 0.04, -0.2), body_mat)
		_box(Vector3(0.5, 0.18, 0.12), Vector3(sx, 0.06, 1.2), dark_mat)
		_box(Vector3(0.4, 0.04, 2.4), Vector3(sx, -0.08, -0.2), dark_mat)
		for v in range(3):
			_box(Vector3(0.45, 0.015, 0.4), Vector3(sx, 0.16, -0.6 + float(v) * 0.55), dark_mat)

	# Engine nacelles
	for side: int in [-1, 1]:
		var sx := float(side) * 1.65
		_box(Vector3(0.55, 0.26, 2.4), Vector3(sx, 0.0, -1.8), body_mat)
		_box(Vector3(0.4, 0.06, 1.8), Vector3(sx, 0.16, -1.8), dark_mat)
		_box(Vector3(0.5, 0.03, 2.2), Vector3(sx, -0.12, -1.8), carbon_mat)

		var nozzle := MeshInstance3D.new()
		var noz := CylinderMesh.new()
		noz.top_radius = 0.18; noz.bottom_radius = 0.28; noz.height = 0.5
		nozzle.mesh = noz
		nozzle.position = Vector3(sx, 0.0, -3.1)
		nozzle.rotation_degrees = Vector3(90, 0, 0)
		nozzle.material_override = engine_mat
		_vehicle_mesh.add_child(nozzle)

		var nozzle_inner := MeshInstance3D.new()
		var noz_i := CylinderMesh.new()
		noz_i.top_radius = 0.12; noz_i.bottom_radius = 0.20; noz_i.height = 0.3
		nozzle_inner.mesh = noz_i
		nozzle_inner.position = Vector3(sx, 0.0, -3.25)
		nozzle_inner.rotation_degrees = Vector3(90, 0, 0)
		nozzle_inner.material_override = accent_mat
		_vehicle_mesh.add_child(nozzle_inner)

		_box(Vector3(0.35, 0.14, 0.5), Vector3(sx, 0.18, -0.8), accent_mat)
		_box(Vector3(absf(sx) - 0.7, 0.05, 1.4), Vector3(side * 0.95, -0.04, -1.2), carbon_mat)
		_box(Vector3(0.03, 0.06, 2.2), Vector3(sx + side * 0.28, 0.02, -1.8), accent_mat)

	# Cockpit
	_box(Vector3(0.82, 0.06, 1.1), Vector3(0, 0.28, 0.7), carbon_mat)
	_box(Vector3(0.60, 0.18, 0.85), Vector3(0, 0.26, 0.75), canopy_mat)
	_box(Vector3(0.35, 0.16, 0.5), Vector3(0, 0.24, 0.1), body_mat)
	_box(Vector3(0.28, 0.22, 0.35), Vector3(0, 0.36, 0.3), carbon_mat)

	# Rear wing
	_box(Vector3(3.4, 0.04, 0.4), Vector3(0, 0.50, -2.8), accent_mat)
	_box(Vector3(3.2, 0.03, 0.22), Vector3(0, 0.46, -3.05), accent_mat)
	for side: int in [-1, 1]:
		_box(Vector3(0.03, 0.34, 0.6), Vector3(side * 1.7, 0.36, -2.9), accent_mat)
	for side: int in [-1, 1]:
		_box(Vector3(0.04, 0.04, 0.9), Vector3(side * 0.6, 0.48, -2.4), carbon_mat)
		_box(Vector3(0.04, 0.28, 0.04), Vector3(side * 0.6, 0.36, -2.0), carbon_mat)

	# Dorsal fin
	_box(Vector3(0.04, 0.40, 1.6), Vector3(0, 0.38, -1.5), body_mat)
	_box(Vector3(0.02, 0.12, 0.02), Vector3(0, 0.60, -0.8), accent_mat)

	# Diffuser
	_box(Vector3(2.0, 0.06, 0.7), Vector3(0, -0.10, -2.8), carbon_mat)
	for i in range(-2, 3):
		_box(Vector3(0.02, 0.10, 0.65), Vector3(float(i) * 0.4, -0.06, -2.8), dark_mat)

	# Floor + bargeboards
	_box(Vector3(1.6, 0.02, 5.0), Vector3(0, -0.10, 0), carbon_mat)
	for side: int in [-1, 1]:
		_box(Vector3(0.02, 0.14, 0.8), Vector3(side * 0.85, 0.0, 1.8), accent_mat)
		_box(Vector3(0.02, 0.10, 0.6), Vector3(side * 0.95, 0.0, 1.5), body_mat)

	# Neon underbody strips
	for side: int in [-1, 1]:
		_box(Vector3(0.04, 0.02, 4.5), Vector3(side * 0.7, -0.12, 0), accent_mat)

	# Brake light
	_box(Vector3(1.8, 0.06, 0.04), Vector3(0, 0.12, -3.1), _neon_mat(Color(0.2, 0.5, 1.0), 3.0))

	# Underbody glow
	var glow := OmniLight3D.new()
	glow.light_color      = _accent_color
	glow.light_energy     = 5.0
	glow.omni_range       = 6.0
	glow.omni_attenuation = 1.4
	glow.position         = Vector3(0, -0.35, 0)
	_vehicle_mesh.add_child(glow)

	# Engine glows
	for side: int in [-1, 1]:
		var eg := OmniLight3D.new()
		eg.light_color      = _accent_color
		eg.light_energy     = 6.0
		eg.omni_range       = 4.0
		eg.omni_attenuation = 1.8
		eg.position         = Vector3(side * 1.65, 0.0, -3.2)
		_vehicle_mesh.add_child(eg)

	# Headlights
	for side: int in [-1, 1]:
		var hl := OmniLight3D.new()
		hl.light_color      = Color(0.85, 0.92, 1.0)
		hl.light_energy     = 3.0
		hl.omni_range       = 15.0
		hl.omni_attenuation = 1.2
		hl.position         = Vector3(side * 0.35, 0.0, 3.8)
		_vehicle_mesh.add_child(hl)

# ─── City backdrop ────────────────────────────────────────────────────────────
func _build_city_backdrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	var neon_colors: Array[Color] = [
		Color(1.0, 0.15, 0.55),  Color(0.2, 0.85, 1.0),
		Color(0.7, 0.15, 1.0),   Color(1.0, 0.5, 0.05),
		Color(0.1, 0.5, 1.0),    Color(0.1, 1.0, 0.45),
		Color(1.0, 0.9, 0.1),
	]

	# Ring of buildings around the showroom
	for i in range(40):
		var angle := float(i) / 40.0 * TAU
		var dist := rng.randf_range(40.0, 120.0)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var bh := rng.randf_range(15.0, 80.0)
		var bw := rng.randf_range(6.0, 20.0)
		var bd := rng.randf_range(6.0, 16.0)
		_place_building(pos, bw, bh, bd, neon_colors, rng)

	# Distant skyline — taller, further out
	for i in range(30):
		var angle := float(i) / 30.0 * TAU
		var dist := rng.randf_range(140.0, 220.0)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var bh := rng.randf_range(40.0, 160.0)
		var bw := rng.randf_range(12.0, 35.0)
		_place_building(pos, bw, bh, bw * 0.7, neon_colors, rng)

	# Street lamps around the platform
	for i in range(8):
		var angle := float(i) / 8.0 * TAU
		var pos := Vector3(cos(angle) * 18.0, 0, sin(angle) * 18.0)
		_place_street_lamp(pos, neon_colors[rng.randi() % neon_colors.size()])

func _place_building(pos: Vector3, width: float, height: float, depth: float,
		colors: Array[Color], rng: RandomNumberGenerator) -> void:
	var building := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height, depth)
	building.mesh = bm
	building.position = pos + Vector3(0, height * 0.5, 0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color     = Color(0.04, 0.05, 0.08)
	body_mat.emission_enabled = true
	body_mat.emission         = Color(0.02, 0.03, 0.05)
	body_mat.emission_energy_multiplier = 0.2
	building.material_override = body_mat
	add_child(building)

	var accent_col: Color = colors[rng.randi() % colors.size()]
	var strip_count := rng.randi_range(1, 3)
	for s in strip_count:
		var strip_h := rng.randf_range(height * 0.3, height * 0.9)
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(width * 0.85, 1.5, 0.15)
		strip.mesh = sm
		strip.position = pos + Vector3(0, strip_h, depth * 0.51)
		strip.material_override = _neon_mat(accent_col, 3.0)
		add_child(strip)

	if height > 30.0:
		var roof_light := OmniLight3D.new()
		roof_light.light_color    = accent_col
		roof_light.light_energy   = 6.0
		roof_light.omni_range     = 40.0
		roof_light.shadow_enabled = false
		roof_light.position       = pos + Vector3(0, height + 3.0, 0)
		add_child(roof_light)

	# Windows
	var window_rows := mini(int(height / 8.0), 6)
	var window_cols := mini(int(width / 6.0), 4)
	var window_col := Color(0.8, 0.85, 0.6)
	for row in window_rows:
		for col_idx in window_cols:
			if rng.randf() < 0.35:
				continue
			var wx := pos.x - width * 0.4 + float(col_idx) * (width * 0.8 / maxf(float(window_cols), 1.0))
			var wy := 5.0 + float(row) * 8.0
			if wy > height - 3.0:
				continue
			var win := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(2.0, 3.0, 0.15)
			win.mesh = wm
			win.position = Vector3(wx, wy, pos.z + depth * 0.51)
			win.material_override = _neon_mat(window_col, 1.2)
			add_child(win)

func _place_street_lamp(pos: Vector3, color: Color) -> void:
	var pole := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.2, 8.0, 0.2)
	pole.mesh = pm
	pole.position = pos + Vector3(0, 4.0, 0)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.15, 0.15, 0.2)
	pole_mat.metallic = 0.9
	pole.material_override = pole_mat
	add_child(pole)

	var fixture := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(2.0, 0.5, 2.0)
	fixture.mesh = fm
	fixture.position = pos + Vector3(0, 8.5, 0)
	fixture.material_override = _neon_mat(color, 6.0)
	add_child(fixture)

	var lamp_light := OmniLight3D.new()
	lamp_light.light_color    = color
	lamp_light.light_energy   = 10.0
	lamp_light.omni_range     = 25.0
	lamp_light.shadow_enabled = false
	lamp_light.position       = pos + Vector3(0, 8.0, 0)
	add_child(lamp_light)

# ─── Camera ───────────────────────────────────────────────────────────────────
func _build_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.position = Vector3(-3.5, 1.5, 0)  # Offset left so car appears right of centre
	add_child(_cam_pivot)

	_camera = Camera3D.new()
	_camera.fov  = 55.0
	_camera.near = 0.2
	_camera.far  = 500.0
	_camera.position = Vector3(0, CAM_HEIGHT, CAM_DISTANCE)
	_cam_pivot.add_child(_camera)
	_camera.look_at(Vector3(0, 1.0, 0))

# ─── Input & Update ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var viewport_size := get_viewport().get_visible_rect().size
		if viewport_size.x > 0 and viewport_size.y > 0:
			var mouse_pos := (event as InputEventMouseMotion).position
			# Map mouse position to -1..1 range
			var nx := (mouse_pos.x / viewport_size.x) * 2.0 - 1.0
			var ny := (mouse_pos.y / viewport_size.y) * 2.0 - 1.0
			_target_yaw   = -nx * YAW_RANGE
			_target_pitch = -0.18 - ny * PITCH_RANGE

func _process(delta: float) -> void:
	_bob_time += delta

	# Vehicle gentle hover bob
	if _vehicle_mesh:
		_vehicle_mesh.position.y = 1.0 + sin(_bob_time * 1.5) * 0.08
		_vehicle_mesh.rotation.z = sin(_bob_time * 0.8) * 0.015

	# Smooth camera orbit
	_current_yaw   = lerp(_current_yaw, _target_yaw, delta * CAM_LERP_SPEED)
	_current_pitch = lerp(_current_pitch, _target_pitch, delta * CAM_LERP_SPEED)

	if _cam_pivot:
		_cam_pivot.rotation = Vector3.ZERO
		_cam_pivot.rotate_y(_current_yaw)
		_cam_pivot.rotate_x(_current_pitch)

# ─── Helpers ──────────────────────────────────────────────────────────────────
func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	_vehicle_mesh.add_child(mi)

func _neon_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color               = color * 0.5
	m.emission_enabled           = true
	m.emission                   = color
	m.emission_energy_multiplier = energy
	return m

func _make_body_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color        = _vehicle_color
	m.metallic            = 0.95
	m.roughness           = 0.08
	m.clearcoat           = 1.0
	m.clearcoat_roughness = 0.03
	m.emission_enabled    = true
	m.emission            = _vehicle_color * 0.18
	return m

func _make_accent_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color               = _accent_color
	m.metallic                   = 0.82
	m.roughness                  = 0.05
	m.emission_enabled           = true
	m.emission                   = _accent_color
	m.emission_energy_multiplier = 2.5
	return m

func _make_canopy_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color               = Color(0.07, 0.52, 0.92, 0.48)
	m.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic                   = 0.1
	m.roughness                  = 0.02
	m.emission_enabled           = true
	m.emission                   = Color(0.1, 0.42, 0.82)
	m.emission_energy_multiplier = 1.1
	return m

func _make_engine_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color               = Color(0.08, 0.10, 0.16)
	m.metallic                   = 0.98
	m.roughness                  = 0.20
	m.emission_enabled           = true
	m.emission                   = _accent_color
	m.emission_energy_multiplier = 3.5
	return m

func _make_dark_panel_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.07, 0.10)
	m.metallic     = 0.9
	m.roughness    = 0.3
	return m

func _make_carbon_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.04)
	m.metallic     = 0.7
	m.roughness    = 0.45
	return m
