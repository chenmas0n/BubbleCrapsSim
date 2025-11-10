extends Node3D
class_name RippleManager

# Reference to the floor mesh with ripple shader
@export var floor_mesh: MeshInstance3D
  # Minimum time between ripples
# Ripple settings
@export var ripple_duration: float = 2.0
@export var min_impact_velocity: float = 2.0

# Internal ripple tracking
const MAX_RIPPLES = 16
var ripples = []
var last_ripple_positions = {}  # Track recent ripples to prevent stacking
@export var ripple_cooldown: float = 0.2
var shader_material: ShaderMaterial

func _ready():
	if floor_mesh:
		shader_material = floor_mesh.material_override
		
		if not shader_material:
			push_error("RippleManager: No shader material found on floor mesh!")

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		add_ripple(Vector3(0, 0, 0), 1.0)
	# Update existing ripples
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].time += delta
		
		if ripples[i].time >= ripple_duration:
			ripples.remove_at(i)
	# Clean up old cooldown entries
	for key in last_ripple_positions.keys():
		last_ripple_positions[key] -= delta
		if last_ripple_positions[key] <= 0:
			last_ripple_positions.erase(key)
	# Update shader
	if shader_material:
		update_shader_data()

func add_ripple(world_position: Vector3, intensity: float = 1.0, source_id: int = -1):
	"""Add a new ripple at the given world position with cooldown"""
	# Check cooldown for this source
	if source_id >= 0 and last_ripple_positions.has(source_id):
		return  # Still in cooldown, ignore
	
	# Check if too close to existing ripples
	for r in ripples:
		var dist = world_position.distance_to(Vector3(r.position.x, 0, r.position.y))
		if dist < 0.5 and r.time < 0.1:
			return
	
	if ripples.size() >= MAX_RIPPLES:
		ripples.pop_front()
	
	ripples.append({
		"position": Vector2(world_position.x, world_position.z),
		"time": 0.0,
		"intensity": intensity
	})
	# ADD THIS AT THE END, before the closing brace:
	if source_id >= 0:
		last_ripple_positions[source_id] = ripple_cooldown
		
func add_ripple_from_collision(collision_point: Vector3, impact_velocity: float, source_id: int = -1):
	"""Add ripple based on collision impact with cooldown"""
	var vel_magnitude = abs(impact_velocity)
	
	if vel_magnitude >= min_impact_velocity:
		var intensity = clamp(vel_magnitude / 10.0, 0.3, 1.0)
		add_ripple(collision_point, intensity, source_id)  # Pass source_id here
		
func update_shader_data():
	"""Update shader uniform arrays with current ripple data"""
	if not shader_material:
		return
	
	var ripple_array = []
	
	for i in range(MAX_RIPPLES):
		if i < ripples.size():
			var r = ripples[i]
			ripple_array.append(Vector4(r.position.x, r.position.y, r.time, r.intensity))
		else:
			ripple_array.append(Vector4(0, 0, 0, 0))
	
	shader_material.set_shader_parameter("ripple_data", ripple_array)
	shader_material.set_shader_parameter("active_ripple_count", ripples.size())
