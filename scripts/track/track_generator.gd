## TrackGenerator — Flat circuit with tight turns, retro neon city scenery.
extends Node
class_name TrackGenerator

var waypoints: Array[Vector3] = []
var _banked_rights: Array[Vector3] = []

# Hi-res road mesh points (test track only — ~5m spacing for smooth curves)
var _hires_pts:    Array[Vector3] = []
var _hires_banks:  Array[float]   = []
var _hires_rights: Array[Vector3] = []

# ─── Material cache for performance ──────────────────────────────────────────
var _mat_cache: Dictionary = {}
var _building_body_mat: StandardMaterial3D
var _pole_mat: StandardMaterial3D
var _dark_curb_mat: StandardMaterial3D
var _chevron_mat: ShaderMaterial
var _chevron_mat_blue: ShaderMaterial
var _building_count: int = 0
var _pylon_accum_dist: float = 0.0  # Distance since last edge pylon (keeps ~500m spacing)
var _lit_section_dist: float = 0.0   # Distance since last lit barrier section (~100m spacing)

# ─── Chunk-based visibility system ───────────────────────────────────────────
const CHUNK_SIZE := 10            # Waypoints per chunk
const CHUNKS_AHEAD := 80          # ~8000m forward visibility
const CHUNKS_BEHIND := 5          # ~500m behind
var _chunks: Array[Node3D] = []   # Chunk containers indexed by chunk_id
var _skyline_node: Node3D         # Always-visible distant backdrop
var _active_chunks: Dictionary = {} # Currently visible chunk indices

# ─── MultiMesh batching system ───────────────────────────────────────────────
var _batch_data: Dictionary = {}  # key → {chunk, mat, vis_range, transforms, customs}

var TRACK_WIDTH: float   = 320.0
const LINE_SPACING  = 50.0     # Neon dashes every 50m — massive track
var EDGE_OFFSET: float   = 150.0    # Yellow edge lines offset from centre
const CURB_BLOCK_LEN = 5.5     # Length of each barrier block along track
const CURB_SIZE      = Vector3(4.0, 10.0, 5.5)  # Tall barrier blocks

# ─── Railing collision walls ────────────────────────────────────────────────
const RAILING_HEIGHT    := 10.0   # Metres tall — enough to block the vehicle
const RAILING_THICKNESS := 3.0    # Metres thick — wide enough to prevent high-speed tunnelling
const RAILING_LAYER     := 4      # Raycast-only layer — vehicle detects via lateral raycasts, not physics

# ─── Track layout — massive flowing clockwise circuit ─────────────────────────
# ~100km perimeter (Catmull-Rom measured). ONE straight. All turns sweeping
# and gentle (no sharp 90°). Traces a large irregular oval with S-curves on
# the long sides. Spans ~19km east-west, ~35km north-south.
# Zero self-intersections. Min 2000m between any non-adjacent sections.
# Lap time ~15 min at 110 m/s average.
const CONTROL_POINTS = [
	# ══ THE STRAIGHT — the ONLY straight on the entire circuit (~4km) ══
	Vector3(     0,  0,      0),    #  0  S/F line
	Vector3(  2000,  0,      0),    #  1  mid straight
	Vector3(  4000,  0,      0),    #  2  straight end

	# ══ Sector 1: Sweeping right entry — heading SE then S (~13km) ══
	Vector3(  5800,  0,    400),    #  3  entry sweep
	Vector3(  7500,  0,   1400),    #  4  sweep SE
	Vector3(  9000,  0,   3000),    #  5  sweep SE
	Vector3( 10300,  0,   5000),    #  6  turning southward
	Vector3( 11300,  0,   7200),    #  7  turning S
	Vector3( 12000,  0,   9500),    #  8  heading S

	# ══ Sector 2: Gentle S-curves flowing south — east side (~22km) ══
	Vector3( 13200,  0,  11500),    #  9  east S-curve 1 (right)
	Vector3( 11800,  0,  13500),    # 10  east S-curve 2 (left)
	Vector3( 13200,  0,  15500),    # 11  east S-curve 3 (right)
	Vector3( 11800,  0,  17500),    # 12  east S-curve 4 (left)
	Vector3( 13200,  0,  19500),    # 13  east S-curve 5 (right)
	Vector3( 11800,  0,  21500),    # 14  east S-curve 6 (left)
	Vector3( 13200,  0,  23500),    # 15  east S-curve 7 (right)
	Vector3( 11800,  0,  25500),    # 16  east S-curve 8 (left)
	Vector3( 13200,  0,  27500),    # 17  east S-curve 9 (right)

	# ══ Sector 3: Big sweeping right — south end (~16km arc) ══
	Vector3( 12200,  0,  29500),    # 18  south approach
	Vector3( 11500,  0,  31200),    # 19  south arc 1
	Vector3( 10000,  0,  32600),    # 20  south arc 2
	Vector3(  8000,  0,  33500),    # 21  south arc 3
	Vector3(  6000,  0,  34000),    # 22  south apex
	Vector3(  4000,  0,  33500),    # 23  south arc 4
	Vector3(  2500,  0,  32500),    # 24  south arc 5
	Vector3(  1200,  0,  31000),    # 25  south arc 6

	# ══ Sector 4: Transition heading NW to west side (~7km) ══
	Vector3(     0,  0,  29500),    # 26  transition 1
	Vector3( -1500,  0,  28500),    # 27  transition 2
	Vector3( -3200,  0,  27800),    # 28  transition 3
	Vector3( -4800,  0,  27000),    # 29  transition 4

	# ══ Sector 5: Gentle S-curves flowing north — west side (~24km) ══
	Vector3( -6200,  0,  25000),    # 30  west S-curve 1 (left)
	Vector3( -4800,  0,  23000),    # 31  west S-curve 2 (right)
	Vector3( -6200,  0,  21000),    # 32  west S-curve 3 (left)
	Vector3( -4800,  0,  19000),    # 33  west S-curve 4 (right)
	Vector3( -6200,  0,  17000),    # 34  west S-curve 5 (left)
	Vector3( -4800,  0,  15000),    # 35  west S-curve 6 (right)
	Vector3( -6200,  0,  13000),    # 36  west S-curve 7 (left)
	Vector3( -4800,  0,  11000),    # 37  west S-curve 8 (right)
	Vector3( -6200,  0,   9000),    # 38  west S-curve 9 (left)
	Vector3( -4800,  0,   7000),    # 39  west S-curve 10 (right)

	# ══ Sector 6: Sweeping right — north end (~10km arc) ══
	Vector3( -5800,  0,   5000),    # 40  north approach
	Vector3( -5500,  0,   3000),    # 41  north arc 1
	Vector3( -4800,  0,   1200),    # 42  north arc 2
	Vector3( -3700,  0,   -100),    # 43  north arc 3
	Vector3( -2200,  0,   -600),    # 44  north closing — wraps to #0
]

# ─── Test Track — High-Speed Banked Oval with Corkscrew ─────────────────────
# Clockwise circuit. S/F flat drag straight → East banked hairpin (400m climb)
# → flat approach → CORKSCREW (1 full right-hand helix, 300m climb, r=1500m)
# → descent ramp back to ground → West banked hairpin → flat return.
# Corkscrew centre (4500, 0, 19500). All sections flat or smoothly banked —
# no sudden hills or bumps that could launch the car.
const TEST_CONTROL_POINTS = [
	# ══ S/F Straight — flat, heading East ══
	Vector3(      0,    0,      0),   #  0  Start / Finish line
	Vector3(   5000,    0,      0),   #  1  mid straight
	Vector3(  10000,    0,      0),   #  2  three-quarter
	Vector3(  13500,    0,      0),   #  3  braking zone

	# ══ East Banked Turn — sweeping right (south), climbing to 400m, 30° bank ══
	Vector3(  16500,  120,   2800),   #  4  entry, climbing
	Vector3(  19200,  280,   6500),   #  5  mid-entry
	Vector3(  20800,  400,  11000),   #  6  apex
	Vector3(  19500,  220,  15500),   #  7  post-apex, descending
	Vector3(  15500,   30,  19000),   #  8  exit, nearly flat

	# ══ Approach to Corkscrew — flat, heading West ══
	Vector3(  10000,    0,  21000),   #  9  flat approach
	Vector3(   6500,    0,  21000),   # 10  corkscrew entry zone

	# ══ Corkscrew — 1 full clockwise helix, r=1500m, climbing 300m ══
	# Centre (4500, 0, 19500). Entry heading West; exits heading West 300m higher.
	# Control points at every 45° around the circle.
	Vector3(   4500,    0,  21000),   # 11  entry  (θ=090°)
	Vector3(   3440,   38,  20560),   # 12  (θ=135°)
	Vector3(   3000,   75,  19500),   # 13  (θ=180°) heading north
	Vector3(   3440,  113,  18440),   # 14  (θ=225°)
	Vector3(   4500,  150,  18000),   # 15  (θ=270°) heading east
	Vector3(   5560,  188,  18440),   # 16  (θ=315°)
	Vector3(   6000,  225,  19500),   # 17  (θ=360°) heading south
	Vector3(   5560,  263,  20560),   # 18  (θ=405°)
	Vector3(   4500,  300,  21000),   # 19  exit   (θ=450°) heading West, 300m up

	# ══ Descent — smooth ramp back to ground ══
	Vector3(      0,  150,  22000),   # 20  mid-descent
	Vector3(  -4000,    0,  21500),   # 21  ground level, join west approach

	# ══ West Banked Turn — sweeping right (north), mirror of East, 30° bank ══
	Vector3(  -7000,   60,  18800),   # 22  entry
	Vector3( -10500,  260,  15500),   # 23  mid-entry
	Vector3( -13000,  400,  11000),   # 24  apex
	Vector3( -11500,  280,   6500),   # 25  post-apex
	Vector3(  -9500,  120,   2800),   # 26  exit

	# ══ Return to S/F ══
	Vector3(  -7000,    0,      0),   # 27  closing join
	Vector3(  -3000,    0,      0),   # 28  approaching S/F
]

# Bank angles per control point (positive = right-turn banking, outer edge up)
const TEST_BANK_ANGLES = [
	0.0,  0.0,  0.0,  3.0,                               # S/F straight
	12.0, 24.0, 30.0, 24.0, 10.0,                        # East turn
	0.0,  0.0,                                            # Flat approach
	0.0, 15.0, 20.0, 20.0, 20.0, 20.0, 20.0, 15.0, 0.0, # Corkscrew (right-turn bank)
	0.0,  0.0,                                            # Descent
	10.0, 24.0, 30.0, 24.0, 12.0,                        # West turn
	3.0,  0.0,                                            # Return
]

# Banking data per interpolated waypoint (filled during _compute_waypoints)
var _bank_angles: Array[float] = []

func _ready() -> void:
	# Set track-specific dimensions before building anything
	if GameManager.selected_track != 0:
		TRACK_WIDTH = 500.0   # Very wide — high-speed test oval, no walls
		EDGE_OFFSET = 215.0   # Edge stripe position near the road margin

	_init_shared_materials()
	_build_plane()
	_compute_waypoints()  # compute waypoints + _banked_rights + _bank_angles FIRST
	_init_chunks()        # create chunk containers BEFORE spawning content
	_build_track()        # edge lines, curbs, signs (uses chunks)
	_compute_hires_road() # hi-res points for smooth road + railing curves
	_build_railings()     # solid collision walls along track edges
	_build_road_surface() # uses waypoints to lay textured road ribbon
	_build_checkpoints()  # lap gates around the circuit
	if GameManager.selected_track == 0:
		_build_city_scenery()
	_flush_batches()      # convert all collected batch data into MultiMeshInstance3D
	# Start with all chunks visible — race_manager will call update_chunks()
	for c in _chunks:
		c.visible = true

func _init_chunks() -> void:
	var num_chunks := ceili(float(waypoints.size()) / float(CHUNK_SIZE))
	for i in num_chunks:
		var chunk := Node3D.new()
		chunk.name = "Chunk_%d" % i
		add_child(chunk)
		_chunks.append(chunk)
	# Skyline container — always visible, not chunked
	_skyline_node = Node3D.new()
	_skyline_node.name = "Skyline"
	add_child(_skyline_node)

## Get the chunk Node3D for a given waypoint index
func _chunk_for(waypoint_idx: int) -> Node3D:
	var chunk_id := clampi(waypoint_idx / CHUNK_SIZE, 0, _chunks.size() - 1)
	return _chunks[chunk_id]

## Call every frame with the player's position to show/hide chunks
func update_chunks(player_pos: Vector3) -> void:
	if _chunks.is_empty() or waypoints.is_empty():
		return
	# Find nearest waypoint (coarse — check every 5th for speed)
	var n := waypoints.size()
	var best_wp := 0
	var best_dist_sq := INF
	for i in range(0, n, 5):
		var dx := player_pos.x - waypoints[i].x
		var dz := player_pos.z - waypoints[i].z
		var d := dx * dx + dz * dz
		if d < best_dist_sq:
			best_dist_sq = d
			best_wp = i
	# Fine pass around best
	var search_start := maxi(best_wp - 5, 0)
	var search_end := mini(best_wp + 5, n - 1)
	for i in range(search_start, search_end + 1):
		var dx := player_pos.x - waypoints[i].x
		var dz := player_pos.z - waypoints[i].z
		var d := dx * dx + dz * dz
		if d < best_dist_sq:
			best_dist_sq = d
			best_wp = i

	var current_chunk := best_wp / CHUNK_SIZE
	var num_chunks := _chunks.size()
	var new_active: Dictionary = {}

	# Mark chunks in range as active (wrapping around for circuit)
	for offset in range(-CHUNKS_BEHIND, CHUNKS_AHEAD + 1):
		var ci := (current_chunk + offset + num_chunks) % num_chunks
		new_active[ci] = true

	# Show newly active, hide newly inactive
	for ci in new_active:
		if not _active_chunks.has(ci):
			_chunks[ci].visible = true
	for ci in _active_chunks:
		if not new_active.has(ci):
			_chunks[ci].visible = false
	_active_chunks = new_active

# ─── Ground plane — unchanged ────────────────────────────────────────────────
func _build_plane() -> void:
	var body := StaticBody3D.new()
	body.name            = "Ground"
	body.collision_layer = 1
	body.collision_mask  = 0
	add_child(body)

	var plane_size := 100000.0

	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(plane_size, plane_size)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08)
	mi.material_override = mat
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(plane_size, 1.0, plane_size)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)

# ─── Railing walls — solid collision barriers along both track edges ──────────
# Test track: dark walls with 5m lit sections every ~100m
# Main track: fully lit walls (no pattern)
func _build_railings() -> void:
	var pts    := _hires_pts
	var banks  := _hires_banks
	var rights := _hires_rights
	var n := pts.size()
	if n < 2:
		return

	var edge_dist := EDGE_OFFSET + 3.0
	var rail_mat  := _neon_mat(Color(1.0, 0.5, 0.15), 30.0)
	rail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark_rail_mat := _neon_mat(Color(0.1, 0.1, 0.1), 2.0)
	dark_rail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var post_mat  := _neon_mat(Color(0.9, 0.6, 0.2), 50.0)
	var half_t    := RAILING_THICKNESS * 0.5

	var wp_count     := waypoints.size()
	var hires_per_wp := maxi(1, n / maxi(1, wp_count))

	# Test track uses dark/lit pattern, main track is all lit
	var use_pattern := GameManager.selected_track != 0
	_lit_section_dist = 0.0  # Reset distance tracker

	for side in [-1, 1]:
		var sf := float(side)

		# ── Pre-compute edge + inner/outer positions for every point ─────
		var edge_pt  := PackedVector3Array()
		var inner_pt := PackedVector3Array()
		var outer_pt := PackedVector3Array()
		var base_y   := PackedFloat32Array()
		edge_pt.resize(n);  inner_pt.resize(n)
		outer_pt.resize(n); base_y.resize(n)

		for i in n:
			var ri: Vector3 = rights[i] if i < rights.size() else Vector3.RIGHT
			var bank_deg: float = banks[i] if i < banks.size() else 0.0
			var bh := tan(deg_to_rad(bank_deg)) * edge_dist
			base_y[i]  = 0.02 - bh * sf
			edge_pt[i] = pts[i] + ri * sf * edge_dist
			var to_ctr := pts[i] - edge_pt[i]
			to_ctr.y = 0.0
			var d := to_ctr.length()
			if d > 0.01:
				to_ctr /= d
			else:
				to_ctr = Vector3.RIGHT
			inner_pt[i] = edge_pt[i] + to_ctr * half_t
			outer_pt[i] = edge_pt[i] - to_ctr * half_t

		# ── Build wall mesh per chunk — segments alternate dark/lit on test track ─
		var chunk_st:    Dictionary = {}   # cid → SurfaceTool
		var chunk_st_dark: Dictionary = {}  # cid → SurfaceTool (dark sections)
		var chunk_faces: Dictionary = {}
		var chunk_faces_dark: Dictionary = {}
		var chunk_sb:    Dictionary = {}
		var lit_positions: Dictionary = {}  # cid → Array of lit section positions for lights

		for i in n:
			var ni := (i + 1) % n
			if edge_pt[i].distance_squared_to(edge_pt[ni]) < 0.01:
				continue

			var wp_idx := clampi(i / hires_per_wp, 0, wp_count - 1)
			var cid    := clampi(wp_idx / CHUNK_SIZE, 0, _chunks.size() - 1)
			var seg_dist := pts[ni].distance_to(pts[i])

			# Determine if this segment is lit or dark (test track only)
			var is_lit := not use_pattern
			var mid_pos := Vector3.ZERO
			if use_pattern:
				_lit_section_dist += seg_dist
				if _lit_section_dist >= 100.0:
					is_lit = true
					_lit_section_dist -= 100.0
					mid_pos = (edge_pt[i] + edge_pt[ni]) * 0.5 + Vector3(0, RAILING_HEIGHT * 0.5, 0)

			# Use appropriate SurfaceTool based on lit/dark state
			var st: SurfaceTool
			var faces: Array
			if is_lit:
				if not chunk_st.has(cid):
					var st_new := SurfaceTool.new()
					st_new.begin(Mesh.PRIMITIVE_TRIANGLES)
					chunk_st[cid] = st_new
					chunk_faces[cid] = []
					lit_positions[cid] = []
					var sb := StaticBody3D.new()
					sb.collision_layer = RAILING_LAYER
					sb.collision_mask  = 2
					chunk_sb[cid] = sb
				st = chunk_st[cid]
				faces = chunk_faces[cid]
				if mid_pos != Vector3.ZERO:
					lit_positions[cid].append(mid_pos)
			else:
				if not chunk_st_dark.has(cid):
					var st_new := SurfaceTool.new()
					st_new.begin(Mesh.PRIMITIVE_TRIANGLES)
					chunk_st_dark[cid] = st_new
					chunk_faces_dark[cid] = []
					var sb := StaticBody3D.new()
					sb.collision_layer = RAILING_LAYER
					sb.collision_mask  = 2
					chunk_sb[cid] = sb
				st = chunk_st_dark[cid]
				faces = chunk_faces_dark[cid]

			var by_i: float = base_y[i]
			var by_n: float = base_y[ni]

			var ib  := inner_pt[i]  + Vector3(0, by_i, 0)
			var it  := inner_pt[i]  + Vector3(0, by_i + RAILING_HEIGHT, 0)
			var ob  := outer_pt[i]  + Vector3(0, by_i, 0)
			var ot  := outer_pt[i]  + Vector3(0, by_i + RAILING_HEIGHT, 0)
			var ib2 := inner_pt[ni] + Vector3(0, by_n, 0)
			var it2 := inner_pt[ni] + Vector3(0, by_n + RAILING_HEIGHT, 0)
			var ob2 := outer_pt[ni] + Vector3(0, by_n, 0)
			var ot2 := outer_pt[ni] + Vector3(0, by_n + RAILING_HEIGHT, 0)

			st.add_vertex(ib);  st.add_vertex(ib2); st.add_vertex(it2)
			st.add_vertex(ib);  st.add_vertex(it2); st.add_vertex(it)
			faces.append(ib);   faces.append(ib2);  faces.append(it2)
			faces.append(ib);   faces.append(it2);  faces.append(it)
			st.add_vertex(ob);  st.add_vertex(ot);  st.add_vertex(ot2)
			st.add_vertex(ob);  st.add_vertex(ot2); st.add_vertex(ob2)
			faces.append(ob);   faces.append(ot);   faces.append(ot2)
			faces.append(ob);   faces.append(ot2);  faces.append(ob2)
			st.add_vertex(it);  st.add_vertex(it2); st.add_vertex(ot2)
			st.add_vertex(it);  st.add_vertex(ot2); st.add_vertex(ot)
			faces.append(it);   faces.append(it2);  faces.append(ot2)
			faces.append(it);   faces.append(ot2);  faces.append(ot)

		# ── Finalize: lit mesh + dark mesh + collision per chunk ──────────
		for cid in chunk_st:
			var chunk := _chunks[cid]
			# Lit sections
			var st_lit: SurfaceTool = chunk_st[cid]
			st_lit.generate_normals()
			var mi_lit := MeshInstance3D.new()
			mi_lit.mesh = st_lit.commit()
			mi_lit.material_override = rail_mat
			chunk.add_child(mi_lit)

			# Dark sections
			if chunk_st_dark.has(cid):
				var st_dark: SurfaceTool = chunk_st_dark[cid]
				st_dark.generate_normals()
				var mi_dark := MeshInstance3D.new()
				mi_dark.mesh = st_dark.commit()
				mi_dark.material_override = dark_rail_mat
				chunk.add_child(mi_dark)

			# Combined collision
			var all_faces: Array = chunk_faces[cid]
			if chunk_faces_dark.has(cid):
				all_faces.append_array(chunk_faces_dark[cid])
			var concave := ConcavePolygonShape3D.new()
			concave.set_faces(PackedVector3Array(all_faces))
			concave.backface_collision = true
			var col := CollisionShape3D.new()
			col.shape = concave
			var sb: StaticBody3D = chunk_sb[cid]
			sb.add_child(col)
			chunk.add_child(sb)

			# Add lights at lit sections
			if lit_positions.has(cid):
				for light_pos in lit_positions[cid]:
					var barrier_light := OmniLight3D.new()
					barrier_light.light_color = Color(1.0, 0.5, 0.15)
					barrier_light.light_energy = 375.0
					barrier_light.omni_range = 200.0
					barrier_light.omni_attenuation = 1.0
					barrier_light.shadow_enabled = false
					barrier_light.distance_fade_enabled = true
					barrier_light.distance_fade_begin = 4800.0
					barrier_light.distance_fade_length = 400.0
					barrier_light.position = light_pos
					chunk.add_child(barrier_light)

	# ── Post accents — decorative boxes every ~40m ───────────────────────────
	for i in n:
		if i % 8 != 0:
			continue
		var a: Vector3 = pts[i]
		var ri: Vector3 = rights[i] if i < rights.size() else Vector3.RIGHT
		var bank_deg: float = banks[i] if i < banks.size() else 0.0
		var wp_idx := clampi(i / hires_per_wp, 0, wp_count - 1)
		var chunk  := _chunk_for(wp_idx)
		for s in [-1, 1]:
			var sf2 := float(s)
			var bh2 := tan(deg_to_rad(bank_deg)) * edge_dist
			var ph: float = -bh2 * sf2
			var post_pos: Vector3 = a + ri * sf2 * edge_dist + Vector3(0, RAILING_HEIGHT + 0.02 + ph, 0)
			_batch_box(post_pos, Vector3(0.6, 1.2, 0.6), Vector3.ZERO, post_mat, chunk)

# ─── Hi-res road point set — shared by road mesh and railings ─────────────────
# Test track: ~5m vertex spacing for smooth curves. Main track: uses waypoints.
func _compute_hires_road() -> void:
	if GameManager.selected_track != 0:
		var ctrl = TEST_CONTROL_POINTS
		var avg_seg := 0.0
		for i in ctrl.size():
			avg_seg += (ctrl[i] as Vector3).distance_to(ctrl[(i + 1) % ctrl.size()] as Vector3)
		avg_seg /= ctrl.size()
		var hi_sub := maxi(10, ceili(avg_seg / 5.0))
		print("TrackGenerator: road mesh hi_sub=%d  (~%.0f m spacing)" % [hi_sub, avg_seg / hi_sub])

		_hires_pts   = _catmull_rom_chain(ctrl, hi_sub)
		_hires_banks = _catmull_rom_chain_1d(TEST_BANK_ANGLES, hi_sub)

		var mn := _hires_pts.size()
		_hires_rights.resize(mn)
		for i in mn:
			var prev: Vector3 = _hires_pts[(i - 1 + mn) % mn]
			var cur:  Vector3 = _hires_pts[i]
			var nxt:  Vector3 = _hires_pts[(i + 1) % mn]
			var d_in  := (cur - prev).normalized()
			var d_out := (nxt - cur).normalized()
			var avg   := (d_in + d_out).normalized()
			if avg.length_squared() < 0.001:
				avg = d_out
			_hires_rights[i] = avg.cross(Vector3.UP).normalized()
	else:
		_hires_pts   = waypoints
		_hires_banks = _bank_angles
		_hires_rights = _banked_rights

# ─── Road surface ribbon mesh — follows curves with proper UVs ───────────────
func _build_road_surface() -> void:
	var mesh_pts   := _hires_pts
	var mesh_banks := _hires_banks
	var mesh_rights := _hires_rights

	var n := mesh_pts.size()
	if n < 2:
		return

	var half_w := TRACK_WIDTH * 0.5

	# Build arrays for ArrayMesh
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()

	# How many road-widths of length per texture tile along the road
	var tile_length := TRACK_WIDTH  # 1:1 aspect ratio tiling

	for i in n:
		var cur: Vector3 = mesh_pts[i]
		var right: Vector3 = mesh_rights[i]

		# Apply physical road banking — tilt the cross-section in banked turns
		var bank_deg: float = mesh_banks[i] if i < mesh_banks.size() else 0.0
		var bank_h := tan(deg_to_rad(bank_deg)) * half_w
		# Positive bank: left (outside) higher, right (inside) lower — correct for right turns
		var left_pt  := cur - right * half_w + Vector3(0, 0.02 + bank_h, 0)
		var right_pt := cur + right * half_w + Vector3(0, 0.02 - bank_h, 0)

		verts.append(left_pt)
		verts.append(right_pt)
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)

	# Add the closing verts (duplicate of first pair but with final V)
	var right0: Vector3 = mesh_rights[0]
	var cur0: Vector3 = mesh_pts[0]
	var bank0: float = mesh_banks[0] if not mesh_banks.is_empty() else 0.0
	var bank_h0 := tan(deg_to_rad(bank0)) * half_w
	verts.append(cur0 - right0 * half_w + Vector3(0, 0.02 + bank_h0, 0))
	verts.append(cur0 + right0 * half_w + Vector3(0, 0.02 - bank_h0, 0))
	norms.append(Vector3.UP)
	norms.append(Vector3.UP)

	# Build UV array — recalculate V for each vertex
	var uv_array := PackedVector2Array()
	var running_v := 0.0
	for i in n:
		if i > 0:
			running_v += mesh_pts[i].distance_to(mesh_pts[i - 1]) / tile_length
		uv_array.append(Vector2(0.0, running_v))
		uv_array.append(Vector2(1.0, running_v))
	# Closing verts
	running_v += mesh_pts[0].distance_to(mesh_pts[n - 1]) / tile_length
	uv_array.append(Vector2(0.0, running_v))
	uv_array.append(Vector2(1.0, running_v))

	# Build triangle indices — quad strip
	for i in n:
		var base := i * 2
		var next_base := (i + 1) * 2
		# Triangle 1
		indices.append(base)
		indices.append(next_base)
		indices.append(base + 1)
		# Triangle 2
		indices.append(base + 1)
		indices.append(next_base)
		indices.append(next_base + 1)

	# Create ArrayMesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Material — Road1_A texture via atlas-cropping shader
	var road_shader := load("res://shaders/road_surface.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = road_shader
	mat.set_shader_parameter("road_tex", load("res://Assets/roads/PLUS/Road1_B_dotted_white.png"))
	mat.set_shader_parameter("darkness", 0.3)

	var mi := MeshInstance3D.new()
	mi.name = "RoadSurface"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	# For tracks with elevation/banking, create a THICK collision slab so the
	# vehicle can't tunnel through the paper-thin visual mesh at high speed.
	# Extrudes 8 m below the road surface along the banked normal.
	if GameManager.selected_track != 0:
		var col_body := StaticBody3D.new()
		col_body.name = "RoadCollision"
		col_body.collision_layer = 1
		col_body.collision_mask  = 0
		col_body.position = Vector3.ZERO
		add_child(col_body)

		var col_depth := 8.0  # metres below surface — generous enough to catch tunnelling
		var mn2 := mesh_pts.size()
		var col_verts := PackedVector3Array()
		var col_indices := PackedInt32Array()

		# Build top + bottom vertex pairs for each cross-section
		# Layout: for each waypoint i → 4 verts: top-left, top-right, bot-left, bot-right
		for i in mn2:
			var cur2: Vector3 = mesh_pts[i]
			var right2: Vector3 = mesh_rights[i]
			var bank_deg2: float = mesh_banks[i] if i < mesh_banks.size() else 0.0
			var bank_h2 := tan(deg_to_rad(bank_deg2)) * half_w
			var left_top  := cur2 - right2 * half_w + Vector3(0, 0.02 + bank_h2, 0)
			var right_top := cur2 + right2 * half_w + Vector3(0, 0.02 - bank_h2, 0)

			# Surface normal for this cross-section (perpendicular to banked surface)
			var surf_n := (right_top - left_top).cross(
				mesh_pts[(i + 1) % mn2] - cur2).normalized()
			if surf_n.y < 0.0:
				surf_n = -surf_n  # Ensure outward-facing (upward)

			var left_bot  := left_top  - surf_n * col_depth
			var right_bot := right_top - surf_n * col_depth

			col_verts.append(left_top)    # base + 0
			col_verts.append(right_top)   # base + 1
			col_verts.append(left_bot)    # base + 2
			col_verts.append(right_bot)   # base + 3

		# Closing cross-section (wraps to first)
		var cr0: Vector3 = mesh_rights[0]
		var cp0: Vector3 = mesh_pts[0]
		var cb0: float = mesh_banks[0] if not mesh_banks.is_empty() else 0.0
		var cbh0 := tan(deg_to_rad(cb0)) * half_w
		var cl_top := cp0 - cr0 * half_w + Vector3(0, 0.02 + cbh0, 0)
		var crt_top := cp0 + cr0 * half_w + Vector3(0, 0.02 - cbh0, 0)
		var csn := (crt_top - cl_top).cross(mesh_pts[1] - cp0).normalized()
		if csn.y < 0.0:
			csn = -csn
		col_verts.append(cl_top)
		col_verts.append(crt_top)
		col_verts.append(cl_top - csn * col_depth)
		col_verts.append(crt_top - csn * col_depth)

		# Build indices — for each segment: top face, bottom face, two side faces
		for i in mn2:
			var b  := i * 4          # current cross-section base
			var nb := (i + 1) * 4    # next cross-section base
			# Top face (two triangles)
			col_indices.append(b);     col_indices.append(nb);     col_indices.append(b + 1)
			col_indices.append(b + 1); col_indices.append(nb);     col_indices.append(nb + 1)
			# Bottom face (two triangles, wound opposite)
			col_indices.append(b + 2); col_indices.append(b + 3); col_indices.append(nb + 2)
			col_indices.append(b + 3); col_indices.append(nb + 3); col_indices.append(nb + 2)
			# Left side (top-left to bot-left)
			col_indices.append(b);     col_indices.append(b + 2); col_indices.append(nb)
			col_indices.append(nb);    col_indices.append(b + 2); col_indices.append(nb + 2)
			# Right side (top-right to bot-right)
			col_indices.append(b + 1); col_indices.append(nb + 1); col_indices.append(b + 3)
			col_indices.append(nb + 1); col_indices.append(nb + 3); col_indices.append(b + 3)

		var col_arrays := []
		col_arrays.resize(Mesh.ARRAY_MAX)
		col_arrays[Mesh.ARRAY_VERTEX] = col_verts
		col_arrays[Mesh.ARRAY_INDEX]  = col_indices
		var col_mesh := ArrayMesh.new()
		col_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, col_arrays)
		var trimesh := col_mesh.create_trimesh_shape()
		if trimesh:
			var col_shape := CollisionShape3D.new()
			col_shape.shape = trimesh
			col_body.add_child(col_shape)
		else:
			push_warning("TrackGenerator: Failed to create thick road collision trimesh!")

# ─── Checkpoints — lap gates evenly spaced around the circuit ────────────────
func _build_checkpoints() -> void:
	var n := waypoints.size()
	if n < 20:
		return

	# Checkpoints: finish line at waypoint 0, rest spread evenly
	# Fewer for shorter tracks
	var num_checkpoints := 5 if GameManager.selected_track != 0 else 10
	var spacing := n / num_checkpoints

	for ci in num_checkpoints:
		var wp_idx := ci * spacing
		var cur: Vector3 = waypoints[wp_idx]
		var nxt: Vector3 = waypoints[(wp_idx + 1) % n]
		var fwd := (nxt - cur).normalized()
		var angle := atan2(fwd.x, fwd.z)

		var cp := Checkpoint.new()
		cp.checkpoint_index = ci
		cp.is_finish_line = (ci == 0)
		cp.position = cur + Vector3(0, 5.0, 0)  # Raised to catch hovering vehicles
		cp.rotation.y = angle
		add_child(cp)

# ─── Waypoint computation (no nodes created) ─────────────────────────────────
func _compute_waypoints() -> void:
	var pts = CONTROL_POINTS if GameManager.selected_track == 0 else TEST_CONTROL_POINTS
	# Test track: 20 subdivisions halves the quad length (~200 m vs ~400 m),
	# halving the kink angle at every seam. Pylon accumulator keeps the light
	# count identical to 10-sub so there is no performance hit.
	var subdivs := 10 if GameManager.selected_track == 0 else 20
	waypoints = _catmull_rom_chain(pts, subdivs)
	var n := waypoints.size()
	_banked_rights.clear()
	for i in n:
		var prev: Vector3 = waypoints[(i - 1 + n) % n]
		var cur:  Vector3 = waypoints[i]
		var nxt:  Vector3 = waypoints[(i + 1) % n]
		var d_in  := (cur - prev).normalized()
		var d_out := (nxt - cur).normalized()
		var avg   := (d_in + d_out).normalized()
		if avg.length_squared() < 0.001:
			avg = d_out
		_banked_rights.append(avg.cross(Vector3.UP).normalized())

	# Compute per-waypoint bank angles (smooth interpolation from control point data)
	_bank_angles.clear()
	if GameManager.selected_track != 0:
		_bank_angles = _catmull_rom_chain_1d(TEST_BANK_ANGLES, subdivs)
	else:
		_bank_angles.resize(n)
		_bank_angles.fill(0.0)

# ─── Track construction (uses chunks) ────────────────────────────────────────
func _build_track() -> void:
	var n := waypoints.size()
	var warm_amber := Color(1.0, 0.75, 0.3)

	if GameManager.selected_track != 0:
		# Test track — no barrier walls, just wide painted edge strips + markers
		_pylon_accum_dist = 0.0  # Reset so pylons stay ~500m apart regardless of subdivision count
		for i in n:
			var a := waypoints[i]
			var b := waypoints[(i + 1) % n]
			_build_test_edge_strips(a, b, warm_amber, i)
		_build_corner_signs(n)
		_build_turn_arrows(n, _chevron_mat_blue, Color(0.2, 0.6, 1.0))
	else:
		for i in n:
			var a := waypoints[i]
			var b := waypoints[(i + 1) % n]
			_build_curbs(a, b, warm_amber, i)
		_build_corner_signs(n)
		_build_turn_arrows(n)

# Edge lines are now integrated into _build_curbs as neon caps on each barrier block.

# ─── Test track edge — flat painted strips, no walls ─────────────────────────
func _build_test_edge_strips(a: Vector3, b: Vector3, color: Color, idx: int) -> void:
	var seg  := b - a
	var dist := seg.length()
	if dist < 1.0:
		return
	var fwd   := seg.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var angle := atan2(fwd.x, fwd.z)
	var chunk := _chunk_for(idx)

	# Two flat neon strips — one each side at EDGE_OFFSET
	# Alternating white/amber blocks like a runway marking
	var stripe_len := 20.0
	var count := ceili(dist / stripe_len)
	for j in count:
		var t := (float(j) + 0.5) * stripe_len / dist
		if t > 1.0:
			break
		var pos := a.lerp(b, t)
		var is_bright := (j + idx) % 4 < 2   # 2 on / 2 off pattern
		var strip_col := color if is_bright else Color(1.0, 1.0, 1.0)
		var strip_mat := _neon_mat(strip_col, 60.0 if is_bright else 30.0)

		for side in [-1, 1]:
			var sp: Vector3 = pos + right * side * (EDGE_OFFSET + 1.0) + Vector3(0, 0.05, 0)
			_batch_box(sp, Vector3(4.0, 0.12, stripe_len * 0.9), Vector3(0, angle, 0), strip_mat, chunk)

		# Every ~500m place a tall pylon — use accumulated distance so spacing
		# stays constant regardless of how many subdivisions the mesh uses.
		_pylon_accum_dist += stripe_len
		if _pylon_accum_dist >= 500.0:
			_pylon_accum_dist -= 500.0
			for side in [-1, 1]:
				var pylon_pos: Vector3 = pos + right * side * (EDGE_OFFSET + 6.0) + Vector3(0, 0, 0)
				_batch_box(pylon_pos, Vector3(1.2, 12.0, 1.2), Vector3.ZERO,
					_neon_mat(color, 80.0), chunk)
				# Light on top
				var lamp := OmniLight3D.new()
				lamp.light_color     = color
				lamp.light_energy    = 20.0
				lamp.omni_range      = 120.0
				lamp.shadow_enabled  = false
				lamp.distance_fade_enabled = true
				lamp.distance_fade_begin   = 8000.0
				lamp.distance_fade_length  = 500.0
				lamp.position = pylon_pos + Vector3(0, 13.0, 0)
				chunk.add_child(lamp)

# ─── Banking angle markers — glowing overhead arches at banked sections ───────
func _build_bank_markers(n: int) -> void:
	var last_marker := -20
	for i in range(0, n, 2):
		var bank: float = _bank_angles[i] if i < _bank_angles.size() else 0.0
		if absf(bank) < 8.0:
			continue
		if i - last_marker < 15:
			continue
		last_marker = i

		var cur  := waypoints[i]
		var nxt  := waypoints[(i + 1) % n]
		var fwd  := (nxt - cur).normalized()
		var right: Vector3 = _banked_rights[i]
		var angle := atan2(fwd.x, fwd.z)
		var chunk := _chunk_for(i)

		# Build a simple arch spanning the track — two tall posts + top beam
		var arch_col := Color(0.2, 0.8, 1.0)    # Cyan for banking sections
		var post_h   := 40.0 + absf(bank) * 1.5  # Taller at steeper banks

		for side in [-1, 1]:
			var post_pos: Vector3 = cur + right * float(side) * (TRACK_WIDTH * 0.5 - 20.0) + Vector3(0, post_h * 0.5, 0)
			_batch_box(post_pos, Vector3(3.0, post_h, 3.0), Vector3(0, angle, 0),
				_neon_mat(arch_col, 50.0), chunk)

		var beam_pos: Vector3 = cur + Vector3(0, post_h + 1.5, 0)
		_batch_box(beam_pos, Vector3(TRACK_WIDTH - 40.0, 3.0, 3.0), Vector3(0, angle, 0),
			_neon_mat(arch_col, 60.0), chunk)

		# Glow source at top centre
		var glow := OmniLight3D.new()
		glow.light_color   = arch_col
		glow.light_energy  = 30.0
		glow.omni_range    = 350.0
		glow.shadow_enabled = false
		glow.distance_fade_enabled = true
		glow.distance_fade_begin   = 8000.0
		glow.distance_fade_length  = 500.0
		glow.position = beam_pos
		chunk.add_child(glow)

func _build_centre_dashes(a: Vector3, b: Vector3, color: Color) -> void:
	var seg  := b - a
	var dist := seg.length()
	if dist < 1.0:
		return
	var fwd   := seg.normalized()
	var angle := atan2(fwd.x, fwd.z)

	var count := int(dist / LINE_SPACING)
	if count < 1:
		count = 1
	for j in count:
		var t   := (float(j) + 0.5) / float(count)
		var pos := a.lerp(b, t) + Vector3(0, 0.04, 0)
		var dash := MeshInstance3D.new()
		var dm   := BoxMesh.new()
		dm.size  = Vector3(1.2, 0.06, 8.0)
		dash.mesh = dm
		dash.position   = pos
		dash.rotation.y = angle
		dash.material_override = _neon_mat(color, 40.0)
		add_child(dash)

func _build_corner_signs(n: int) -> void:
	var look := 10
	var step := 5
	for i in range(0, n, step):
		var behind: Vector3 = waypoints[(i - look + n) % n]
		var cur:    Vector3 = waypoints[i]
		var ahead:  Vector3 = waypoints[(i + look) % n]
		var d_in  := (cur - behind).normalized()
		var d_out := (ahead - cur).normalized()
		var dot   := d_in.dot(d_out)
		if dot > 0.985:
			continue
		var cross_y := d_in.cross(d_out).y
		var turn_right := cross_y < 0.0
		var right: Vector3 = _banked_rights[i]
		var fwd   := d_out
		var chunk := _chunk_for(i)

		var severity := clampf((1.0 - dot) * 3.0, 1.0, 3.0)
		var sign_count := int(severity)

		var outside_dir := right * (1.0 if turn_right else -1.0)
		for s in sign_count:
			var sign_pos := cur + outside_dir * (EDGE_OFFSET + 40.0) + Vector3(0, 25.0 + float(s) * 12.0, 0)
			_place_arrow_sign(sign_pos, fwd, turn_right, severity, chunk)

		if dot < 0.92:
			var beacon := OmniLight3D.new()
			var bcol := Color(1.0, 0.5, 0.15) if severity > 2.0 else Color(1.0, 0.75, 0.3)
			beacon.light_color    = bcol
			beacon.light_energy   = 40.0
			beacon.omni_range     = 300.0
			beacon.shadow_enabled = false
			beacon.distance_fade_enabled = true
			beacon.distance_fade_begin = 4800.0
			beacon.distance_fade_length = 400.0
			beacon.position       = cur + outside_dir * EDGE_OFFSET + Vector3(0, 50.0, 0)
			chunk.add_child(beacon)

func _place_arrow_sign(pos: Vector3, forward: Vector3, turn_right: bool, severity: float, parent: Node3D) -> void:
	var angle := atan2(forward.x, forward.z)
	var col := Color(1.0, 0.9, 0.0)
	if severity > 2.0:
		col = Color(1.0, 0.3, 0.0)
	elif severity > 1.5:
		col = Color(1.0, 0.6, 0.0)
	_batch_box(pos, Vector3(30.0, 15.0, 0.3), Vector3(0, angle, 0), _neon_mat(col, 30.0), parent)

	var side_offset := 12.0 if turn_right else -12.0
	var ind_pos := pos + Vector3(side_offset, 0, 0).rotated(Vector3.UP, angle)
	_batch_box(ind_pos, Vector3(8.0, 15.0, 0.5), Vector3(0, angle, 0), _neon_mat(Color(1.0, 1.0, 1.0), 40.0), parent)

# ─── Curbs — alternating neon/black blocks along road edges ───────────────────
func _build_curbs(a: Vector3, b: Vector3, color: Color, idx: int) -> void:
	var seg  := b - a
	var dist := seg.length()
	if dist < 1.0:
		return
	var fwd   := seg.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var angle := atan2(fwd.x, fwd.z)
	var chunk := _chunk_for(idx)
	var neon_mat := _neon_mat(color, 120.0)
	var cap_mat := _neon_mat(color, 150.0)

	# One long occluder per side for the entire barrier wall segment
	for side in [-1, 1]:
		var wall_center: Vector3 = (a + b) * 0.5 + right * side * (EDGE_OFFSET + 3.0) + Vector3(0, CURB_SIZE.y * 0.5, 0)
		var wall_occ := OccluderInstance3D.new()
		var box_occ := BoxOccluder3D.new()
		box_occ.size = Vector3(CURB_SIZE.x, CURB_SIZE.y, dist)
		wall_occ.occluder = box_occ
		wall_occ.position = wall_center
		wall_occ.rotation.y = angle
		chunk.add_child(wall_occ)

	# Place blocks contiguously — no gaps (ceili to cover full segment)
	var count := ceili(dist / CURB_BLOCK_LEN)
	if count < 1:
		return

	for j in count:
		var t := (float(j) + 0.5) * CURB_BLOCK_LEN / dist
		if t > 1.0:
			break
		var curb_pos := a.lerp(b, t)
		# 10 black then 1 yellow, repeating
		var is_neon := (j + idx) % 22 == 21

		for side in [-1, 1]:
			var cpos: Vector3 = curb_pos + right * side * (EDGE_OFFSET + 3.0) + Vector3(0, CURB_SIZE.y * 0.5, 0)
			# Neon light strip on the ground beside the barrier (road side)
			var strip_pos: Vector3 = curb_pos + right * side * (EDGE_OFFSET - 1.0) + Vector3(0, 0.05, 0)
			_batch_box(strip_pos, Vector3(3.0, 0.15, CURB_SIZE.z), Vector3(0, angle, 0), cap_mat, chunk)
			if is_neon:
				_batch_box(cpos, CURB_SIZE, Vector3(0, angle, 0), neon_mat, chunk)
				# Actual light that illuminates the road
				var barrier_light := OmniLight3D.new()
				barrier_light.light_color = color
				barrier_light.light_energy = 375.0
				barrier_light.omni_range = 200.0
				barrier_light.omni_attenuation = 1.0
				barrier_light.shadow_enabled = false
				barrier_light.distance_fade_enabled = true
				barrier_light.distance_fade_begin = 4800.0
				barrier_light.distance_fade_length = 400.0
				barrier_light.position = cpos + Vector3(0, 1.0, 0)
				chunk.add_child(barrier_light)
			else:
				_batch_box(cpos, CURB_SIZE, Vector3(0, angle, 0), _dark_curb_mat, chunk)

# ─── Massive neon >>> hovering above the track BEFORE each corner ─────────────
func _build_turn_arrows(n: int, mat: ShaderMaterial = null, glow_col: Color = Color(1.0, 0.0, 0.6)) -> void:
	if mat == null:
		mat = _chevron_mat
	var look := 6
	var last_corner := -30
	for i in range(0, n, 2):
		var behind: Vector3 = waypoints[(i - look + n) % n]
		var cur:    Vector3 = waypoints[i]
		var ahead:  Vector3 = waypoints[(i + look) % n]
		var d_in  := (cur - behind).normalized()
		var d_out := (ahead - cur).normalized()
		var dot   := d_in.dot(d_out)
		if dot > 0.85:
			continue
		if i - last_corner < 10:
			continue
		last_corner = i

		var cross_y := d_in.cross(d_out).y
		var turn_right := cross_y < 0.0
		var chunk := _chunk_for(i)
		var fwd := d_in
		var face_angle := atan2(fwd.x, fwd.z)

		# 200m before the turn, centered above the track
		var center: Vector3 = cur - fwd * 200.0 + Vector3(0, 80.0, 0)
		var turn_sign := -1.0 if turn_right else 1.0

		# Build >>> from pixel-art style blocks — no rotations, just offsets
		# Each > is 7 rows of blocks stacked vertically, offset laterally to form arrow
		# Row pattern for > pointing right (turn_sign = +1):
		#   row 0 (top):    far left
		#   row 1:          mid left
		#   row 2:          near center
		#   row 3 (middle): tip (rightmost)
		#   row 4:          near center
		#   row 5:          mid left
		#   row 6 (bottom): far left
		var block_w := 10.0   # width of each block
		var block_h := 5.0    # height of each row
		var block_d := 2.5    # depth
		var step    := 8.0    # lateral step per row toward the tip
		var rows := 7
		var mid_row := 3      # tip row

		for chev in range(3):
			var phase := float(chev) / 3.0
			# Space the three chevrons along the turn direction
			var chev_lateral := turn_sign * (float(chev) - 1.0) * 36.0
			var chev_center: Vector3 = center + Vector3(chev_lateral, 0, 0).rotated(Vector3.UP, face_angle)

			for row in rows:
				# How far from the tip this row is (0 at tip, 3 at extremes)
				var dist_from_tip := absi(row - mid_row)
				# Lateral offset: tip is furthest in turn direction, edges are furthest away
				var row_lateral := turn_sign * float(mid_row - dist_from_tip) * step
				# Vertical offset: row 0 at top, row 6 at bottom
				var row_y := float(mid_row - row) * block_h

				var block_pos: Vector3 = chev_center \
					+ Vector3(row_lateral, row_y, 0).rotated(Vector3.UP, face_angle)
				_batch_box(block_pos, Vector3(block_w, block_h, block_d),
					Vector3(0, face_angle, 0), mat, chunk, 0.0,
					Color(phase, 0, 0, 0))

		var glow := OmniLight3D.new()
		glow.light_color = glow_col
		glow.light_energy = 50.0
		glow.omni_range = 300.0
		glow.shadow_enabled = false
		glow.distance_fade_enabled = true
		glow.distance_fade_begin = 4800.0
		glow.distance_fade_length = 400.0
		glow.position = center
		chunk.add_child(glow)

# ─── Retro City Scenery ──────────────────────────────────────────────────────
func _build_city_scenery() -> void:
	var n := waypoints.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic — same city every time

	# Neon color palette — retro cyberpunk
	var neon_colors: Array[Color] = [
		Color(1.0, 0.0, 0.4),    # Hot pink
		Color(0.0, 1.0, 0.9),    # Cyan
		Color(0.6, 0.0, 1.0),    # Purple
		Color(1.0, 0.4, 0.0),    # Orange
		Color(0.0, 0.6, 1.0),    # Blue
		Color(0.0, 1.0, 0.3),    # Green
		Color(1.0, 0.75, 0.3),   # Warm amber
	]

	# ── Dense city lining the circuit — towering skyscrapers ──
	# Hard clearance: no building center closer than this to any waypoint.
	var HARD_CLEARANCE := TRACK_WIDTH * 0.5 + 300.0  # 460m — very generous to prevent any road overlap
	var building_spacing := 8
	for i in range(0, n, building_spacing):
		var cur: Vector3 = waypoints[i]
		var nxt: Vector3 = waypoints[(i + 1) % n]
		var fwd := (nxt - cur).normalized()
		var right := fwd.cross(Vector3.UP).normalized()

		for side in [-1, 1]:
			for row in range(5):
				# Massive buildings — fewer but much bigger
				var bw := rng.randf_range(120.0, 300.0)
				var bd := rng.randf_range(100.0, 250.0)

				# Row offsets — all well clear of track
				var base_offset: float
				if row == 0:
					base_offset = HARD_CLEARANCE + bw * 0.5 + rng.randf_range(10.0, 50.0)
				elif row == 1:
					base_offset = HARD_CLEARANCE + bw * 0.5 + 150.0 + rng.randf_range(0.0, 80.0)
				elif row < 4:
					base_offset = HARD_CLEARANCE + bw * 0.5 + 250.0 + float(row) * 180.0 + rng.randf_range(0.0, 100.0)
				elif row < 6:
					base_offset = HARD_CLEARANCE + bw * 0.5 + 600.0 + float(row) * 250.0 + rng.randf_range(0.0, 150.0)
				else:
					base_offset = HARD_CLEARANCE + bw * 0.5 + 1200.0 + float(row) * 300.0 + rng.randf_range(0.0, 200.0)

				var pos: Vector3 = cur + right * side * base_offset

				# Verify against EVERY waypoint AND midpoints — no building overlaps the track
				var too_close := false
				var min_clear := HARD_CLEARANCE + bw * 0.5
				var min_clear_sq := min_clear * min_clear
				for check_j in n:
					var wp: Vector3 = waypoints[check_j]
					var dx := pos.x - wp.x
					var dz := pos.z - wp.z
					if dx * dx + dz * dz < min_clear_sq:
						too_close = true
						break
					# Also check midpoint to next waypoint (catches inner curves)
					var wp_next: Vector3 = waypoints[(check_j + 1) % n]
					var mx := (wp.x + wp_next.x) * 0.5
					var mz := (wp.z + wp_next.z) * 0.5
					dx = pos.x - mx
					dz = pos.z - mz
					if dx * dx + dz * dz < min_clear_sq:
						too_close = true
						break
				if too_close:
					continue

				# Tall skyscrapers — fewer but much taller
				var min_h := 150.0 + float(row) * 80.0
				var max_h := 400.0 + float(row) * 250.0
				var bh := rng.randf_range(min_h, max_h)

				_place_building(pos, bw, bh, bd, neon_colors, rng, _chunk_for(i))

		# Street lamps — every other waypoint, both sides
		if i % 10 == 0:
			for lamp_side in [-1, 1]:
				var lamp_pos: Vector3 = cur + right * lamp_side * (EDGE_OFFSET + 12.0)
				var lamp_colors: Array[Color] = [
					Color(1.0, 0.75, 0.3),
					Color(1.0, 0.8, 0.45),
					Color(0.95, 0.9, 0.8),
				]
				_place_street_lamp(lamp_pos, lamp_colors[rng.randi() % lamp_colors.size()], _chunk_for(i))

	# ── Holographic billboards ──
	for i in range(0, n, 15):
		var cur: Vector3 = waypoints[i]
		var nxt: Vector3 = waypoints[(i + 1) % n]
		var fwd := (nxt - cur).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var board_side := 1 if (i / 15) % 2 == 0 else -1
		var board_pos := cur + right * board_side * (EDGE_OFFSET + 200.0) + Vector3(0, 55.0, 0)
		var angle := atan2(fwd.x, fwd.z)
		_place_billboard(board_pos, angle, neon_colors[rng.randi() % neon_colors.size()], _chunk_for(i))

	# ── Neon ground strips between buildings ──
	for i in range(0, n, 8):
		var cur: Vector3 = waypoints[i]
		var nxt: Vector3 = waypoints[(i + 1) % n]
		var fwd := (nxt - cur).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var angle := atan2(fwd.x, fwd.z)
		var chunk := _chunk_for(i)
		for side in [-1, 1]:
			var strip_pos: Vector3 = cur + right * side * (EDGE_OFFSET + 60.0) + Vector3(0, 0.05, 0)
			var gcol: Color = neon_colors[rng.randi() % neon_colors.size()]
			_batch_box(strip_pos, Vector3(1.5, 0.1, 40.0), Vector3(0, angle, 0), _neon_mat(gcol, 25.0), chunk, 1200.0)

	# ── Skyline ring — distant mega-towers (always visible) ──
	var center := Vector3(3500.0, 0, 16700.0)
	for i in range(80):
		var ang := float(i) / 80.0 * TAU
		var dist := rng.randf_range(12000.0, 35000.0)
		var pos := center + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		var bh := rng.randf_range(400.0, 1500.0)
		var bw := rng.randf_range(80.0, 300.0)
		_place_building(pos, bw, bh, bw * 0.8, neon_colors, rng, _skyline_node)

	# ── Floating neon ad panels ──
	for i in range(0, n, 25):
		var cur: Vector3 = waypoints[i]
		var nxt: Vector3 = waypoints[(i + 1) % n]
		var fwd := (nxt - cur).normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var angle := atan2(fwd.x, fwd.z)
		var chunk := _chunk_for(i)
		for side in [-1, 1]:
			var ad_pos: Vector3 = cur + right * float(side) * (EDGE_OFFSET + rng.randf_range(200.0, 500.0)) + Vector3(0, rng.randf_range(80.0, 200.0), 0)
			var ad_w := rng.randf_range(20.0, 50.0)
			var ad_h := rng.randf_range(10.0, 25.0)
			var ad_angle := angle + rng.randf_range(-0.3, 0.3)
			var ad_mat := _neon_mat(neon_colors[rng.randi() % neon_colors.size()], rng.randf_range(20.0, 45.0))
			_batch_box(ad_pos, Vector3(ad_w, ad_h, 0.3), Vector3(0, ad_angle, 0), ad_mat, chunk, 4000.0)

			var ad_glow := OmniLight3D.new()
			ad_glow.light_color = neon_colors[rng.randi() % neon_colors.size()]
			ad_glow.light_energy = 12.0
			ad_glow.omni_range = 120.0
			ad_glow.shadow_enabled = false
			ad_glow.distance_fade_enabled = true
			ad_glow.distance_fade_begin = 4800.0
			ad_glow.distance_fade_length = 400.0
			ad_glow.position = ad_pos
			chunk.add_child(ad_glow)


func _place_building(pos: Vector3, width: float, height: float, depth: float, colors: Array[Color], rng: RandomNumberGenerator, parent: Node3D = null) -> void:
	_building_count += 1
	var target: Node3D = parent if parent else self

	# Dark building body
	_batch_box(pos + Vector3(0, height * 0.5, 0), Vector3(width, height, depth), Vector3.ZERO, _building_body_mat, target)

	# Occlusion culling — building acts as occluder
	var occluder := OccluderInstance3D.new()
	var box_occ := BoxOccluder3D.new()
	box_occ.size = Vector3(width, height, depth)
	occluder.occluder = box_occ
	occluder.position = pos + Vector3(0, height * 0.5, 0)
	target.add_child(occluder)

	# Neon accent strips — front and back faces, bright emission, batched via MultiMesh
	var accent_col: Color = colors[rng.randi() % colors.size()]
	var accent_col2: Color = colors[rng.randi() % colors.size()]
	var strip_count := rng.randi_range(4, 8)
	for s in strip_count:
		var strip_h := rng.randf_range(height * 0.1, height * 0.95)
		var strip_mat := _neon_mat(accent_col if s % 2 == 0 else accent_col2, 50.0)
		# Front face
		var strip_pos := pos + Vector3(0, strip_h, depth * 0.51)
		_batch_box(strip_pos, Vector3(width * 0.9, 6.0, 3.5), Vector3.ZERO, strip_mat, target, 8000.0)
		# Back face
		var strip_pos_back := pos + Vector3(0, strip_h, -depth * 0.51)
		_batch_box(strip_pos_back, Vector3(width * 0.9, 6.0, 3.5), Vector3.ZERO, strip_mat, target, 8000.0)

func _place_street_lamp(pos: Vector3, color: Color, parent: Node3D = null) -> void:
	var target: Node3D = parent if parent else self

	# Pole
	_batch_box(pos + Vector3(0, 10.0, 0), Vector3(0.4, 20.0, 0.4), Vector3.ZERO, _pole_mat, target)

	# Fixture
	_batch_box(pos + Vector3(0, 20.5, 0), Vector3(4.0, 1.0, 4.0), Vector3.ZERO, _neon_mat(color, 12.0), target)

	var lamp_light := OmniLight3D.new()
	lamp_light.light_color   = color
	lamp_light.light_energy  = 8.0
	lamp_light.omni_range    = 80.0
	lamp_light.omni_attenuation = 1.2
	lamp_light.shadow_enabled = false
	lamp_light.distance_fade_enabled = true
	lamp_light.distance_fade_begin = 4800.0
	lamp_light.distance_fade_length = 400.0
	lamp_light.position = pos + Vector3(0, 18.0, 0)
	target.add_child(lamp_light)

func _place_billboard(pos: Vector3, angle: float, color: Color, parent: Node3D = null) -> void:
	var target: Node3D = parent if parent else self

	for offset in [-8.0, 8.0]:
		var pole_pos := pos + Vector3(offset, -27.5, 0).rotated(Vector3.UP, angle)
		_batch_box(pole_pos, Vector3(0.6, 55.0, 0.6), Vector3.ZERO, _pole_mat, target)

	_batch_box(pos, Vector3(28.0, 14.0, 0.4), Vector3(0, angle, 0), _neon_mat(color, 30.0), target)

	var frame_pos := pos + Vector3(0, 0, -0.3).rotated(Vector3.UP, angle)
	_batch_box(frame_pos, Vector3(30.0, 16.0, 0.2), Vector3(0, angle, 0), _neon_mat(Color(0.9, 0.9, 1.0), 15.0), target)

# ─── Point-in-track-loop test (ray casting, XZ plane) ────────────────────────
func _is_inside_track(px: float, pz: float) -> bool:
	var wn := waypoints.size()
	var inside := false
	var j := wn - 1
	for i in wn:
		var zi := waypoints[i].z
		var zj := waypoints[j].z
		var xi := waypoints[i].x
		var xj := waypoints[j].x
		if ((zi > pz) != (zj > pz)) and (px < (xj - xi) * (pz - zi) / (zj - zi) + xi):
			inside = not inside
		j = i
	return inside

# ─── Catmull-Rom ──────────────────────────────────────────────────────────────
func _catmull_rom_chain(pts: Array, subdivisions: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var pn := pts.size()
	for i in pn:
		var p0: Vector3 = pts[(i - 1 + pn) % pn] as Vector3
		var p1: Vector3 = pts[i]                  as Vector3
		var p2: Vector3 = pts[(i + 1) % pn]       as Vector3
		var p3: Vector3 = pts[(i + 2) % pn]       as Vector3
		for j in subdivisions:
			var t := float(j) / float(subdivisions)
			result.append(_catmull_rom(p0, p1, p2, p3, t))
	return result

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## 1D Catmull-Rom for bank angle interpolation
func _catmull_rom_chain_1d(vals: Array, subdivisions: int) -> Array[float]:
	var result: Array[float] = []
	var pn := vals.size()
	for i in pn:
		var p0: float = vals[(i - 1 + pn) % pn]
		var p1: float = vals[i]
		var p2: float = vals[(i + 1) % pn]
		var p3: float = vals[(i + 2) % pn]
		for j in subdivisions:
			var t := float(j) / float(subdivisions)
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return result

# ─── Materials ────────────────────────────────────────────────────────────────
func _init_shared_materials() -> void:
	_building_body_mat = StandardMaterial3D.new()
	_building_body_mat.albedo_color = Color(0.08, 0.09, 0.14)
	_building_body_mat.metallic     = 0.4
	_building_body_mat.roughness    = 0.35
	_building_body_mat.emission_enabled = true
	_building_body_mat.emission = Color(0.03, 0.035, 0.06)
	_building_body_mat.emission_energy_multiplier = 0.25

	_pole_mat = StandardMaterial3D.new()
	_pole_mat.albedo_color = Color(0.08, 0.08, 0.12)
	_pole_mat.metallic   = 0.95
	_pole_mat.roughness  = 0.2

	_dark_curb_mat = StandardMaterial3D.new()
	_dark_curb_mat.albedo_color = Color(0.08, 0.08, 0.12)
	_dark_curb_mat.metallic     = 0.5
	_dark_curb_mat.roughness    = 0.3

	var chevron_shader := load("res://shaders/chevron_chase.gdshader") as Shader
	_chevron_mat = ShaderMaterial.new()
	_chevron_mat.shader = chevron_shader
	_chevron_mat.set_shader_parameter("base_color", Vector3(1.0, 0.0, 0.6))
	_chevron_mat.set_shader_parameter("speed", 2.5)

	_chevron_mat_blue = ShaderMaterial.new()
	_chevron_mat_blue.shader = chevron_shader
	_chevron_mat_blue.set_shader_parameter("base_color", Vector3(0.2, 0.6, 1.0))
	_chevron_mat_blue.set_shader_parameter("speed", 2.5)

func _neon_mat(color: Color, energy: float) -> StandardMaterial3D:
	# Quantize energy to reduce unique materials
	var e_key := int(energy * 2.0)
	# Quantize color to reduce unique materials
	var r := int(color.r * 10.0)
	var g := int(color.g * 10.0)
	var b := int(color.b * 10.0)
	var key := r * 100000000 + g * 1000000 + b * 10000 + e_key
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color     = color * 0.5
	m.emission_enabled = true
	m.emission         = color
	m.emission_energy_multiplier = energy
	_mat_cache[key] = m
	return m

# ─── MultiMesh Batching ─────────────────────────────────────────────────────
## Collect a box instance for deferred batching into MultiMeshInstance3D.
## All boxes use a shared unit BoxMesh(1,1,1) scaled via the transform.
func _batch_box(pos: Vector3, size: Vector3, rot: Vector3, mat: Material, chunk: Node3D, vis_range: float = 0.0, custom: Color = Color(0, 0, 0, 0)) -> void:
	var key := "%d_%d_%.0f" % [chunk.get_instance_id(), mat.get_instance_id(), vis_range]
	if not _batch_data.has(key):
		_batch_data[key] = {chunk = chunk, mat = mat, vis_range = vis_range, transforms = [], customs = []}
	var basis := Basis.from_euler(rot).scaled(size)
	_batch_data[key].transforms.append(Transform3D(basis, pos))
	_batch_data[key].customs.append(custom)

## Flush all collected batch data into MultiMeshInstance3D nodes.
## Each unique (chunk, material, visibility_range) combination becomes one draw call.
func _flush_batches() -> void:
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3(1, 1, 1)
	for key in _batch_data:
		var batch: Dictionary = _batch_data[key]
		var transforms: Array = batch.transforms
		var count := transforms.size()
		if count == 0:
			continue

		var has_custom := false
		for c in batch.customs:
			if c != Color(0, 0, 0, 0):
				has_custom = true
				break

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = has_custom
		mm.mesh = unit_box
		mm.instance_count = count
		for i in count:
			mm.set_instance_transform(i, transforms[i])
		if has_custom:
			for i in count:
				mm.set_instance_custom_data(i, batch.customs[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = batch.mat
		if batch.vis_range > 0.0:
			mmi.visibility_range_end = batch.vis_range
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		batch.chunk.add_child(mmi)
	_batch_data.clear()
