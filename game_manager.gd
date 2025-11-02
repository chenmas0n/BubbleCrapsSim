extends Node3D

enum GameState { IDLE, ROLLING, SHOWING_RESULT }
var game_state: GameState = GameState.IDLE

var active_numbers: Array[int] = []
var total: int = 0
const MAX_DISPLAY := 5
var all_history: Array[int] = []

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
@onready var clear_bets_button: Button = $CanvasLayer/ClearBetsButton

func _ready() -> void:
	# Connect all number buttons
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.wager_changed.connect(_on_wager_changed)
	
	# Connect to floor shake signal
	var floor = get_node_or_null("ShakeFloor")

	# Initialize points display
	update_points_display()
	
	if message_label:
		message_label.visible = false
	if clear_bets_button:
		clear_bets_button.pressed.connect(_on_clear_bets_pressed)
	if floor:
		floor.shake_started.connect(_on_shake_started)

func clear_all_wagers() -> void:
	# Return all wagered points
	var total_returned = get_total_wagered()
	points += total_returned
	
	# Clear wagers dictionary
	wagers.clear()
	active_numbers.clear()
	
	# Reset all button displays
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.reset_to_wager(0)
	
	update_points_display()
	print("Cleared all wagers. Returned ", total_returned, " points")
func _on_wager_changed(number: int, wager_amount: int) -> void:
	# Remove old wager if exists
	var old_wager = wagers.get(number, 0)
	
	# Check if player has enough points
	var points_difference = wager_amount - old_wager
	
	if points_difference > points:
		show_message("Insufficient funds!")
		# Reset button to old wager
		var button = get_button_for_number(number)
		if button:
			button.reset_to_wager(old_wager)
		return
	
	# Update wager
	if wager_amount <= 0:
		# Remove wager completely
		wagers.erase(number)
		points += old_wager  # Return points
		active_numbers.erase(number)
	else:
		# Update wager
		wagers[number] = wager_amount
		points -= points_difference
		
		# Add to active numbers if not already there
		if number not in active_numbers:
			active_numbers.append(number)
	
	update_points_display()
	print("Wager on ", number, ": ", wager_amount, " | Remaining: ", points)

func get_total_wagered() -> int:
	var total_wagered = 0
	for wager in wagers.values():
		total_wagered += wager
	return total_wagered

func get_button_for_number(number: int) -> Button:
	for button in get_tree().get_nodes_in_group("number_buttons"):
		if button.button_value == number:
			return button
	return null


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
	# Case 1: Rolled a 7 - lose ALL wagers
	if total == 7:
		var total_lost = get_total_wagered()
		wagers.clear()
		active_numbers.clear()
		sum_label.add_theme_color_override("font_color", Color(1, 0, 0))
		print("Rolled 7! Lost all wagers: ", total_lost, " points")
		
		# Reset all buttons
		for button in get_tree().get_nodes_in_group("number_buttons"):
			button.reset_to_wager(0)
		
		update_points_display()
		return
	
	# Case 2: Rolled a number we wagered on - WIN!
	if total in active_numbers:
		var wager = wagers.get(total, 0)
		var base_payout = PAYOUT_TABLE.get(total, 0)
		var payout = PAYOUT_TABLE.get(total, 0)
		var profit = int((wager * base_payout) / 100.0)
		var total_win = wager + profit  # Get wager back + scaled profit
		
		points += total_win
		sum_label.add_theme_color_override("font_color", Color(0, 1, 0))
		print("WIN! Rolled ", total, " - Wager: ", wager, " + Profit: ", profit, " = ", total_win, " total")
		
		# Keep wagers active for next roll (they stay on the table)
		
	# Case 3: Rolled a number we didn't wager on (not 7) - wagers stay active
	else:
		sum_label.add_theme_color_override("font_color", Color(1, 1, 1))
		print("Rolled ", total, " - No bet on this number. Wagers remain.")
		# Wagers stay in place, points don't change
	
	update_points_display()
	check_game_over()

func show_message(text: String) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		message_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		
		# Hide after 2 seconds
		await get_tree().create_timer(2.0).timeout
		if message_label:
			message_label.visible = false

func update_points_display() -> void:
	var wagered = get_total_wagered()
	points_label.text = "Points: " + str(points) + " (Wagered: " + str(wagered) + ")"
	
func check_game_over() -> void:
	if points <= 0 and get_total_wagered() == 0:
		points = 0
		update_points_display()
		lock_buttons()
		sum_label.text = "GAME OVER!"
		sum_label.add_theme_color_override("font_color", Color(1, 0, 0))
		show_message("Game Over! No points left!")

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
		button.modulate.a = 0.6
	if clear_bets_button:
		clear_bets_button.disabled = true
func unlock_buttons() -> void:
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.disabled = false
		button.modulate.a = 1.0

# Re-enable clear button after roll
	if clear_bets_button:
		clear_bets_button.disabled = false


func _on_clear_bets_pressed() -> void:
	clear_all_wagers()
