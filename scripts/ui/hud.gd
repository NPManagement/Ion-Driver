## HUD — Retro-futuristic in-race heads-up display.
## Segmented bars, angular panels, neon borders, WipEout/F-Zero aesthetic.
extends CanvasLayer
class_name HUD

# ─── Minimap ────────────────────────────────────────────────────────────────────
class _MiniMapPanel extends Control:
	const PAD      := 6.0
	const MAP_SIZE := Vector2(148.0, 140.0)

	var map_waypoints: Array = []
	var map_vehicles:  Array = []
	var _min_x: float = 0.0
	var _min_z: float = 0.0
	var _sc:    float = 1.0
	var _off:   Vector2 = Vector2.ZERO
	var _ready_to_draw := false

	func set_data(wps: Array, vehs: Array) -> void:
		map_waypoints = wps
		map_vehicles  = vehs
		if wps.is_empty():
			return
		var mx := (wps[0] as Vector3).x;  var xx := mx
		var mz := (wps[0] as Vector3).z;  var xz := mz
		for wp in wps:
			var w := wp as Vector3
			mx = minf(mx, w.x);  xx = maxf(xx, w.x)
			mz = minf(mz, w.z);  xz = maxf(xz, w.z)
		_min_x = mx;  _min_z = mz
		var tw := xx - mx;  var th := xz - mz
		var sc_x := (MAP_SIZE.x - PAD * 2.0) / maxf(tw, 1.0)
		var sc_z := (MAP_SIZE.y - PAD * 2.0) / maxf(th, 1.0)
		_sc  = minf(sc_x, sc_z)
		_off = Vector2(
			(MAP_SIZE.x - tw * _sc) * 0.5,
			(MAP_SIZE.y - th * _sc) * 0.5)
		_ready_to_draw = true

	func _wp_to_map(wp: Vector3) -> Vector2:
		return Vector2(
			(wp.x - _min_x) * _sc + _off.x,
			(wp.z - _min_z) * _sc + _off.y)

	func _draw() -> void:
		# Background
		draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.02, 0.03, 0.07, 0.88))
		draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.18, 0.55, 1.0, 0.75), false, 1.5)
		if not _ready_to_draw:
			return
		# Track line
		var n := map_waypoints.size()
		for i in n:
			var a: Vector2 = _wp_to_map(map_waypoints[i] as Vector3)
			var b: Vector2 = _wp_to_map(map_waypoints[(i + 1) % n] as Vector3)
			draw_line(a, b, Color(0.22, 0.52, 1.0, 0.55), 2.2)
		# Vehicles
		for v in map_vehicles:
			if not is_instance_valid(v):
				continue
			var iv := v as IonVehicle
			if iv == null:
				continue
			var dot_pos: Vector2 = _wp_to_map(iv.global_position)
			var is_p:    bool    = iv.is_player
			var dot_r:   float   = 4.5 if is_p else 2.8
			draw_circle(dot_pos, dot_r, Color(1.0, 0.85, 0.1) if is_p else Color(0.9, 0.18, 0.18))
			if is_p:  # Direction arrow
				var fwd: Vector3 = -iv.global_transform.basis.z
				var tip: Vector2 = dot_pos + Vector2(fwd.x, fwd.z).normalized() * 7.0
				draw_line(dot_pos, tip, Color(1.0, 1.0, 0.6, 0.9), 1.5)

	func _process(_d: float) -> void:
		queue_redraw()

# ────────────────────────────────────────────────────────────────────────────────
const CELL_COUNT    := 12
const NEON_CYAN     := Color(0.20, 0.85, 1.00)
const NEON_ORANGE   := Color(1.00, 0.45, 0.05)
const NEON_GREEN    := Color(0.15, 1.00, 0.40)
const NEON_RED      := Color(1.00, 0.12, 0.12)
const NEON_GOLD     := Color(1.00, 0.82, 0.10)
const PANEL_BG      := Color(0.02, 0.04, 0.09, 0.82)
const PANEL_BORDER  := Color(0.18, 0.55, 1.00, 0.90)
const CELL_BG       := Color(0.03, 0.05, 0.10, 1.0)

# ─── Layout nodes ──────────────────────────────────────────────────────────────
var _speed_label: Label
var _lap_label: Label
var _pos_label: Label
var _gap_label: Label    # Gap to car ahead/behind
var _time_label: Label
var _countdown_label: Label
var _lap_flash_label: Label
var _results_panel: Panel
var _best_lap_label: Label
var _speed_bar_fill: ColorRect
var _pause_overlay: Panel
var _pause_cam_sliders: Dictionary = {}
var _pause_music_slider: HSlider
var _pause_music_time: Label
var _pause_music_dragging: bool = false

# Boost smooth meter
var _boost_bar_fill: ColorRect
var _boost_bar_bg:   ColorRect
const BOOST_BAR_W := 170.0

# Tracking
var _current_energy: float = 100.0
var _max_energy: float     = 100.0
var _total_laps: int       = 3
var _race_time: float      = 0.0
var _race_active: bool     = false
var _lap_flash_timer: float = 0.0
var _boost_warn_t: float   = 0.0
var _vignette: ColorRect
var _boost_overlay: ColorRect
var _speedlines: Array = []
var _fps_label: Label
var _current_speed_kmh: float = 0.0
var _boost_flash_t: float = 0.0
var _beep_player: AudioStreamPlayer   # Countdown beep synthesis
var _minimap: _MiniMapPanel
var _delta_label: Label          # Current lap time vs best lap
var _delta_panel: Panel

func _ready() -> void:
	_total_laps = GameManager.get_lap_count()
	# Keep HUD active while game is paused so pause overlay shows
	process_mode = PROCESS_MODE_ALWAYS
	GameManager.game_state_changed.connect(_on_game_state_changed)
	_build_hud()
	_build_beep_player()

func _on_game_state_changed(state: GameManager.GameState) -> void:
	if _pause_overlay:
		_pause_overlay.visible = (state == GameManager.GameState.PAUSED)

func _build_beep_player() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate      = 44100.0
	gen.buffer_length = 0.50
	_beep_player = AudioStreamPlayer.new()
	_beep_player.stream    = gen
	_beep_player.volume_db = -4.0
	_beep_player.bus       = "SFX"
	add_child(_beep_player)

## Synthesise a short beep tone and push it into the AudioStreamGenerator.
## freq_hz: fundamental frequency. duration_s: seconds of tone.
func _play_beep(freq_hz: float, duration_s: float, vol: float = 0.55) -> void:
	if _beep_player == null or not _beep_player.is_playing():
		_beep_player.play()
	await get_tree().process_frame  # Wait one frame for playback to init
	var pb := _beep_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var rate     := 44100.0
	var samples  := int(duration_s * rate)
	var inc      := freq_hz * TAU / rate
	var phase    := 0.0
	var env_len  := int(rate * 0.012)   # 12ms attack/release envelope
	for i in samples:
		phase = fmod(phase + inc, TAU)
		var envelope := 1.0
		if i < env_len:
			envelope = float(i) / env_len
		elif i > samples - env_len:
			envelope = float(samples - i) / env_len
		var s := sin(phase) * vol * envelope
		pb.push_frame(Vector2(s, s))

# ─── Build ─────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var root := Control.new()
	root.name          = "HUDRoot"
	root.anchor_right  = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_vignette(root)
	_build_speedlines(root)
	_build_minimap_panel(root)
	_build_speedometer(root)
	_build_status_bars(root)
	_build_top_bar(root)
	_build_best_lap_panel(root)
	_build_delta_panel(root)
	_build_countdown(root)
	_build_lap_flash(root)
	_build_results_panel(root)
	_build_pause_overlay(root)
	_build_fps_counter(root)

func _build_speedometer(root: Control) -> void:
	# Large angular speed panel — bottom left
	var panel := _make_panel(root, Vector2(230, 110), Vector2(18, -118), CORNER_BOTTOM_LEFT)

	# Small label above number
	var unit_top := Label.new()
	unit_top.text     = "SPEED"
	unit_top.position = Vector2(12, 8)
	unit_top.size     = Vector2(206, 22)
	unit_top.add_theme_font_size_override("font_size", 11)
	unit_top.add_theme_color_override("font_color", Color(0.35, 0.60, 0.85))
	unit_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(unit_top)

	# Big speed number
	_speed_label = Label.new()
	_speed_label.text     = "0"
	_speed_label.position = Vector2(6, 20)
	_speed_label.size     = Vector2(170, 78)
	_speed_label.add_theme_font_size_override("font_size", 66)
	_speed_label.add_theme_color_override("font_color", NEON_CYAN)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_speed_label)

	# Unit label (right side)
	var unit := Label.new()
	unit.text     = "KM/H"
	unit.position = Vector2(178, 68)
	unit.size     = Vector2(46, 30)
	unit.add_theme_font_size_override("font_size", 13)
	unit.add_theme_color_override("font_color", Color(0.3, 0.55, 0.80))
	panel.add_child(unit)

	# Accent bar at top of panel
	var bar := ColorRect.new()
	bar.color    = NEON_CYAN
	bar.position = Vector2(0, 0)
	bar.size     = Vector2(230, 2)
	panel.add_child(bar)

	# Speed progress bar (fills with speed)
	var bar_bg := ColorRect.new()
	bar_bg.color    = Color(0.04, 0.07, 0.15)
	bar_bg.position = Vector2(6, 100)
	bar_bg.size     = Vector2(218, 5)
	panel.add_child(bar_bg)

	_speed_bar_fill = ColorRect.new()
	_speed_bar_fill.color    = NEON_CYAN
	_speed_bar_fill.position = Vector2(6, 100)
	_speed_bar_fill.size     = Vector2(0, 5)
	panel.add_child(_speed_bar_fill)

func _build_status_bars(root: Control) -> void:
	# Bars panel — boost only
	var panel := _make_panel(root, Vector2(260, 48), Vector2(18, -168), CORNER_BOTTOM_LEFT)

	var bl := _bar_label(panel, "BOOST", Vector2(10, 12), NEON_CYAN)

	_boost_bar_bg = ColorRect.new()
	_boost_bar_bg.color    = Color(0.03, 0.05, 0.10, 1.0)
	_boost_bar_bg.position = Vector2(80, 12)
	_boost_bar_bg.size     = Vector2(BOOST_BAR_W, 22)
	panel.add_child(_boost_bar_bg)

	_boost_bar_fill = ColorRect.new()
	_boost_bar_fill.color    = NEON_CYAN
	_boost_bar_fill.position = Vector2(80, 12)
	_boost_bar_fill.size     = Vector2(BOOST_BAR_W, 22)
	panel.add_child(_boost_bar_fill)

	var bar := ColorRect.new()
	bar.color    = NEON_CYAN
	bar.position = Vector2(0, 0)
	bar.size     = Vector2(260, 2)
	panel.add_child(bar)

func _bar_label(parent: Control, text: String, pos: Vector2, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.size     = Vector2(66, 24)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl


func _build_top_bar(root: Control) -> void:
	# Single top-right panel: LAP / TIME / POSITION
	var panel := _make_panel(root, Vector2(300, 130), Vector2(-318, 18), CORNER_TOP_RIGHT)

	# Accent bar at bottom
	var bar := ColorRect.new()
	bar.color    = NEON_CYAN
	bar.position = Vector2(0, 128)
	bar.size     = Vector2(300, 2)
	panel.add_child(bar)

	# LAP
	var lap_lbl := Label.new()
	lap_lbl.text     = "LAP"
	lap_lbl.position = Vector2(12, 8)
	lap_lbl.size     = Vector2(276, 18)
	lap_lbl.add_theme_font_size_override("font_size", 11)
	lap_lbl.add_theme_color_override("font_color", Color(0.35, 0.60, 0.85))
	panel.add_child(lap_lbl)

	_lap_label = Label.new()
	_lap_label.text     = "1 / %d" % _total_laps
	_lap_label.position = Vector2(10, 20)
	_lap_label.size     = Vector2(276, 36)
	_lap_label.add_theme_font_size_override("font_size", 28)
	_lap_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_lap_label)

	# Divider
	var div := ColorRect.new()
	div.color    = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.4)
	div.position = Vector2(10, 60)
	div.size     = Vector2(280, 1)
	panel.add_child(div)

	# TIME
	var time_lbl := Label.new()
	time_lbl.text     = "TIME"
	time_lbl.position = Vector2(12, 65)
	time_lbl.size     = Vector2(276, 18)
	time_lbl.add_theme_font_size_override("font_size", 11)
	time_lbl.add_theme_color_override("font_color", Color(0.35, 0.60, 0.85))
	panel.add_child(time_lbl)

	_time_label = Label.new()
	_time_label.text     = "0:00.000"
	_time_label.position = Vector2(10, 78)
	_time_label.size     = Vector2(276, 26)
	_time_label.add_theme_font_size_override("font_size", 20)
	_time_label.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_time_label)

	# POSITION — in its own prominent panel, top-right corner below top bar
	var pos_panel := _make_panel(root, Vector2(100, 108), Vector2(-116, 162), CORNER_TOP_RIGHT)

	var pos_lbl_top := Label.new()
	pos_lbl_top.text     = "POS"
	pos_lbl_top.position = Vector2(0, 6)
	pos_lbl_top.size     = Vector2(100, 18)
	pos_lbl_top.add_theme_font_size_override("font_size", 11)
	pos_lbl_top.add_theme_color_override("font_color", Color(0.35, 0.60, 0.85))
	pos_lbl_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_panel.add_child(pos_lbl_top)

	_pos_label = Label.new()
	_pos_label.text     = "P1"
	_pos_label.position = Vector2(0, 20)
	_pos_label.size     = Vector2(100, 52)
	_pos_label.add_theme_font_size_override("font_size", 50)
	_pos_label.add_theme_color_override("font_color", NEON_GOLD)
	_pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_panel.add_child(_pos_label)

	# Gap to car ahead — small label below position number
	_gap_label = Label.new()
	_gap_label.text     = ""
	_gap_label.position = Vector2(0, 72)
	_gap_label.size     = Vector2(100, 18)
	_gap_label.add_theme_font_size_override("font_size", 11)
	_gap_label.add_theme_color_override("font_color", NEON_CYAN)
	_gap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_panel.add_child(_gap_label)

	var pos_bar := ColorRect.new()
	pos_bar.color    = NEON_GOLD
	pos_bar.position = Vector2(0, 0)
	pos_bar.size     = Vector2(100, 2)
	pos_panel.add_child(pos_bar)

func _build_countdown(root: Control) -> void:
	_countdown_label = Label.new()
	_countdown_label.anchor_left   = 0.5
	_countdown_label.anchor_right  = 0.5
	_countdown_label.anchor_top    = 0.5
	_countdown_label.anchor_bottom = 0.5
	_countdown_label.position      = Vector2(-140, -100)
	_countdown_label.size          = Vector2(280, 200)
	_countdown_label.add_theme_font_size_override("font_size", 140)
	_countdown_label.add_theme_color_override("font_color", NEON_CYAN)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.pivot_offset  = Vector2(140, 100)
	_countdown_label.text = ""
	root.add_child(_countdown_label)

func _build_lap_flash(root: Control) -> void:
	_lap_flash_label = Label.new()
	_lap_flash_label.anchor_left   = 0.5
	_lap_flash_label.anchor_right  = 0.5
	_lap_flash_label.anchor_top    = 0.38
	_lap_flash_label.anchor_bottom = 0.38
	_lap_flash_label.position      = Vector2(-220, 0)
	_lap_flash_label.size          = Vector2(440, 70)
	_lap_flash_label.add_theme_font_size_override("font_size", 46)
	_lap_flash_label.add_theme_color_override("font_color", NEON_GREEN)
	_lap_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lap_flash_label.pivot_offset  = Vector2(220, 35)
	_lap_flash_label.text        = ""
	_lap_flash_label.modulate.a  = 0.0
	root.add_child(_lap_flash_label)

func _build_results_panel(root: Control) -> void:
	_results_panel = Panel.new()
	_results_panel.anchor_left   = 0.22
	_results_panel.anchor_right  = 0.78
	_results_panel.anchor_top    = 0.12
	_results_panel.anchor_bottom = 0.88
	_style_panel_sharp(_results_panel, PANEL_BG, NEON_CYAN, 2)
	_results_panel.visible = false
	root.add_child(_results_panel)

# ─── Update ────────────────────────────────────────────────────────────────────
func _fmt_music_time(secs: float) -> String:
	return "%d:%02d" % [int(secs) / 60, int(secs) % 60]

func _process(delta: float) -> void:
	if _fps_label:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	# Update pause music scrubber
	if _pause_music_slider and _pause_overlay and _pause_overlay.visible and not _pause_music_dragging:
		if AudioManager.is_music_playing():
			var length := AudioManager.get_music_length()
			if length > 0.0:
				var pos := AudioManager.get_music_position()
				_pause_music_slider.value = pos / length
				if _pause_music_time:
					_pause_music_time.text = "%s / %s" % [_fmt_music_time(pos), _fmt_music_time(length)]
	if _race_active and not get_tree().paused:
		_race_time += delta
		if _time_label:
			_time_label.text = GameManager.format_time(_race_time)

	# Lap flash fade
	if _lap_flash_timer > 0.0:
		_lap_flash_timer -= delta
		if _lap_flash_label:
			_lap_flash_label.modulate.a = clampf(_lap_flash_timer / 1.5, 0.0, 1.0)
	elif _lap_flash_label:
		_lap_flash_label.modulate.a = 0.0

	# Boost warning flash when critically low
	if _current_energy < _max_energy * 0.18 and _race_active:
		_boost_warn_t += delta * 5.0
		var flash := (sin(_boost_warn_t) * 0.5 + 0.5)
		if _boost_bar_fill:
			_boost_bar_fill.color = NEON_ORANGE * flash

	# Speed lines removed

	# Boost screen flash — brief blue pulse on boost activation
	if _boost_flash_t > 0.0:
		_boost_flash_t = maxf(_boost_flash_t - delta * 3.5, 0.0)
		if _boost_overlay:
			_boost_overlay.color.a = _boost_flash_t * 0.28



# ─── Public API ────────────────────────────────────────────────────────────────
func update_speed(kmh: float) -> void:
	_current_speed_kmh = kmh
	if _speed_label:
		_speed_label.text = str(int(kmh))
	if _speed_bar_fill:
		_speed_bar_fill.size.x = clampf(kmh / 600.0, 0.0, 1.0) * 218.0
	if _vignette:
		var spd_a := clampf((kmh - 180.0) / 420.0, 0.0, 0.22)
		_vignette.color.a = spd_a

func update_energy(current: float, maximum: float) -> void:
	_current_energy = current
	_max_energy     = maximum
	if _boost_bar_fill:
		_boost_bar_fill.size.x = clampf(current / maximum, 0.0, 1.0) * BOOST_BAR_W
		if _current_energy >= _max_energy * 0.18:
			_boost_warn_t = 0.0
			_boost_bar_fill.color = NEON_CYAN

func update_lap(lap: int, total: int, lap_time: float = 0.0) -> void:
	if _lap_label:
		_lap_label.text = "%d / %d" % [lap, total]
	var msg := "LAP  %d" % lap
	if lap_time > 0.0:
		msg += "   " + GameManager.format_time(lap_time)
	flash_lap_message(msg)

func update_position(_pos: int, _total: int) -> void:
	pass   # Solo time trial — position panel replaced by best lap focus

## Shows gap to car immediately ahead or behind the player.
## gap_ahead: seconds to car in front (INF = no car ahead / in P1)
## gap_behind: seconds gap behind (INF = no car behind / last place)
func update_gap(_gap_ahead: float, _gap_behind: float) -> void:
	pass   # Solo time trial — no gap display needed

func show_countdown(count: int) -> void:
	if not _countdown_label:
		return
	if count == 0:
		_countdown_label.text = "GO!"
		_countdown_label.add_theme_color_override("font_color", NEON_GREEN)
		_countdown_label.scale     = Vector2(1.6, 1.6)
		_countdown_label.modulate.a = 0.0
		_race_active = true
		var tw_go := create_tween().set_parallel(true)
		tw_go.tween_property(_countdown_label, "scale",      Vector2(1.0, 1.0), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw_go.tween_property(_countdown_label, "modulate:a", 1.0,               0.18)
		var tw_go2 := create_tween()
		tw_go2.tween_interval(0.75)
		tw_go2.tween_property(_countdown_label, "modulate:a", 0.0, 0.30)
		tw_go2.tween_callback(func(): _countdown_label.text = "")
		# GO! double beep — higher pitch
		_play_beep(880.0, 0.18, 0.65)
		await get_tree().create_timer(0.22).timeout
		_play_beep(1100.0, 0.28, 0.70)
	else:
		_countdown_label.text = str(count)
		_countdown_label.add_theme_color_override("font_color", NEON_CYAN)
		_countdown_label.scale      = Vector2(2.4, 2.4)
		_countdown_label.modulate.a = 0.0
		var tw_cnt := create_tween().set_parallel(true)
		tw_cnt.tween_property(_countdown_label, "scale",      Vector2(1.0, 1.0), 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw_cnt.tween_property(_countdown_label, "modulate:a", 1.0,               0.18)
		# Standard beep — mid pitch
		_play_beep(440.0, 0.14, 0.50)

func flash_lap_message(msg: String) -> void:
	if _lap_flash_label:
		_lap_flash_label.text        = msg
		_lap_flash_timer             = 2.2
		_lap_flash_label.modulate.a  = 0.0
		_lap_flash_label.scale       = Vector2(1.5, 1.5)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_lap_flash_label, "scale",      Vector2(1.0, 1.0), 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(_lap_flash_label, "modulate:a", 1.0,               0.15)

func show_results(results: Array) -> void:
	if _results_panel == null:
		return
	_results_panel.visible = true
	for c in _results_panel.get_children():
		c.queue_free()

	# Title
	var title := Label.new()
	title.text     = "RACE RESULTS"
	title.position = Vector2(0, 22)
	title.size     = Vector2(_results_panel.size.x, 52)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", NEON_CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_panel.add_child(title)

	# Divider
	var div := ColorRect.new()
	div.color    = Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.5)
	div.position = Vector2(30, 72)
	div.size     = Vector2(_results_panel.size.x - 60, 2)
	_results_panel.add_child(div)

	# Column headers
	var hdr := Label.new()
	hdr.text     = "POS   PILOT              TIME         BEST LAP"
	hdr.position = Vector2(30, 76)
	hdr.size     = Vector2(_results_panel.size.x - 60, 22)
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.35, 0.55, 0.82))
	_results_panel.add_child(hdr)

	for i in results.size():
		var r:      Dictionary = results[i]
		var is_p:   bool       = r.get("is_player", false)
		var pos_n:  int        = r.get("position", i + 1)
		var medal:  String     = "  " if pos_n > 3 else (["1ST", "2ND", "3RD"][pos_n - 1] + " ")
		var best_l: float      = r.get("best_lap", INF)
		var best_s: String     = GameManager.format_time(best_l) if best_l < INF else "--:--.---"

		var row := Label.new()
		row.text = "%s  %-18s  %s   %s" % [
			medal,
			r.get("name", "Vehicle"),
			GameManager.format_time(r.get("time", 0.0)),
			best_s
		]
		row.position = Vector2(30, 102 + i * 36)
		row.size     = Vector2(_results_panel.size.x - 60, 30)
		row.add_theme_font_size_override("font_size", 18)
		var col := NEON_GOLD if is_p else (NEON_CYAN if pos_n <= 3 else Color(0.72, 0.78, 0.88))
		row.add_theme_color_override("font_color", col)
		_results_panel.add_child(row)

	# Buttons
	var btn_menu := Button.new()
	btn_menu.text     = "MAIN MENU"
	btn_menu.position = Vector2(_results_panel.size.x * 0.5 - 230, _results_panel.size.y - 68)
	btn_menu.size     = Vector2(200, 48)
	btn_menu.pressed.connect(GameManager.return_to_menu)
	_results_panel.add_child(btn_menu)

	var btn_again := Button.new()
	btn_again.text     = "RACE AGAIN"
	btn_again.position = Vector2(_results_panel.size.x * 0.5 + 30, _results_panel.size.y - 68)
	btn_again.size     = Vector2(200, 48)
	btn_again.pressed.connect(GameManager.start_race)
	_results_panel.add_child(btn_again)

# ─── Helpers ───────────────────────────────────────────────────────────────────
func _make_panel(parent: Control, size: Vector2, offset: Vector2, corner: int) -> Panel:
	var p := Panel.new()
	p.size = size
	match corner:
		CORNER_TOP_LEFT:
			p.position = offset
		CORNER_TOP_RIGHT:
			p.anchor_left  = 1.0; p.anchor_right = 1.0
			p.position     = Vector2(-size.x + offset.x, offset.y)
		CORNER_BOTTOM_LEFT:
			p.anchor_top   = 1.0; p.anchor_bottom = 1.0
			p.position     = Vector2(offset.x, offset.y)
		CORNER_BOTTOM_RIGHT:
			p.anchor_left  = 1.0; p.anchor_right  = 1.0
			p.anchor_top   = 1.0; p.anchor_bottom = 1.0
			p.position     = Vector2(-size.x + offset.x, offset.y)
	_style_panel_sharp(p, PANEL_BG, PANEL_BORDER, 1)
	parent.add_child(p)
	return p

func _style_panel_sharp(p: Panel, bg: Color, border: Color, border_w: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color            = bg
	sb.border_color        = border
	sb.border_width_left   = border_w
	sb.border_width_right  = border_w
	sb.border_width_top    = border_w
	sb.border_width_bottom = border_w
	# Sharp corners — no rounding for angular retro look
	sb.corner_radius_top_left     = 0
	sb.corner_radius_top_right    = 0
	sb.corner_radius_bottom_left  = 0
	sb.corner_radius_bottom_right = 0
	p.add_theme_stylebox_override("panel", sb)

# ─── Minimap Panel ──────────────────────────────────────────────────────────────
func _build_minimap_panel(root: Control) -> void:
	_minimap = _MiniMapPanel.new()
	_minimap.size          = _MiniMapPanel.MAP_SIZE
	_minimap.anchor_top    = 1.0
	_minimap.anchor_bottom = 1.0
	_minimap.position      = Vector2(18, -375)   # Bottom-left, above status bars
	_minimap.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(_minimap)

# ─── Screen-Space Effects ───────────────────────────────────────────────────────
func _build_vignette(root: Control) -> void:
	_vignette = ColorRect.new()
	_vignette.anchor_right  = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.color         = Color(0.01, 0.03, 0.14, 0.0)
	_vignette.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)

	_boost_overlay = ColorRect.new()
	_boost_overlay.anchor_right  = 1.0
	_boost_overlay.anchor_bottom = 1.0
	_boost_overlay.color         = Color(0.28, 0.68, 1.0, 0.0)
	_boost_overlay.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(_boost_overlay)

func _build_speedlines(root: Control) -> void:
	for i in 14:
		var line := ColorRect.new()
		var width := randf_range(55.0, 210.0)
		line.size         = Vector2(width, randf_range(0.7, 2.2))
		line.position     = Vector2(randf_range(0.0, 1920.0), randf_range(55.0, 990.0))
		line.color        = Color(0.45, 0.75, 1.0, 0.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(line)
		_speedlines.append(line)

# ─── Best Lap Panel ─────────────────────────────────────────────────────────────
func _build_best_lap_panel(root: Control) -> void:
	var panel := _make_panel(root, Vector2(200, 62), Vector2(18, 18), CORNER_TOP_LEFT)

	var bar := ColorRect.new()
	bar.color    = NEON_GOLD
	bar.position = Vector2(0, 0)
	bar.size     = Vector2(200, 2)
	panel.add_child(bar)

	var hdr := Label.new()
	hdr.text     = "BEST LAP"
	hdr.position = Vector2(10, 6)
	hdr.size     = Vector2(180, 18)
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", Color(0.35, 0.60, 0.85))
	panel.add_child(hdr)

	_best_lap_label = Label.new()
	_best_lap_label.text     = "--:--.---"
	_best_lap_label.position = Vector2(6, 24)
	_best_lap_label.size     = Vector2(188, 32)
	_best_lap_label.add_theme_font_size_override("font_size", 22)
	_best_lap_label.add_theme_color_override("font_color", NEON_GOLD)
	_best_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_best_lap_label)

## Delta time panel: shows current lap time vs best lap. Green = ahead, red = behind.
## Appears below the BEST LAP panel (top-left), only visible once a best lap exists.
func _build_delta_panel(root: Control) -> void:
	_delta_panel = _make_panel(root, Vector2(200, 42), Vector2(18, 84), CORNER_TOP_LEFT)
	_delta_panel.visible = false  # Hidden until first best lap is set

	var bar := ColorRect.new()
	bar.color    = NEON_GREEN
	bar.position = Vector2(0, 0)
	bar.size     = Vector2(200, 2)
	_delta_panel.add_child(bar)

	var hdr := Label.new()
	hdr.text     = "DELTA"
	hdr.position = Vector2(10, 4)
	hdr.size     = Vector2(80, 16)
	hdr.add_theme_font_size_override("font_size", 10)
	hdr.add_theme_color_override("font_color", Color(0.35, 0.60, 0.85))
	_delta_panel.add_child(hdr)

	_delta_label = Label.new()
	_delta_label.text     = "+0.000"
	_delta_label.position = Vector2(6, 18)
	_delta_label.size     = Vector2(188, 22)
	_delta_label.add_theme_font_size_override("font_size", 18)
	_delta_label.add_theme_color_override("font_color", NEON_GREEN)
	_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delta_panel.add_child(_delta_label)

# ─── Pause Overlay ──────────────────────────────────────────────────────────────
func _build_fps_counter(root: Control) -> void:
	_fps_label = Label.new()
	_fps_label.anchor_left  = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.position     = Vector2(-110, 8)
	_fps_label.size         = Vector2(100, 24)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9, 0.7))
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fps_label)

func _build_pause_overlay(root: Control) -> void:
	_pause_overlay = Panel.new()
	_pause_overlay.anchor_right  = 1.0
	_pause_overlay.anchor_bottom = 1.0
	_pause_overlay.visible       = false
	_pause_overlay.mouse_filter  = Control.MOUSE_FILTER_STOP
	_style_panel_sharp(_pause_overlay, Color(0.0, 0.02, 0.06, 0.76), PANEL_BORDER, 0)

	# Scroll container for all pause content
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5; scroll.anchor_right = 0.5
	scroll.anchor_top = 0.0; scroll.anchor_bottom = 1.0
	scroll.offset_left = -260; scroll.offset_right = 260
	scroll.offset_top = 20; scroll.offset_bottom = -20
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pause_overlay.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(520, 0)
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# Title
	var lbl := Label.new()
	lbl.text = "PAUSED"
	lbl.custom_minimum_size = Vector2(520, 80)
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", NEON_CYAN)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	# ── AUDIO ──
	_add_pause_section("AUDIO", vbox)
	_build_pause_vol_slider("MASTER", AudioManager.db_to_percent(AudioManager.master_volume_db), vbox,
		func(v: float): AudioManager.set_master_volume(AudioManager.percent_to_db(v)); AudioManager.save_settings())
	_build_pause_vol_slider("MUSIC", AudioManager.db_to_percent(AudioManager.music_volume_db), vbox,
		func(v: float): AudioManager.set_music_volume(AudioManager.percent_to_db(v)); AudioManager.save_settings())
	_build_pause_vol_slider("SFX", AudioManager.db_to_percent(AudioManager.sfx_volume_db), vbox,
		func(v: float): AudioManager.set_sfx_volume(AudioManager.percent_to_db(v)); AudioManager.save_settings())

	# Music timeline scrubber
	_build_pause_music_scrubber(vbox)

	# ── CAMERA ──
	_add_pause_section("CAMERA", vbox)
	var cs := CameraSettings
	_add_pause_cam_slider("LATERAL SLIDE",       "lateral_base",        0.0, 10.0, 0.1, cs.lateral_base, vbox)
	_add_pause_cam_slider("LATERAL SPEED SCALE", "lateral_speed_scale", 0.0, 20.0, 0.1, cs.lateral_speed_scale, vbox)
	_add_pause_cam_slider("SLIDE OUT SPEED",     "lateral_out_rate",    0.1, 5.0,  0.1, cs.lateral_out_rate, vbox)
	_add_pause_cam_slider("SLIDE RETURN SPEED",  "lateral_return_rate", 0.1, 8.0,  0.1, cs.lateral_return_rate, vbox)
	_add_pause_cam_slider("TILT DEADZONE",       "tilt_deadzone",       0.0, 1.0,  0.05, cs.tilt_deadzone, vbox)
	_add_pause_cam_slider("TILT AMOUNT",         "tilt_base",           0.0, 0.5,  0.01, cs.tilt_base, vbox)
	_add_pause_cam_slider("TILT SPEED SCALE",    "tilt_speed_scale",    0.0, 1.0,  0.01, cs.tilt_speed_scale, vbox)
	_add_pause_cam_slider("TILT SMOOTHNESS",     "tilt_rate",           0.1, 3.0,  0.1, cs.tilt_rate, vbox)
	_add_pause_cam_slider("YAW FOLLOW",          "yaw_base",            0.0, 0.2,  0.005, cs.yaw_base, vbox)
	_add_pause_cam_slider("YAW SPEED SCALE",     "yaw_speed_scale",     0.0, 0.3,  0.005, cs.yaw_speed_scale, vbox)
	_add_pause_cam_slider("YAW SMOOTHNESS",      "yaw_rate",            0.1, 5.0,  0.1, cs.yaw_rate, vbox)
	_add_pause_cam_slider("BASE FOV",            "fov_base",            60.0, 110.0, 1.0, cs.fov_base, vbox)
	_add_pause_cam_slider("FOV SPEED SCALE",     "fov_speed_scale",     0.0, 40.0, 1.0, cs.fov_speed_scale, vbox)
	_add_pause_cam_slider("FOV BOOST",           "fov_boost",           0.0, 30.0, 1.0, cs.fov_boost, vbox)
	_add_pause_cam_slider("DISTANCE",            "distance_base",       2.0, 15.0, 0.1, cs.distance_base, vbox)
	_add_pause_cam_slider("DISTANCE SPEED SCALE","distance_speed_scale",0.0, 5.0,  0.1, cs.distance_speed_scale, vbox)
	_add_pause_cam_slider("HEIGHT",              "height_base",         0.5, 4.0,  0.1, cs.height_base, vbox)
	_add_pause_cam_slider("PITCH",               "pitch_base",         -40.0, 0.0, 1.0, cs.pitch_base, vbox)
	_add_pause_cam_slider("PITCH SPEED SCALE",   "pitch_speed_scale",   0.0, 25.0, 0.5, cs.pitch_speed_scale, vbox)
	_add_pause_cam_slider("BLUR STRENGTH",       "blur_strength",       0.0, 1.0,  0.05, cs.blur_strength, vbox)
	_add_pause_cam_slider("BLUR SPEED REF",      "blur_speed_ref",      50.0, 300.0, 5.0, cs.blur_speed_ref, vbox)

	# ── Buttons ──
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var btn_box := HBoxContainer.new()
	btn_box.custom_minimum_size = Vector2(520, 52)
	btn_box.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_box)

	var resume_btn := _make_pause_btn_inline("RESUME", NEON_CYAN)
	resume_btn.pressed.connect(GameManager.toggle_pause)
	btn_box.add_child(resume_btn)

	var reset_btn := _make_pause_btn_inline("RESET CAM", Color(0.88, 0.55, 0.1))
	reset_btn.pressed.connect(func(): CameraSettings.reset_defaults())
	btn_box.add_child(reset_btn)

	var restart_btn := _make_pause_btn_inline("RESTART", Color(0.9, 0.65, 0.1))
	restart_btn.pressed.connect(GameManager.start_race)
	btn_box.add_child(restart_btn)

	var menu_btn := _make_pause_btn_inline("MENU", Color(0.85, 0.25, 0.25))
	menu_btn.pressed.connect(GameManager.return_to_menu)
	btn_box.add_child(menu_btn)

	CameraSettings.settings_reset.connect(_refresh_pause_cam_sliders)
	root.add_child(_pause_overlay)

func _build_pause_volume_row(title: String, initial_percent: float, offset: Vector2,
		changed_cb: Callable) -> void:
	var hdr := Label.new()
	hdr.text              = title
	hdr.anchor_left       = 0.5
	hdr.anchor_right      = 0.5
	hdr.anchor_top        = 0.5
	hdr.anchor_bottom     = 0.5
	hdr.position          = offset
	hdr.size              = Vector2(80, 24)
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.42, 0.65, 0.90))
	_pause_overlay.add_child(hdr)

	var slider := HSlider.new()
	slider.anchor_left    = 0.5
	slider.anchor_right   = 0.5
	slider.anchor_top     = 0.5
	slider.anchor_bottom  = 0.5
	slider.position       = offset + Vector2(85, 0)
	slider.size           = Vector2(220, 24)
	slider.min_value      = 0
	slider.max_value      = 100
	slider.step           = 1
	slider.value          = initial_percent
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.28, 0.82, 1.0)
	grabber.corner_radius_top_left = 0; grabber.corner_radius_top_right = 0
	grabber.corner_radius_bottom_left = 0; grabber.corner_radius_bottom_right = 0
	slider.add_theme_stylebox_override("grabber_area", grabber)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.22)
	bg.corner_radius_top_left = 0; bg.corner_radius_top_right = 0
	bg.corner_radius_bottom_left = 0; bg.corner_radius_bottom_right = 0
	slider.add_theme_stylebox_override("slider", bg)
	_pause_overlay.add_child(slider)

	var pct := Label.new()
	pct.text              = "%d%%" % int(initial_percent)
	pct.anchor_left       = 0.5
	pct.anchor_right      = 0.5
	pct.anchor_top        = 0.5
	pct.anchor_bottom     = 0.5
	pct.position          = offset + Vector2(310, 0)
	pct.size              = Vector2(50, 24)
	pct.add_theme_font_size_override("font_size", 14)
	pct.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	_pause_overlay.add_child(pct)

	slider.value_changed.connect(func(v: float):
		changed_cb.call(v)
		pct.text = "%d%%" % int(v))

func _make_pause_button(text: String, color: Color, offset: Vector2) -> Button:
	var btn := Button.new()
	btn.text              = text
	btn.anchor_left       = 0.5
	btn.anchor_right      = 0.5
	btn.anchor_top        = 0.5
	btn.anchor_bottom     = 0.5
	btn.position          = offset
	btn.size              = Vector2(250, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color              = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.90)
	sb.border_color          = color * 0.85
	sb.border_width_left     = 2;  sb.border_width_right  = 2
	sb.border_width_top      = 2;  sb.border_width_bottom = 2
	sb.corner_radius_top_left = 0; sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0; sb.corner_radius_bottom_right = 0
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color    = Color(color.r * 0.28, color.g * 0.28, color.b * 0.28, 0.95)
	sb_h.border_color = color
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 22)
	return btn

# ─── Pause Overlay Helpers (VBox layout) ─────────────────────────────────────────

func _add_pause_section(title_text: String, parent: Control) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.custom_minimum_size = Vector2(520, 30)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", NEON_CYAN)
	parent.add_child(lbl)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(440, 1)
	line.color = Color(0.22, 0.62, 1.0, 0.5)
	parent.add_child(line)

func _build_pause_vol_slider(title_text: String, initial_percent: float,
		parent: Control, changed_cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(520, 28)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.custom_minimum_size = Vector2(160, 24)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.42, 0.65, 0.90))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(240, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = initial_percent
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.28, 0.82, 1.0)
	grabber.corner_radius_top_left = 0; grabber.corner_radius_top_right = 0
	grabber.corner_radius_bottom_left = 0; grabber.corner_radius_bottom_right = 0
	slider.add_theme_stylebox_override("grabber_area", grabber)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.12, 0.22)
	bg_sb.corner_radius_top_left = 0; bg_sb.corner_radius_top_right = 0
	bg_sb.corner_radius_bottom_left = 0; bg_sb.corner_radius_bottom_right = 0
	slider.add_theme_stylebox_override("slider", bg_sb)
	row.add_child(slider)

	var pct := Label.new()
	pct.text = "%d%%" % int(initial_percent)
	pct.custom_minimum_size = Vector2(60, 24)
	pct.add_theme_font_size_override("font_size", 13)
	pct.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)

	slider.value_changed.connect(func(v: float):
		changed_cb.call(v)
		pct.text = "%d%%" % int(v))

func _add_pause_cam_slider(title_text: String, setting_key: String,
		min_val: float, max_val: float, step_val: float, initial: float,
		parent: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(520, 28)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.custom_minimum_size = Vector2(180, 24)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.42, 0.65, 0.90))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(240, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.28, 0.82, 1.0)
	grabber.corner_radius_top_left = 0; grabber.corner_radius_top_right = 0
	grabber.corner_radius_bottom_left = 0; grabber.corner_radius_bottom_right = 0
	slider.add_theme_stylebox_override("grabber_area", grabber)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.12, 0.22)
	bg_sb.corner_radius_top_left = 0; bg_sb.corner_radius_top_right = 0
	bg_sb.corner_radius_bottom_left = 0; bg_sb.corner_radius_bottom_right = 0
	slider.add_theme_stylebox_override("slider", bg_sb)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(60, 24)
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.text = _fmt_pause_cam_val(initial, step_val)
	row.add_child(val_lbl)

	_pause_cam_sliders[setting_key] = { "slider": slider, "label": val_lbl, "step": step_val }

	slider.value_changed.connect(func(value: float) -> void:
		CameraSettings.set(setting_key, value)
		val_lbl.text = _fmt_pause_cam_val(value, step_val)
		CameraSettings.save_settings())

func _fmt_pause_cam_val(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(value))
	elif step >= 0.1:
		return "%.1f" % value
	else:
		return "%.2f" % value

func _refresh_pause_cam_sliders() -> void:
	for key in _pause_cam_sliders:
		var entry: Dictionary = _pause_cam_sliders[key]
		var slider: HSlider = entry["slider"]
		var label: Label = entry["label"]
		var step: float = entry["step"]
		var val: float = CameraSettings.get(key)
		slider.value = val
		label.text = _fmt_pause_cam_val(val, step)

func _build_pause_music_scrubber(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(520, 28)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "TRACK"
	lbl.custom_minimum_size = Vector2(160, 24)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.42, 0.65, 0.90))
	row.add_child(lbl)

	_pause_music_slider = HSlider.new()
	_pause_music_slider.custom_minimum_size = Vector2(240, 20)
	_pause_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_music_slider.min_value = 0.0
	_pause_music_slider.max_value = 1.0
	_pause_music_slider.step = 0.001
	var grab_sb := StyleBoxFlat.new()
	grab_sb.bg_color = Color(0.28, 0.82, 1.0)
	grab_sb.corner_radius_top_left = 0; grab_sb.corner_radius_top_right = 0
	grab_sb.corner_radius_bottom_left = 0; grab_sb.corner_radius_bottom_right = 0
	_pause_music_slider.add_theme_stylebox_override("grabber_area", grab_sb)
	_pause_music_slider.add_theme_stylebox_override("grabber_area_highlight", grab_sb)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.12, 0.22)
	bg_sb.corner_radius_top_left = 0; bg_sb.corner_radius_top_right = 0
	bg_sb.corner_radius_bottom_left = 0; bg_sb.corner_radius_bottom_right = 0
	_pause_music_slider.add_theme_stylebox_override("slider", bg_sb)
	_pause_music_slider.drag_started.connect(func(): _pause_music_dragging = true)
	_pause_music_slider.drag_ended.connect(func(changed: bool):
		_pause_music_dragging = false
		if changed:
			var length := AudioManager.get_music_length()
			if length > 0.0:
				AudioManager.seek_music(_pause_music_slider.value * length)
	)
	row.add_child(_pause_music_slider)

	_pause_music_time = Label.new()
	_pause_music_time.text = "0:00 / 0:00"
	_pause_music_time.custom_minimum_size = Vector2(90, 24)
	_pause_music_time.add_theme_font_size_override("font_size", 13)
	_pause_music_time.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	_pause_music_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_pause_music_time)

func _make_pause_btn_inline(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.90)
	sb.border_color = color * 0.85
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.corner_radius_top_left = 0; sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0; sb.corner_radius_bottom_right = 0
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(color.r * 0.28, color.g * 0.28, color.b * 0.28, 0.95)
	sb_h.border_color = color
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)
	return btn

# ─── Public: Best Lap & Boost ───────────────────────────────────────────────────
func update_best_lap(lap_time: float) -> void:
	if _best_lap_label:
		_best_lap_label.text = GameManager.format_time(lap_time)
		# Brief white flash to celebrate new personal best
		_best_lap_label.add_theme_color_override("font_color", Color.WHITE)
		get_tree().create_timer(0.55).timeout.connect(
			func(): if is_instance_valid(_best_lap_label):
				_best_lap_label.add_theme_color_override("font_color", NEON_GOLD))
	# Show the delta panel now that we have a reference lap
	if _delta_panel:
		_delta_panel.visible = true
	flash_lap_message("BEST LAP!")

## Delta vs best lap. Positive = currently slower than best, negative = ahead.
func update_lap_delta(delta_sec: float) -> void:
	if not _delta_label or not _delta_panel or not _delta_panel.visible:
		return
	var sign_chr := "+" if delta_sec >= 0.0 else "-"
	var abs_sec  := absf(delta_sec)
	_delta_label.text = "%s%s" % [sign_chr, GameManager.format_time(abs_sec)]
	# Green = faster than best, red = slower
	var col := NEON_RED if delta_sec > 0.0 else NEON_GREEN
	_delta_label.add_theme_color_override("font_color", col)

func show_boost_flash() -> void:
	_boost_flash_t = 1.0

## Flash a red overlay on barrier/collision damage. Intensity scales with hit strength.
func set_minimap_data(waypoints: Array, vehicles: Array) -> void:
	if _minimap:
		_minimap.set_data(waypoints, vehicles)

func toggle_pause() -> void:
	if _results_panel and _results_panel.visible:
		return
	GameManager.toggle_pause()
