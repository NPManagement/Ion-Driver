## MainMenu — Retro-futuristic main menu UI overlay.
extends Control

var _title_label: Label
var _subtitle: Label
var _btn_start: Button
var _btn_options: Button
var _btn_quit: Button
var _options_panel: Panel
var _laps_label: Label
var _master_slider: HSlider
var _master_label: Label
var _music_slider: HSlider
var _music_label: Label
var _sfx_slider: HSlider
var _sfx_label: Label
var _color_swatches: Array = []
var _cam_sliders: Dictionary = {}   # key → { "slider": HSlider, "label": Label }
var _side_panel: ColorRect
var _menu_content: Control          # Holds title + subtitle + lines + buttons
var _collapse_btn: Button
var _menu_collapsed: bool = false
var _music_scrub_slider: HSlider
var _music_time_label: Label
var _music_scrub_dragging: bool = false
var _track_select_panel: Panel

const COLOR_OPTIONS: Array = [
	Color(0.10, 0.45, 0.95),   # Cobalt blue (default)
	Color(0.85, 0.12, 0.12),   # Racing red
	Color(0.12, 0.88, 0.28),   # Neon green
	Color(0.95, 0.68, 0.05),   # Gold
	Color(0.70, 0.12, 0.96),   # Purple
	Color(0.95, 0.38, 0.08),   # Orange
	Color(0.12, 0.92, 0.88),   # Cyan
]
var _anim_time: float = 0.0

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_side_panel()
	_build_title()
	_build_menu()
	_build_options_panel()
	_play_menu_music()

# ─── Side Panel ────────────────────────────────────────────────────────────────
func _build_side_panel() -> void:
	_side_panel = ColorRect.new()
	_side_panel.anchor_left   = 0.0
	_side_panel.anchor_right  = 0.0
	_side_panel.anchor_top    = 0.0
	_side_panel.anchor_bottom = 1.0
	_side_panel.offset_left   = 0
	_side_panel.offset_right  = 520
	_side_panel.offset_top    = 0
	_side_panel.offset_bottom = 0
	_side_panel.color         = Color(0.004, 0.008, 0.018, 0.82)
	_side_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_side_panel)

	# Container for all menu content (title, buttons, etc.)
	_menu_content = Control.new()
	_menu_content.anchor_right  = 1.0
	_menu_content.anchor_bottom = 1.0
	_menu_content.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_content)

	# Collapse/expand toggle button on the panel edge
	_collapse_btn = Button.new()
	_collapse_btn.text = "<"
	_collapse_btn.anchor_left   = 0.0
	_collapse_btn.anchor_right  = 0.0
	_collapse_btn.anchor_top    = 0.5
	_collapse_btn.anchor_bottom = 0.5
	_collapse_btn.position      = Vector2(520, -24)
	_collapse_btn.size          = Vector2(32, 48)
	_collapse_btn.add_theme_font_size_override("font_size", 20)
	_collapse_btn.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	_collapse_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.01, 0.02, 0.04, 0.9)
	btn_sb.border_color = Color(0.22, 0.62, 1.0, 0.6)
	btn_sb.border_width_left = 0; btn_sb.border_width_right = 1
	btn_sb.border_width_top = 1; btn_sb.border_width_bottom = 1
	btn_sb.corner_radius_top_left = 0; btn_sb.corner_radius_top_right = 0
	btn_sb.corner_radius_bottom_left = 0; btn_sb.corner_radius_bottom_right = 0
	_collapse_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hover := btn_sb.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.04, 0.08, 0.16, 0.95)
	_collapse_btn.add_theme_stylebox_override("hover", btn_hover)
	_collapse_btn.pressed.connect(_toggle_collapse)
	add_child(_collapse_btn)

func _play_menu_music() -> void:
	# Load and play menu music
	var music_stream := load("res://audio/The Hidden Gems of Ambient Drum and Bass - Vic^ (128k) (mp3cut.net).mp3")
	if music_stream:
		AudioManager.play_music(music_stream, 1.0)

# ─── Title ─────────────────────────────────────────────────────────────────────
func _build_title() -> void:
	# Large angular title
	_title_label = Label.new()
	_title_label.text          = "ION  DRIVER"
	_title_label.anchor_left   = 0.0
	_title_label.anchor_right  = 0.0
	_title_label.position      = Vector2(40, 80)
	_title_label.size          = Vector2(480, 110)
	_title_label.add_theme_font_size_override("font_size", 78)
	_title_label.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_content.add_child(_title_label)

	# Subtitle
	_subtitle = Label.new()
	_subtitle.text         = "ANTI-GRAVITY  ·  HIGH-SPEED  ·  CIRCUIT RACING"
	_subtitle.anchor_left  = 0.0
	_subtitle.anchor_right = 0.0
	_subtitle.position     = Vector2(44, 192)
	_subtitle.size         = Vector2(440, 28)
	_subtitle.add_theme_font_size_override("font_size", 14)
	_subtitle.add_theme_color_override("font_color", Color(0.38, 0.60, 0.85))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_content.add_child(_subtitle)

	# Sharp accent line under title
	var line := ColorRect.new()
	line.anchor_left  = 0.0
	line.anchor_right = 0.0
	line.position     = Vector2(40, 228)
	line.size         = Vector2(440, 2)
	line.color        = Color(0.22, 0.62, 1.0, 0.80)
	_menu_content.add_child(line)

	# Thin secondary line
	var line2 := ColorRect.new()
	line2.anchor_left  = 0.0
	line2.anchor_right = 0.0
	line2.position     = Vector2(40, 234)
	line2.size         = Vector2(340, 1)
	line2.color        = Color(0.22, 0.62, 1.0, 0.30)
	_menu_content.add_child(line2)

# ─── Menu Buttons ──────────────────────────────────────────────────────────────
func _build_menu() -> void:
	var vbox := VBoxContainer.new()
	vbox.anchor_left   = 0.0
	vbox.anchor_right  = 0.0
	vbox.anchor_top    = 0.5
	vbox.anchor_bottom = 0.5
	vbox.position      = Vector2(40, -80)
	vbox.size          = Vector2(360, 220)
	vbox.add_theme_constant_override("separation", 16)
	_menu_content.add_child(vbox)

	_btn_start   = _make_button("RACE NOW",  Color(0.22, 0.78, 1.0), true)
	_btn_options = _make_button("OPTIONS",   Color(0.45, 0.58, 0.85), false)
	_btn_quit    = _make_button("QUIT",      Color(0.88, 0.25, 0.25), false)

	vbox.add_child(_btn_start)
	vbox.add_child(_btn_options)
	vbox.add_child(_btn_quit)

	_btn_start.pressed.connect(_show_track_select)
	_btn_options.pressed.connect(_toggle_options)
	_btn_quit.pressed.connect(get_tree().quit)

func _make_button(text: String, color: Color, primary: bool) -> Button:
	var btn := Button.new()
	btn.text                = text
	btn.custom_minimum_size = Vector2(360, 60)

	var normal := StyleBoxFlat.new()
	var bg_alpha := 0.16 if primary else 0.08
	normal.bg_color              = Color(color.r * bg_alpha * 2, color.g * bg_alpha * 2, color.b * bg_alpha * 2, 0.90)
	normal.border_color          = color * (0.9 if primary else 0.55)
	normal.border_width_left     = 2 if primary else 1
	normal.border_width_right    = 2 if primary else 1
	normal.border_width_top      = 2 if primary else 1
	normal.border_width_bottom   = 2 if primary else 1
	# Sharp corners — retro angular look
	normal.corner_radius_top_left     = 0
	normal.corner_radius_top_right    = 0
	normal.corner_radius_bottom_left  = 0
	normal.corner_radius_bottom_right = 0
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color    = Color(color.r * 0.28, color.g * 0.28, color.b * 0.28, 0.95)
	hover.border_color = color
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color * 0.45
	btn.add_theme_stylebox_override("pressed", pressed)

	var font_size := 24 if primary else 20
	btn.add_theme_color_override("font_color",         color)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", font_size)

	return btn

# ─── Options Panel ─────────────────────────────────────────────────────────────
func _build_options_panel() -> void:
	# Full-screen overlay with 75% opacity background
	_options_panel = Panel.new()
	_options_panel.anchor_left   = 0.0
	_options_panel.anchor_right  = 1.0
	_options_panel.anchor_top    = 0.0
	_options_panel.anchor_bottom = 1.0
	_options_panel.offset_left   = 0
	_options_panel.offset_right  = 0
	_options_panel.offset_top    = 0
	_options_panel.offset_bottom = 0
	_options_panel.visible       = false

	var sb := StyleBoxFlat.new()
	sb.bg_color            = Color(0.02, 0.04, 0.09, 0.75)
	sb.border_color        = Color(0.20, 0.52, 0.92, 0.0)
	sb.border_width_left   = 0
	sb.border_width_right  = 0
	sb.border_width_top    = 0
	sb.border_width_bottom = 0
	_options_panel.add_theme_stylebox_override("panel", sb)
	add_child(_options_panel)

	# Scroll container — allows all options to fit
	var scroll := ScrollContainer.new()
	scroll.anchor_left   = 0.5
	scroll.anchor_right  = 0.5
	scroll.anchor_top    = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left   = -260
	scroll.offset_right  = 260
	scroll.offset_top    = 30
	scroll.offset_bottom = -30
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(520, 0)
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

	# ── Title ──
	var title := Label.new()
	title.text = "OPTIONS"
	title.custom_minimum_size = Vector2(520, 50)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var title_line := ColorRect.new()
	title_line.custom_minimum_size = Vector2(440, 2)
	title_line.color = Color(0.22, 0.62, 1.0, 0.80)
	content.add_child(title_line)

	# ── RACE SETTINGS ──
	_add_section_header("RACE", content)

	var laps_row := HBoxContainer.new()
	laps_row.custom_minimum_size = Vector2(520, 34)
	content.add_child(laps_row)
	var laps_lbl := Label.new()
	laps_lbl.text = "LAPS"
	laps_lbl.custom_minimum_size = Vector2(160, 30)
	laps_lbl.add_theme_font_size_override("font_size", 15)
	laps_lbl.add_theme_color_override("font_color", Color(0.42, 0.65, 0.90))
	laps_row.add_child(laps_lbl)
	var dec_btn := Button.new()
	dec_btn.text = "<"
	dec_btn.custom_minimum_size = Vector2(34, 30)
	dec_btn.pressed.connect(func(): GameManager.selected_laps = (GameManager.selected_laps - 1 + 4) % 4; _refresh_options())
	laps_row.add_child(dec_btn)
	_laps_label = Label.new()
	_laps_label.text = str(GameManager.get_lap_count())
	_laps_label.custom_minimum_size = Vector2(60, 30)
	_laps_label.add_theme_font_size_override("font_size", 16)
	_laps_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	_laps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	laps_row.add_child(_laps_label)
	var inc_btn := Button.new()
	inc_btn.text = ">"
	inc_btn.custom_minimum_size = Vector2(34, 30)
	inc_btn.pressed.connect(func(): GameManager.selected_laps = (GameManager.selected_laps + 1) % 4; _refresh_options())
	laps_row.add_child(inc_btn)

	# Ship color
	var color_hdr := Label.new()
	color_hdr.text = "SHIP COLOR"
	color_hdr.custom_minimum_size = Vector2(520, 28)
	color_hdr.add_theme_font_size_override("font_size", 15)
	color_hdr.add_theme_color_override("font_color", Color(0.42, 0.65, 0.90))
	content.add_child(color_hdr)

	var swatch_row := HBoxContainer.new()
	swatch_row.custom_minimum_size = Vector2(520, 36)
	swatch_row.add_theme_constant_override("separation", 4)
	content.add_child(swatch_row)
	for i in COLOR_OPTIONS.size():
		var col := COLOR_OPTIONS[i] as Color
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(32, 32)
		var swatch_sb := StyleBoxFlat.new()
		swatch_sb.bg_color = col
		swatch_sb.border_color = Color.WHITE if GameManager.selected_vehicle_color.is_equal_approx(col) else col * 1.3
		swatch_sb.border_width_left = 3; swatch_sb.border_width_right = 3
		swatch_sb.border_width_top = 3; swatch_sb.border_width_bottom = 3
		swatch_sb.corner_radius_top_left = 0; swatch_sb.corner_radius_top_right = 0
		swatch_sb.corner_radius_bottom_left = 0; swatch_sb.corner_radius_bottom_right = 0
		swatch.add_theme_stylebox_override("normal", swatch_sb)
		var sb_h := swatch_sb.duplicate() as StyleBoxFlat
		sb_h.border_color = Color.WHITE
		swatch.add_theme_stylebox_override("hover", sb_h)
		swatch.pressed.connect(_on_color_selected.bind(i))
		swatch_row.add_child(swatch)
		_color_swatches.append(swatch)

	# ── AUDIO ──
	_add_section_header("AUDIO", content)
	_build_volume_slider("MASTER VOLUME", AudioManager.db_to_percent(AudioManager.master_volume_db),
		content, func(s: HSlider, l: Label): _master_slider = s; _master_label = l,
		_on_master_volume_changed)
	_build_volume_slider("MUSIC VOLUME", AudioManager.db_to_percent(AudioManager.music_volume_db),
		content, func(s: HSlider, l: Label): _music_slider = s; _music_label = l,
		_on_music_volume_changed)
	_build_volume_slider("SFX VOLUME", AudioManager.db_to_percent(AudioManager.sfx_volume_db),
		content, func(s: HSlider, l: Label): _sfx_slider = s; _sfx_label = l,
		_on_sfx_volume_changed)

	# Music timeline scrubber
	var scrub_row := HBoxContainer.new()
	scrub_row.custom_minimum_size = Vector2(520, 28)
	scrub_row.add_theme_constant_override("separation", 8)
	content.add_child(scrub_row)

	var scrub_lbl := Label.new()
	scrub_lbl.text = "TRACK"
	scrub_lbl.custom_minimum_size = Vector2(180, 24)
	scrub_lbl.add_theme_font_size_override("font_size", 13)
	scrub_lbl.add_theme_color_override("font_color", Color(0.42, 0.65, 0.90))
	scrub_row.add_child(scrub_lbl)

	_music_scrub_slider = HSlider.new()
	_music_scrub_slider.custom_minimum_size = Vector2(240, 20)
	_music_scrub_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_scrub_slider.min_value = 0.0
	_music_scrub_slider.max_value = 1.0
	_music_scrub_slider.step = 0.001
	_music_scrub_slider.value = 0.0
	var scrub_grabber := StyleBoxFlat.new()
	scrub_grabber.bg_color = Color(0.28, 0.82, 1.0)
	scrub_grabber.corner_radius_top_left = 0; scrub_grabber.corner_radius_top_right = 0
	scrub_grabber.corner_radius_bottom_left = 0; scrub_grabber.corner_radius_bottom_right = 0
	_music_scrub_slider.add_theme_stylebox_override("grabber_area", scrub_grabber)
	_music_scrub_slider.add_theme_stylebox_override("grabber_area_highlight", scrub_grabber)
	var scrub_bg := StyleBoxFlat.new()
	scrub_bg.bg_color = Color(0.08, 0.12, 0.22)
	scrub_bg.corner_radius_top_left = 0; scrub_bg.corner_radius_top_right = 0
	scrub_bg.corner_radius_bottom_left = 0; scrub_bg.corner_radius_bottom_right = 0
	_music_scrub_slider.add_theme_stylebox_override("slider", scrub_bg)
	_music_scrub_slider.drag_started.connect(func(): _music_scrub_dragging = true)
	_music_scrub_slider.drag_ended.connect(_on_music_scrub_released)
	scrub_row.add_child(_music_scrub_slider)

	_music_time_label = Label.new()
	_music_time_label.text = "0:00 / 0:00"
	_music_time_label.custom_minimum_size = Vector2(90, 24)
	_music_time_label.add_theme_font_size_override("font_size", 13)
	_music_time_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	_music_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scrub_row.add_child(_music_time_label)

	# ── CAMERA ──
	_add_section_header("CAMERA", content)
	var cs := CameraSettings
	_add_cam_slider("LATERAL SLIDE",       "lateral_base",        0.0, 10.0, 0.1, cs.lateral_base, content)
	_add_cam_slider("LATERAL SPEED SCALE", "lateral_speed_scale", 0.0, 20.0, 0.1, cs.lateral_speed_scale, content)
	_add_cam_slider("SLIDE OUT SPEED",     "lateral_out_rate",    0.1, 5.0,  0.1, cs.lateral_out_rate, content)
	_add_cam_slider("SLIDE RETURN SPEED",  "lateral_return_rate", 0.1, 8.0,  0.1, cs.lateral_return_rate, content)
	_add_cam_slider("TILT DEADZONE",       "tilt_deadzone",       0.0, 1.0,  0.05, cs.tilt_deadzone, content)
	_add_cam_slider("TILT AMOUNT",         "tilt_base",           0.0, 0.5,  0.01, cs.tilt_base, content)
	_add_cam_slider("TILT SPEED SCALE",    "tilt_speed_scale",    0.0, 1.0,  0.01, cs.tilt_speed_scale, content)
	_add_cam_slider("TILT SMOOTHNESS",     "tilt_rate",           0.1, 3.0,  0.1, cs.tilt_rate, content)
	_add_cam_slider("YAW FOLLOW",          "yaw_base",            0.0, 0.2,  0.005, cs.yaw_base, content)
	_add_cam_slider("YAW SPEED SCALE",     "yaw_speed_scale",     0.0, 0.3,  0.005, cs.yaw_speed_scale, content)
	_add_cam_slider("YAW SMOOTHNESS",      "yaw_rate",            0.1, 5.0,  0.1, cs.yaw_rate, content)
	_add_cam_slider("BASE FOV",            "fov_base",            60.0, 110.0, 1.0, cs.fov_base, content)
	_add_cam_slider("FOV SPEED SCALE",     "fov_speed_scale",     0.0, 40.0, 1.0, cs.fov_speed_scale, content)
	_add_cam_slider("FOV BOOST",           "fov_boost",           0.0, 30.0, 1.0, cs.fov_boost, content)
	_add_cam_slider("DISTANCE",            "distance_base",       2.0, 15.0, 0.1, cs.distance_base, content)
	_add_cam_slider("DISTANCE SPEED SCALE","distance_speed_scale",0.0, 5.0,  0.1, cs.distance_speed_scale, content)
	_add_cam_slider("HEIGHT",              "height_base",         0.5, 4.0,  0.1, cs.height_base, content)
	_add_cam_slider("PITCH",               "pitch_base",         -40.0, 0.0, 1.0, cs.pitch_base, content)
	_add_cam_slider("PITCH SPEED SCALE",   "pitch_speed_scale",   0.0, 25.0, 0.5, cs.pitch_speed_scale, content)
	_add_cam_slider("BLUR STRENGTH",       "blur_strength",       0.0, 1.0,  0.05, cs.blur_strength, content)
	_add_cam_slider("BLUR SPEED REF",      "blur_speed_ref",      50.0, 300.0, 5.0, cs.blur_speed_ref, content)

	# ── Reset + Close ──
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	content.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.custom_minimum_size = Vector2(520, 52)
	btn_row.add_theme_constant_override("separation", 16)
	content.add_child(btn_row)

	var reset_btn := _make_button("RESET CAMERA", Color(0.88, 0.25, 0.25), false)
	reset_btn.custom_minimum_size = Vector2(200, 48)
	reset_btn.pressed.connect(_on_reset_camera)
	btn_row.add_child(reset_btn)

	var close_btn := _make_button("CLOSE", Color(0.22, 0.78, 1.0), false)
	close_btn.custom_minimum_size = Vector2(200, 48)
	close_btn.pressed.connect(_toggle_options)
	btn_row.add_child(close_btn)

	# Listen for resets to refresh sliders
	CameraSettings.settings_reset.connect(_refresh_cam_sliders)

func _add_section_header(title_text: String, parent: Control) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	parent.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.custom_minimum_size = Vector2(520, 32)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	parent.add_child(lbl)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(440, 1)
	line.color = Color(0.22, 0.62, 1.0, 0.5)
	parent.add_child(line)

func _add_cam_slider(title_text: String, setting_key: String,
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
	val_lbl.text = _fmt_cam_val(initial, step_val)
	row.add_child(val_lbl)

	_cam_sliders[setting_key] = { "slider": slider, "label": val_lbl, "step": step_val }

	slider.value_changed.connect(func(value: float) -> void:
		CameraSettings.set(setting_key, value)
		val_lbl.text = _fmt_cam_val(value, step_val)
		CameraSettings.save_settings()
	)

func _fmt_cam_val(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(value))
	elif step >= 0.1:
		return "%.1f" % value
	else:
		return "%.2f" % value

func _toggle_options() -> void:
	_options_panel.visible = not _options_panel.visible

func _on_reset_camera() -> void:
	CameraSettings.reset_defaults()

func _refresh_cam_sliders() -> void:
	for key in _cam_sliders:
		var entry: Dictionary = _cam_sliders[key]
		var slider: HSlider = entry["slider"]
		var label: Label = entry["label"]
		var step: float = entry["step"]
		var val: float = CameraSettings.get(key)
		slider.value = val
		label.text = _fmt_cam_val(val, step)

func _refresh_options() -> void:
	if _laps_label: _laps_label.text = str(GameManager.get_lap_count())
	if _master_slider: _master_slider.value = AudioManager.db_to_percent(AudioManager.master_volume_db)
	if _master_label: _master_label.text = "%d%%" % int(_master_slider.value)
	if _music_slider: _music_slider.value = AudioManager.db_to_percent(AudioManager.music_volume_db)
	if _music_label: _music_label.text = "%d%%" % int(_music_slider.value)
	if _sfx_slider: _sfx_slider.value = AudioManager.db_to_percent(AudioManager.sfx_volume_db)
	if _sfx_label: _sfx_label.text = "%d%%" % int(_sfx_slider.value)


func _build_volume_slider(title_text: String, initial_percent: float,
		parent: Control, ref_cb: Callable, changed_cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(520, 28)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var hdr := Label.new()
	hdr.text = title_text
	hdr.custom_minimum_size = Vector2(180, 24)
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.42, 0.65, 0.90))
	row.add_child(hdr)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(240, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = initial_percent
	slider.value_changed.connect(changed_cb)
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

	var lbl := Label.new()
	lbl.text = "%d%%" % int(initial_percent)
	lbl.custom_minimum_size = Vector2(60, 24)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lbl)

	ref_cb.call(slider, lbl)

func _on_master_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(AudioManager.percent_to_db(value))
	if _master_label: _master_label.text = "%d%%" % int(value)
	AudioManager.save_settings()

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(AudioManager.percent_to_db(value))
	if _music_label: _music_label.text = "%d%%" % int(value)
	AudioManager.save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(AudioManager.percent_to_db(value))
	if _sfx_label: _sfx_label.text = "%d%%" % int(value)
	AudioManager.save_settings()

func _on_music_scrub_released(value_changed: bool) -> void:
	_music_scrub_dragging = false
	if value_changed:
		var length := AudioManager.get_music_length()
		if length > 0.0:
			AudioManager.seek_music(_music_scrub_slider.value * length)

func _fmt_time(secs: float) -> String:
	var m := int(secs) / 60
	var s := int(secs) % 60
	return "%d:%02d" % [m, s]

func _on_color_selected(index: int) -> void:
	GameManager.selected_vehicle_color = COLOR_OPTIONS[index]
	# Update swatch borders to highlight selection
	for i in _color_swatches.size():
		var s := _color_swatches[i] as Button
		var col := COLOR_OPTIONS[i] as Color
		var sb  := StyleBoxFlat.new()
		sb.bg_color              = col
		sb.border_color          = Color.WHITE if i == index else col * 1.3
		sb.border_width_left     = 3
		sb.border_width_right    = 3
		sb.border_width_top      = 3
		sb.border_width_bottom   = 3
		sb.corner_radius_top_left     = 0
		sb.corner_radius_top_right    = 0
		sb.corner_radius_bottom_left  = 0
		sb.corner_radius_bottom_right = 0
		s.add_theme_stylebox_override("normal", sb)

# ─── Collapse ──────────────────────────────────────────────────────────────────
var _panel_slide: float = 0.0  # 0 = fully open, 1 = fully collapsed
const PANEL_WIDTH := 520.0
const COLLAPSE_SPEED := 6.0

func _toggle_collapse() -> void:
	_menu_collapsed = not _menu_collapsed
	_collapse_btn.text = ">" if _menu_collapsed else "<"

# ─── Animation ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_anim_time += delta

	# Smooth slide animation for collapse
	var target := 1.0 if _menu_collapsed else 0.0
	_panel_slide = move_toward(_panel_slide, target, delta * COLLAPSE_SPEED)
	var offset_x := -PANEL_WIDTH * _panel_slide
	if _side_panel:
		_side_panel.offset_left  = offset_x
		_side_panel.offset_right = PANEL_WIDTH + offset_x
	if _menu_content:
		_menu_content.position.x = offset_x
	if _collapse_btn:
		_collapse_btn.position.x = PANEL_WIDTH + offset_x

	# Update music scrubber position
	if _music_scrub_slider and not _music_scrub_dragging and AudioManager.is_music_playing():
		var length := AudioManager.get_music_length()
		if length > 0.0:
			var pos := AudioManager.get_music_position()
			_music_scrub_slider.value = pos / length
			if _music_time_label:
				_music_time_label.text = "%s / %s" % [_fmt_time(pos), _fmt_time(length)]

	# Title: neon glow pulse + subtle color shift
	if _title_label:
		var pulse := sin(_anim_time * 1.8) * 0.18 + 0.82
		_title_label.add_theme_color_override("font_color",
			Color(0.28 * pulse, 0.82 * pulse, 1.0 * pulse))

# ─── Track Selection ──────────────────────────────────────────────────────────
func _show_track_select() -> void:
	if _track_select_panel and is_instance_valid(_track_select_panel):
		_track_select_panel.visible = not _track_select_panel.visible
		return

	_track_select_panel = Panel.new()
	_track_select_panel.anchor_left   = 0.0
	_track_select_panel.anchor_right  = 1.0
	_track_select_panel.anchor_top    = 0.0
	_track_select_panel.anchor_bottom = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	_track_select_panel.add_theme_stylebox_override("panel", bg)
	add_child(_track_select_panel)

	var center := VBoxContainer.new()
	center.anchor_left   = 0.5
	center.anchor_right  = 0.5
	center.anchor_top    = 0.5
	center.anchor_bottom = 0.5
	center.offset_left   = -220
	center.offset_right  = 220
	center.offset_top    = -180
	center.offset_bottom = 180
	center.add_theme_constant_override("separation", 24)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_track_select_panel.add_child(center)

	var title := Label.new()
	title.text = "SELECT TRACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	center.add_child(title)

	var btn_night := _make_button("NIGHT CITY", Color(0.22, 0.78, 1.0), true)
	btn_night.pressed.connect(_select_track.bind(0))
	center.add_child(btn_night)

	var btn_test := _make_button("TEST", Color(0.95, 0.68, 0.05), true)
	btn_test.pressed.connect(_select_track.bind(1))
	center.add_child(btn_test)

	var btn_back := _make_button("BACK", Color(0.88, 0.25, 0.25), false)
	btn_back.pressed.connect(func(): _track_select_panel.visible = false)
	center.add_child(btn_back)

func _select_track(track_id: int) -> void:
	GameManager.selected_track = track_id
	if _track_select_panel:
		_track_select_panel.visible = false
	GameManager.start_race()
