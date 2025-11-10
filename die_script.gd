extends RigidBody3D

var _still_time := 0.0
const V_THRESH := 5
const W_THRESH := 7
const SLEEP_AFTER := 0.3
var cd := 0.0
const CD_TIME := 0.03  # short cooldown to prevent rapid repeats
const MIN_IMPULSE := 15
var ripple_manager: RippleManager = null
@onready var sfx: AudioStreamPlayer3D = $HitSound
@onready var sum_label = null
# Define the normal vectors for each face of the die in local space
# These point outward from each face
var face_normals := {
	1: Vector3(0, 0, -1),  # Face 1
	2: Vector3(0, 1, 0),   # Face 2
	3: Vector3(-1, 0, 0),   # Face 3
	4: Vector3(1, 0, 0),  # Face 4
	5: Vector3(0, -1, 0),  # Face 5
	6: Vector3(0, 0, 1)    # Face 6
}

var last_detected_face := -1
var has_detected_this_roll := false


func _ready():
	# connect to floor signal dynamically
	sum_label = get_node_or_null("/root/Main/CanvasLayer/SumLabel")  # Adjust path to your scene
	var floor = get_parent().get_node_or_null("ShakeFloor") # adjust path as needed
	if floor:
		floor.connect("shake_started", Callable(self, "_on_floor_shake_started"))
	ripple_manager = get_node_or_null("/root/Main/RippleManager")  # Adjust path
	


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
			if not sleeping:
				sleeping = true
				# Detect and print the upward face when die becomes still
				if not has_detected_this_roll:
					var face = get_upward_face()
					last_detected_face = face
					has_detected_this_roll = true
					# Check if ALL dice are now settled before printing sum
					var parent = get_parent()
					var all_detected = true
					for child in parent.get_children():
						if child.has_method("get_upward_face") and child.has_detected_this_roll == false:
							all_detected = false
							break
					
					# Only print if all dice have detected their faces
					if all_detected:
						var total = 0
						for child in parent.get_children():
							if child.has_method("get_upward_face"):
								total += child.get_upward_face()
						
						get_node("/root/Main/").set_total(total)
						print("Dice sum: ", total)
	else:
		_still_time = 0.0
		# Reset detection flag when die starts moving again
		if has_detected_this_roll:
			has_detected_this_roll = false

# Function to detect which face is pointing upward
func get_upward_face() -> int:
	var up_direction := Vector3.UP  # World up direction (0, 1, 0)
	var best_face := 1
	var best_dot := -1.0
	
	# Check each face to see which one is pointing most upward
	for face_number in face_normals:
		# Transform the face normal from local space to world space
		var world_normal: Vector3 = global_transform.basis * face_normals[face_number]
		# Calculate dot product with up direction
		var dot := world_normal.dot(up_direction)
		# The face with the highest dot product is pointing most upward
		if dot > best_dot:
			best_dot = dot
			best_face = face_number
	
	return best_face

func _integrate_forces(state):
	if cd > 0.0:
		return
	var n = state.get_contact_count()
	for i in range(n):
		var imp: Vector3 = state.get_contact_impulse(i)  # impulse vector
		var imp_magnitude = imp.length()
		if imp_magnitude >= MIN_IMPULSE:                  # check magnitude
			sfx.pitch_scale = randf_range(0.96, 1.04)
			sfx.volume_db = lerp(-10.0, 0.0, clamp(imp.length() / 4.0, 0.0, 1.0))
			sfx.play()
			cd = CD_TIME
			if ripple_manager:
				var collision_point = state.get_contact_collider_position(i)
				ripple_manager.add_ripple(collision_point, imp_magnitude,get_instance_id())
			break
