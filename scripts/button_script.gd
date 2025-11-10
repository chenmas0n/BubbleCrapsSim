extends Button

@export var button_value: int = 2
@export var normal_color: Color = Color(0.2, 0.2, 0.2)
@export var active_color: Color = Color(0.3, 0.6, 0.3)

signal wager_changed(number: int, wager_amount: int)

var current_wager: int = 0
const WAGER_INCREMENT := 100

func _ready():
	pressed.connect(_on_pressed)
	update_display()
	focus_mode = Control.FOCUS_NONE

func _on_pressed():
	print("=== BUTTON PRESSED ===")
	print("Button value: ", button_value)
	print("Disabled property: ", disabled)
	print("Self disabled: ", self.disabled)
	if disabled:
		print("Button is disabled, blocking press")
		return
	# Increase wager by increment
	var game_manager = get_node("/root/Main")
	if not game_manager:
		return
	
	# Check if player can afford this wager
	var new_wager = current_wager + WAGER_INCREMENT
	var points_needed = new_wager - current_wager
	
	if points_needed > game_manager.points:
		# Can't afford, show message
		game_manager.show_message("Not enough points!")
		return
	
	current_wager = new_wager
	wager_changed.emit(button_value, current_wager)
	update_display()

func _gui_input(event):
	# Right-click to decrease/remove wager
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if current_wager > 0:
			current_wager -= WAGER_INCREMENT
			if current_wager < 0:
				current_wager = 0
			wager_changed.emit(button_value, current_wager)
			update_display()

func reset_to_wager(wager: int):
	current_wager = wager
	update_display()

func update_display():
	# Update button text to show value and current wager
	if current_wager > 0:
		text = str(button_value) + "\n$" + str(current_wager)
		modulate = active_color
	else:
		text = str(button_value)
		modulate = normal_color
