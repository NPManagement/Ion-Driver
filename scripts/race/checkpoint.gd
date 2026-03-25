## Checkpoint — Area3D gate vehicles must pass through in sequence.
## Visually dramatic: full-width arch with pulsing light.
extends Area3D
class_name Checkpoint

signal checkpoint_passed(vehicle: IonVehicle, index: int)

@export var checkpoint_index: int = 0
@export var is_finish_line: bool  = false

var _gate_light: OmniLight3D
var _anim_t: float = 0.0

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask  = 2
	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	# Scale checkpoint to track width
	var track_w := 80.0 if GameManager.selected_track != 0 else 320.0
	var half_w := track_w * 0.5

	# Collision gate spans full track width with a bit of margin
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(track_w + 80.0, 40.0, 30.0)
	col.shape = box
	add_child(col)

	# Side posts at track edges
	_add_post(Vector3(-half_w, 5.0, 0))
	_add_post(Vector3( half_w, 5.0, 0))

	# Top bar spanning track
	var bar := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = Vector3(track_w, 0.5, 0.5)
	bar.mesh             = bm
	bar.position         = Vector3(0, 10.0, 0)
	bar.material_override = _gate_material(1.0)
	add_child(bar)

	# Lower horizontal bar
	var bar2 := MeshInstance3D.new()
	var bm2  := BoxMesh.new()
	bm2.size = Vector3(track_w, 0.25, 0.25)
	bar2.mesh             = bm2
	bar2.position         = Vector3(0, 5.0, 0)
	bar2.material_override = _gate_material(0.6)
	add_child(bar2)

	# Gate light — pulses gently
	_gate_light = OmniLight3D.new()
	_gate_light.light_color    = Color(0.1, 0.6, 1.0) if not is_finish_line else Color(1.0, 0.85, 0.1)
	_gate_light.light_energy   = 8.0
	_gate_light.omni_range     = 60.0
	_gate_light.shadow_enabled = false
	_gate_light.position       = Vector3(0, 10.5, 0)
	add_child(_gate_light)

	# Finish line: add FINISH text marker light
	if is_finish_line:
		var extra := OmniLight3D.new()
		extra.light_color  = Color(1.0, 0.88, 0.15)
		extra.light_energy = 12.0
		extra.omni_range   = 80.0
		extra.position     = Vector3(0, 15.0, 0)
		add_child(extra)

func _add_post(pos: Vector3) -> void:
	var post := MeshInstance3D.new()
	var pm   := CylinderMesh.new()
	pm.top_radius    = 0.4
	pm.bottom_radius = 0.5
	pm.height        = 12.0
	post.mesh             = pm
	post.position         = pos
	post.material_override = _gate_material(1.0)
	add_child(post)

func _gate_material(energy_mult: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var col := Color(0.1, 0.55, 1.0) if not is_finish_line else Color(1.0, 0.85, 0.1)
	m.albedo_color               = col
	m.emission_enabled           = true
	m.emission                   = col
	m.emission_energy_multiplier = 2.8 * energy_mult
	m.metallic                   = 0.85
	m.roughness                  = 0.08
	return m

func _process(delta: float) -> void:
	if _gate_light == null:
		return
	_anim_t += delta
	# Gentle breathing pulse
	var pulse := sin(_anim_t * 1.8) * 0.4 + 1.0
	_gate_light.light_energy = 3.0 * pulse

func _on_body_entered(body: Node3D) -> void:
	if body is IonVehicle:
		var v := body as IonVehicle
		if v.checkpoint_idx == checkpoint_index:
			v.checkpoint_idx = checkpoint_index + 1
			checkpoint_passed.emit(v, checkpoint_index)
