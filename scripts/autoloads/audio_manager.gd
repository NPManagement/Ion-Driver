## AudioManager — Global audio singleton for music and SFX.
extends Node

# ─── Constants ─────────────────────────────────────────────────────────────────
const BUS_MASTER := "Master"
const BUS_MUSIC  := "Music"
const BUS_SFX    := "SFX"

const SETTINGS_PATH := "user://settings.cfg"
const VOL_MIN_DB := -40.0
const VOL_MAX_DB := 0.0

# ─── State ─────────────────────────────────────────────────────────────────────
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8
var _sfx_index: int = 0

var _music_tween: Tween
var music_volume_db: float = 0.0    # 0 = full volume, -40 = very quiet
var sfx_volume_db: float   = 0.0
var master_volume_db: float = 0.0

# ─── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_setup_players()
	load_settings()

func _setup_audio_buses() -> void:
	var bus_count := AudioServer.get_bus_count()
	# Add Music bus if not present
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus_count, BUS_MUSIC)
		AudioServer.set_bus_send(bus_count, BUS_MASTER)
		bus_count += 1
	# Add SFX bus if not present
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus_count, BUS_SFX)
		AudioServer.set_bus_send(bus_count, BUS_MASTER)

	_apply_volumes()

func _setup_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	_music_player.volume_db = 0.0  # Bus controls volume, player stays at 0
	add_child(_music_player)

	for i in _sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		p.volume_db = 0.0  # Bus controls volume, player stays at 0
		add_child(p)
		_sfx_pool.append(p)

# ─── Public API ────────────────────────────────────────────────────────────────
func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	if stream == null or _music_player == null:
		return
	# Kill any in-flight fade so it can't stomp this new playback
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_player.stream = stream
	_music_player.volume_db = -80.0  # Start silent
	_music_player.play()
	# Fade in to 0 dB (bus handles the actual volume level)
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", 0.0, fade_in)

func stop_music(fade_out: float = 1.0) -> void:
	if _music_player == null or not _music_player.playing:
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -80.0, fade_out)
	_music_tween.tween_callback(_music_player.stop)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player := _sfx_pool[_sfx_index % _sfx_pool_size]
	_sfx_index += 1
	player.stream = stream
	player.volume_db = volume_db  # Relative offset only; bus handles base volume
	player.pitch_scale = pitch
	player.play()

func get_music_position() -> float:
	if _music_player and _music_player.playing:
		return _music_player.get_playback_position()
	return 0.0

func get_music_length() -> float:
	if _music_player and _music_player.stream:
		return _music_player.stream.get_length()
	return 0.0

func seek_music(position: float) -> void:
	if _music_player and _music_player.playing:
		_music_player.seek(clampf(position, 0.0, get_music_length()))

func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing

func set_master_volume(value: float) -> void:
	master_volume_db = value
	_apply_volumes()

func set_music_volume(value: float) -> void:
	music_volume_db = value
	_apply_volumes()

func set_sfx_volume(value: float) -> void:
	sfx_volume_db = value
	_apply_volumes()

func _apply_volumes() -> void:
	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, master_volume_db)

	var music_idx := AudioServer.get_bus_index(BUS_MUSIC)
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, music_volume_db)

	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, sfx_volume_db)

# ─── Helpers ───────────────────────────────────────────────────────────────────
## Convert a 0-100 percentage to dB in our range.
static func percent_to_db(percent: float) -> float:
	return (percent / 100.0) * (VOL_MAX_DB - VOL_MIN_DB) + VOL_MIN_DB

## Convert dB to a 0-100 percentage.
static func db_to_percent(db: float) -> float:
	return ((db - VOL_MIN_DB) / (VOL_MAX_DB - VOL_MIN_DB)) * 100.0

# ─── Persistence ───────────────────────────────────────────────────────────────
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume_db", master_volume_db)
	cfg.set_value("audio", "music_volume_db", music_volume_db)
	cfg.set_value("audio", "sfx_volume_db", sfx_volume_db)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return  # No saved settings yet — use defaults
	master_volume_db = cfg.get_value("audio", "master_volume_db", 0.0)
	music_volume_db  = cfg.get_value("audio", "music_volume_db", 0.0)
	sfx_volume_db    = cfg.get_value("audio", "sfx_volume_db", 0.0)
	_apply_volumes()
