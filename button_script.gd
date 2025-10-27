extends Button

@export var button_value: int = 2  # Set this in the inspector for each button
@export var normal_color: Color = Color(0.2, 0.2, 0.2)  # Dark gray
@export var active_color: Color = Color(0.3, 0.6, 0.3)  # Green

signal number_toggled(number: int, is_active: bool)

var is_active: bool = false

func _ready():
	pressed.connect(_on_pressed)
	update_color()
	# Prevent button from responding to keyboard input
	focus_mode = Control.FOCUS_NONE

func _on_pressed():
	is_active = !is_active  # Toggle
	update_color()
	number_toggled.emit(button_value, is_active)

func update_color():
	if is_active:
		modulate = active_color
	else:
		modulate = normal_color
