extends AnimatableBody3D

signal shake_started  # 🔸 signal to notify dice

var shake_timer := 0.0
var original_position := Vector3.ZERO
var total_shake_time := 3.0
var current_strength := 0.3
var change_timer := 0.0
@onready var roll_sfx: AudioStreamPlayer3D = $RollSound
var is_locked := false


func _ready():
	original_position = position
	randomize()
	
func set_locked(locked: bool) -> void:
	is_locked = locked

func _process(delta):
	if is_locked:  # ← If true, entire function returns
		return
	if Input.is_action_just_pressed("ui_accept") and shake_timer <= 0.0:
		shake_timer = total_shake_time
		current_strength = 1.0
		change_timer = 0.0
		if roll_sfx:
			roll_sfx.play()
		emit_signal("shake_started")  # 🔸 tell dice to wake up

	if shake_timer > 0.0:
		shake_timer -= delta
		change_timer -= delta
		if change_timer <= 0.0:
			var target := randf_range(0.2, 0.5)
			current_strength = lerp(current_strength, target, 0.6)
			change_timer = randf_range(0.08, 0.18)
		var elapsed = total_shake_time - shake_timer
		var shake_y: float = abs(cos(elapsed * 40.0)) * current_strength
		position = original_position + Vector3(0, shake_y, 0)
	else:
		position = original_position
