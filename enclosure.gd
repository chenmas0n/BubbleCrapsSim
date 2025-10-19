extends StaticBody3D

func _ready():
	var mat := PhysicsMaterial.new()
	mat.friction = 0.0   # smooth slides
	physics_material_override = mat
