extends RigidBody3D

# Jump force - adjust this value to make the jump higher or lower
var jump_force = 500.0

func _physics_process(delta):
	# Check if spacebar is pressed
	if Input.is_action_just_pressed("ui_accept"):
		# Apply upward impulse to make the die jump
		apply_central_impulse(Vector3(0, jump_force, 0))
