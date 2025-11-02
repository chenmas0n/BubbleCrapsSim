extends Node3D

enum GameState { IDLE, ROLLING, SHOWING_RESULT }
var game_state: GameState = GameState.IDLE

var active_numbers: Array[int] = []
var total: int = 0
const MAX_DISPLAY := 5
var all_history: Array[int] = []

const SEVEN_PENALTY := 500


# Wagering system
var points: int = 1000
const BASE_PAYOUT := 100
var wagers := {}

# Payout multipliers based on probability (6 ways to roll 7 / ways to roll X)
const PAYOUT_TABLE := {
	2: 600,   # 1 way  - 6x multiplier
	3: 300,   # 2 ways - 3x multiplier
	4: 200,   # 3 ways - 2x multiplier
	5: 150,   # 4 ways - 1.5x multiplier
	6: 120,   # 5 ways - 1.2x multiplier
	7: 0,     # 6 ways - PENALTY (special case)
	8: 120,   # 5 ways - 1.2x multiplier
	9: 150,   # 4 ways - 1.5x multiplier
	10: 200,  # 3 ways - 2x multiplier
	11: 300,  # 2 ways - 3x multiplier
	12: 600   # 1 way  - 6x multiplier
}

signal total_changed(total: int)
@onready var sum_label: Label = $CanvasLayer/SumLabel
@onready var history_label: VBoxContainer = $CanvasLayer/HistoryColumn
@onready var points_label: Label = $CanvasLayer/Points  # NEW: Reference your Points label
@onready var points_feedback_label: Label = $CanvasLayer/PointsFeedback
@onready var message_label: Label = $CanvasLayer/MessageLabel

func _ready() -> void:
	 # Connect all number buttons
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.number_toggled.connect(_on_number_toggled)
		var button_value = button.button_value
		var payout = PAYOUT_TABLE.get(button_value, 0)
		if button_value == 7:
			button.text = str(button_value) + "\n(-" + str(SEVEN_PENALTY) + ")"
		else:
			button.text = str(button_value) + "\n(+" + str(payout) + ")"
	var floor = get_node_or_null("ShakeFloor")
	if floor:
		floor.shake_started.connect(_on_shake_started)
	update_points_display()
	
# Hide message label initially
	if message_label:
		message_label.visible = false

func show_points_change(amount: int) -> void:
	if points_feedback_label:
		if amount > 0:
			points_feedback_label.text = "+" + str(amount)
			points_feedback_label.add_theme_color_override("font_color", Color(0, 1, 0))
		else:
			points_feedback_label.text = str(amount)
			points_feedback_label.add_theme_color_override("font_color", Color(1, 0, 0))

		points_feedback_label.visible = true
		# Hide after 1 second
		await get_tree().create_timer(1.0).timeout
		points_feedback_label.visible = false
func update_points_display() -> void:
	points_label.text = "Points: " + str(points)

func _on_shake_started() -> void:
	game_state = GameState.ROLLING
	lock_buttons()


func set_total(v: int) -> void:
	total = v
	total_changed.emit(total)
	sum_label.text = "Sum: " + str(total)
	sum_label.visible = true
	var anim_player = sum_label.get_parent().get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("ResultAnim")
	all_history.append(total)
	_update_history_ui()
	print(total)
	check_sum_match()
	game_state = GameState.SHOWING_RESULT
	unlock_buttons()
	
func _on_number_toggled(number: int, is_active: bool):
	if is_active:
		active_numbers.append(number)
	else:
		active_numbers.erase(number)
	print("Active numbers: ", active_numbers)

func check_sum_match() -> void:
	var active_sum = 0
	if total == 7:
		points -= SEVEN_PENALTY
		sum_label.add_theme_color_override("font_color", Color(1, 0, 0))  # Red
		print("Rolled 7! Lost ", SEVEN_PENALTY, " points")
		update_points_display()
		return
	# Check if player guessed correctly
	if total in active_numbers:
		var payout = PAYOUT_TABLE.get(total, 0)
		points += payout
		sum_label.add_theme_color_override("font_color", Color(0, 1, 0))  # Green
		print("Correct! Rolled ", total, " - Won ", payout, " points!")
	else:
		# Wrong guess - no points
		sum_label.add_theme_color_override("font_color", Color(1, 1, 1))  # White
		print("Missed - Rolled ", total, " but didn't select it")
	update_points_display()
func _update_history_ui() -> void:
	# Use your variable name here; if you kept `history_label`, use that.
	for child in history_label.get_children():
		child.queue_free()
	var start: int = max(0, all_history.size() - MAX_DISPLAY)
	# Newest at top
	for i in range(all_history.size() - 1, start - 1, -1):
		var label: Label = Label.new()
		label.text = str(all_history[i])
		history_label.add_child(label)
		
func lock_buttons() -> void:
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.disabled = true
func unlock_buttons() -> void:
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.disabled = false
