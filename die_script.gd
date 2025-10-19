extends RigidBody3D

var _still_time := 0.0
const V_THRESH := 5	
const W_THRESH := 5
const SLEEP_AFTER := 0.3
var cd := 0.0
const CD_TIME := 0.03  # short cooldown to prevent rapid repeats
const MIN_IMPULSE := 15 
@onready var sfx: AudioStreamPlayer3D = $HitSound


func _ready():
	# connect to floor signal dynamically
	var floor = get_parent().get_node_or_null("ShakeFloor") # adjust path as needed
	if floor:
		floor.connect("shake_started", Callable(self, "_on_floor_shake_started"))

func _on_floor_shake_started():
	# wake up immediately when floor begins shaking
	sleeping = false
	_still_time = 0.0

func _physics_process(delta):
	# Add small random spin when moving upward
	if cd > 0.0:
		cd -= delta
	if linear_velocity.y > 1.0:
		var random_torque = Vector3(
			randf_range(-2.0, 2.0),
			randf_range(-2.0, 2.0),
			randf_range(-2.0, 2.0)
		)
		apply_torque_impulse(random_torque)

	# Auto-sleep when still
	if linear_velocity.length() < V_THRESH and angular_velocity.length() < W_THRESH:
		_still_time += delta
		if _still_time >= SLEEP_AFTER:
			sleeping = true
	else:
		_still_time = 0.0
func _integrate_forces(state):
	if cd > 0.0:
		return
	var n = state.get_contact_count()
	for i in range(n):
		var imp: Vector3 = state.get_contact_impulse(i)  # impulse vector
		if imp.length() >= MIN_IMPULSE:                  # check magnitude
			sfx.pitch_scale = randf_range(0.96, 1.04)
			sfx.volume_db = lerp(-10.0, 0.0, clamp(imp.length() / 4.0, 0.0, 1.0))
			sfx.play()
			cd = CD_TIME
			break
