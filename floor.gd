extends AnimatableBody3D

var shake_timer = 0.0
var original_position = Vector3.ZERO

func _ready():
	original_position = position

func _process(delta):
	# Press spacebar to start shaking
	if Input.is_action_just_pressed("ui_accept") and shake_timer <= 0:
		shake_timer = 3.0  # Start 5 second shake
	
	# Shake the floor
	if shake_timer > 0:
		shake_timer -= delta
		# Bounce up and down
		var shake_y = abs(sin(shake_timer * 40)) * 0.5
		position = original_position + Vector3(0, shake_y, 0)
	else:
		# Return to original position when done
		position = original_position
