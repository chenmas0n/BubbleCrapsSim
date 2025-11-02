extends Node3D



var active_numbers: Array[int] = []
var total: int = 0
const MAX_DISPLAY := 5
var all_history: Array[int] = []
var roll_counts := {} 
var player_rolled: bool = false 
const POWERUP_CARD_SCENE = preload("res://powerup_card.tscn")

# Wagering system
var points: int = 1000
const BASE_PAYOUT := 100
var wagers := {}

var current_level: int = 1
var rolls_remaining: int = 0
var level_goal: int = 0

enum GameState {
	IDLE,           # Waiting for player to place bets and roll
	ROLLING,        # Dice are currently rolling
	SHOWING_RESULT, # Result is displayed, can adjust bets
	LEVEL_COMPLETE, # Level completed, transitioning to next
	GAME_OVER       # Game over, waiting for restart
}

var game_state: GameState = GameState.IDLE


# Level definitions: [required_points, allowed_rolls, starting_points]
const LEVEL_DATA := {
	1: {"goal": 2000, "rolls": 2, "start_points": 1000},
	2: {"goal": 3500, "rolls": 12, "start_points": 1500},
	3: {"goal": 5000, "rolls": 15, "start_points": 2000},
	4: {"goal": 7500, "rolls": 18, "start_points": 2500},
	5: {"goal": 10000, "rolls": 20, "start_points": 3000},
	6: {"goal": 15000, "rolls": 25, "start_points": 4000},
	7: {"goal": 20000, "rolls": 30, "start_points": 5000},
	8: {"goal": 30000, "rolls": 35, "start_points": 6000},
	9: {"goal": 45000, "rolls": 40, "start_points": 8000},
	10: {"goal": 60000, "rolls": 50, "start_points": 10000}
}

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
@onready var points_label: Label = $CanvasLayer/Points
@onready var points_feedback_label: Label = $CanvasLayer/PointsFeedback
@onready var message_label: Label = $CanvasLayer/MessageLabel
@onready var clear_bets_button: Button = $CanvasLayer/ClearBetsButton
@onready var rolls_label: Label = $CanvasLayer/RollsLabel
@onready var level_label: Label = $CanvasLayer/LevelLabel
@onready var goal_label: Label = $CanvasLayer/GoalLabel
@onready var game_over_panel: Panel = $CanvasLayer/GameOverPanel
@onready var try_again_button: Button = $CanvasLayer/GameOverPanel/TryAgainButton
@onready var reason_label: Label = $CanvasLayer/GameOverPanel/ReasonLabel
@onready var roll_chart: VBoxContainer = $CanvasLayer/GameOverPanel/RollChart
@onready var powerup_selection_panel: Panel = $CanvasLayer/PowerupSelectionPanel
@onready var cards_container: HBoxContainer = $CanvasLayer/PowerupSelectionPanel/VBoxContainer/CardsContainer

func _process(delta):
	# Debug: Show current state (remove in production)
	if Input.is_action_just_pressed("ui_text_completion_query"):  # Tab key
		print("Current State: ", GameState.keys()[game_state])

func _ready() -> void:
# Connect all number buttons
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.wager_changed.connect(_on_wager_changed)
	# Connect to floor shake signal
	var floor = get_node_or_null("ShakeFloor")
	if floor:
		floor.shake_started.connect(_on_shake_started)
	# Connect clear bets button
	if clear_bets_button:
		clear_bets_button.pressed.connect(_on_clear_bets_pressed)
	# Connect try again button
	if try_again_button:
		try_again_button.pressed.connect(_on_try_again_pressed)
	# Hide game over panel initially
	if game_over_panel:
		game_over_panel.visible = false
	# TESTING: Add some powerups manually
	#PowerupManager.add_powerup(PowerupManager.PowerupType.GOLDEN_DICE)
	#PowerupManager.add_powerup(PowerupManager.PowerupType.LUCKY_NUMBER, 7)  # 7 is lucky
	#PowerupManager.add_powerup(PowerupManager.PowerupType.EXTRA_CHANCES)
	start_level(1)
	if message_label:
		message_label.visible = false
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
func start_level(level: int) -> void:
	current_level = level
	# Get level data or use last level if beyond max
	var level_info = LEVEL_DATA.get(level, LEVEL_DATA[10])
	
	level_goal = level_info["goal"]
	rolls_remaining = level_info["rolls"]
	points = level_info["start_points"]
	
	rolls_remaining += PowerupManager.get_bonus_rolls()
	points += PowerupManager.get_bonus_starting_points()
	PowerupManager.reset_level_powerups()  # Reset per-level flags
	game_state = GameState.IDLE
	
	clear_all_wagers()
	update_level_display()
	update_points_display()
	update_rolls_display()
	
	print("Starting Level ", current_level, " - Goal: ", level_goal, " | Rolls: ", rolls_remaining)
	if level == 1:
		# Small delay so player can see level start
		await get_tree().create_timer(0.5).timeout
		show_powerup_selection()

func update_level_display() -> void:
	if level_label:
		level_label.text = "Level: " + str(current_level)

func update_rolls_display() -> void:
	if rolls_label:
		rolls_label.text = "Rolls: " + str(rolls_remaining)

func update_goal_display() -> void:
	if goal_label:
		var total_wealth = get_total_wealth()
		goal_label.text = "Goal: " + str(total_wealth) + " / " + str(level_goal)

func get_total_wealth() -> int:
	return points + get_total_wagered()

func update_points_display() -> void:
	var wagered = get_total_wagered()
	points_label.text = "Points: " + str(points) + " (Wagered: " + str(wagered) + ")"
	
	# Update clear button text
	if clear_bets_button:
		if wagered > 0:
			clear_bets_button.text = "Clear All Bets (" + str(wagered) + ")"
			clear_bets_button.disabled = false
		else:
			clear_bets_button.text = "Clear All Bets"
			clear_bets_button.disabled = true
	
	# Update goal display
	update_goal_display()
func _on_wager_changed(number: int, wager_amount: int) -> void:
	# Remove old wager if exists
	if game_state == GameState.GAME_OVER or game_state == GameState.ROLLING or game_state == GameState.LEVEL_COMPLETE:
		return
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
	# Don't allow rolling if game is over
	if game_state == GameState.GAME_OVER or game_state == GameState.LEVEL_COMPLETE:
		return
	
	if rolls_remaining <= 0:
		show_message("No rolls remaining!")
		return
	
	game_state = GameState.ROLLING
	player_rolled = true
	lock_buttons()

func set_total(v: int) -> void:
	if player_rolled:
		total = v
		rolls_remaining -= 1
		update_rolls_display()
		player_rolled = false
		total_changed.emit(total)
		sum_label.text = "Sum: " + str(total)
		sum_label.visible = true
		var anim_player = sum_label.get_parent().get_node_or_null("AnimationPlayer")
		if anim_player:
			anim_player.play("ResultAnim")
		all_history.append(total)
		if roll_counts.has(total):
			roll_counts[total] += 1
		else:
			roll_counts[total] = 1
	game_state = GameState.SHOWING_RESULT
	_update_history_ui()
	print(total)
	check_sum_match()

	update_rolls_display()
	unlock_buttons()
	check_level_complete()
	if game_state == GameState.GAME_OVER:
		lock_buttons()

func check_level_complete() -> void:
	var total_wealth = get_total_wealth()
	
	# Win condition: reached goal
	if total_wealth >= level_goal:
		show_level_complete()
		return
	
	# Loss condition: out of rolls
	if rolls_remaining <= 0:
		show_game_over()
		return
	
	# Continue playing
	print("Rolls remaining: ", rolls_remaining, " | Total wealth: ", total_wealth, " / ", level_goal)

func show_level_complete() -> void:
	game_state = GameState.LEVEL_COMPLETE
	lock_buttons()
	
	# Show completion message
	sum_label.text = "LEVEL " + str(current_level) + " COMPLETE!"
	sum_label.add_theme_color_override("font_color", Color(0, 1, 0))
	
	print("Level ", current_level, " complete!")
	
	# Advance to next level after delay
	await get_tree().create_timer(2.0).timeout
	start_level(current_level + 1)

func show_game_over(reason: String = "") -> void:
	game_state = GameState.GAME_OVER
	var floor = get_node_or_null("ShakeFloor")
	lock_buttons()
	if floor and floor.has_method("set_locked"):
		floor.set_locked(true)
	if game_over_panel:
		game_over_panel.visible = true
		var reason_label = game_over_panel.get_node_or_null("ReasonLabel")
		if reason_label:
			reason_label.text = reason
	# Update game over text
	display_roll_distribution()
	sum_label.text = "GAME OVER!"
	sum_label.add_theme_color_override("font_color", Color(1, 0, 0))
	
	var total_wealth = get_total_wealth()
	print("Game Over! Reached: ", total_wealth, " / ", level_goal)

func _on_try_again_pressed() -> void:
	var floor = get_node_or_null("ShakeFloor")
	if game_over_panel:
		game_over_panel.visible = false
	sum_label.text = ""
	sum_label.visible = false
	all_history.clear()
	roll_counts.clear()
	_update_history_ui()
	PowerupManager.reset_powerups()
	start_level(1)
	unlock_buttons()
	floor.set_locked(false)
	print("Game restarted!")

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
		
		# APPLY: Risk Taker penalty multiplier
		var penalty_mult = PowerupManager.get_seven_penalty_multiplier()
		total_lost = int(total_lost * penalty_mult)
		
				# APPLY: Insurance refund
		var insurance_refund = PowerupManager.get_seven_insurance_refund(total_lost)
		if insurance_refund > 0:
			points += insurance_refund
			print("Insurance refund: ", insurance_refund)
		
		if PowerupManager.should_apply_seven_shield():
			sum_label.text = "PROTECTED!"
			sum_label.add_theme_color_override("font_color", Color(0, 1, 1))  # Cyan
			print("Seven Shield activated! No wagers lost.")
			PowerupManager.on_seven()
			update_points_display()
			return

		wagers.clear()
		active_numbers.clear()
		sum_label.add_theme_color_override("font_color", Color(1, 0, 0))
		print("Rolled 7! Lost ", total_lost, " points (refunded: ", insurance_refund, ")")
		for button in get_tree().get_nodes_in_group("number_buttons"):
			button.reset_to_wager(0)
		update_points_display()
		PowerupManager.on_seven()
		update_points_display()
		return
	
	# Case 2: Rolled a number we wagered on - WIN!
	if total in active_numbers:
		var wager = wagers.get(total, 0)
		var base_payout = PAYOUT_TABLE.get(total, 0)
		# APPLY: Powerup payout modifiers
		var modified_payout = PowerupManager.apply_payout_modifiers(base_payout, total)
		var payout = PAYOUT_TABLE.get(total, 0)
		var profit = int((wager * base_payout) / 100.0)
		var total_win = wager + profit  # Get wager back + scaled profit
		
		points += total_win
		sum_label.add_theme_color_override("font_color", Color(0, 1, 0))
		print("WIN! Rolled ", total, " - Wager: ", wager, " + Profit: ", profit, " = ", total_win, " total")
		# APPLY: Hot Streak bonus
		var streak_bonus = PowerupManager.on_win()
		if streak_bonus > 0:
			points += streak_bonus
			show_message("HOT STREAK! +" + str(streak_bonus))
		
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
	var buttons = get_tree().get_nodes_in_group("number_buttons")
	for button in buttons:
		button.disabled = true
		button.modulate.a = 0.6
	if clear_bets_button:
		clear_bets_button.disabled = true

func unlock_buttons() -> void:
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.disabled = false
		button.modulate.a = 1.0
	if clear_bets_button:
		clear_bets_button.disabled = false

func _on_clear_bets_pressed() -> void:
	clear_all_wagers()
func display_roll_distribution() -> void:
	if not roll_chart:
		return
	
	# Clear existing chart
	for child in roll_chart.get_children():
		child.queue_free()
	
	# Add title
	var title = Label.new()
	title.text = "Roll Distribution"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	roll_chart.add_child(title)
	
	# Find max count for scaling
	var max_count = 0
	for count in roll_counts.values():
		if count > max_count:
			max_count = count
	
	if max_count == 0:
		max_count = 1
	
	# Create horizontal container for all bars
	var bars_container = HBoxContainer.new()
	bars_container.alignment = BoxContainer.ALIGNMENT_END
	bars_container.custom_minimum_size = Vector2(0, 200)
	roll_chart.add_child(bars_container)
	
	# Create vertical bar for each number (2-12)
	for number in range(2, 13):
		var count = roll_counts.get(number, 0)
		
		# Column container (vertical)
		var column = VBoxContainer.new()
		column.custom_minimum_size = Vector2(20, 200)
		column.alignment = BoxContainer.ALIGNMENT_END  # Align to bottom
		
		# Count label at top
		var count_label = Label.new()
		count_label.text = str(count)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.custom_minimum_size = Vector2(20, 0)
		count_label.add_theme_font_size_override("font_size", 12)
		
		# Spacer to push bar to bottom
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Bar (ColorRect)
		var bar = ColorRect.new()
		var max_bar_height = 150.0
		var bar_height = (float(count) / float(max_count)) * max_bar_height
		bar.custom_minimum_size = Vector2(18, bar_height)
		
		# Color based on roll number
		if number == 7:
			bar.color = Color(1, 0.3, 0.3)  # Red for 7
		else:
			bar.color = Color(0.3, 0.6, 1)  # Blue for others
		
		# Number label at bottom
		var num_label = Label.new()
		num_label.text = str(number)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.custom_minimum_size = Vector2(20, 0)
		num_label.add_theme_font_size_override("font_size", 12)
		
		# Add to column (top to bottom: count, spacer, bar, number)
		column.add_child(count_label)
		column.add_child(spacer)
		column.add_child(bar)
		column.add_child(num_label)
		
		# Add column to bars container
		bars_container.add_child(column)
func show_powerup_selection() -> void:
	print("=== SHOWING POWERUP SELECTION ===")
	
	# Lock game controls
	game_state = GameState.SHOWING_RESULT
	lock_buttons()
	
	# Clear any existing cards
	for child in cards_container.get_children():
		child.queue_free()
	
	# Get 3 random powerup types
	var available_powerups = PowerupManager.PowerupType.values()
	available_powerups.shuffle()
	var chosen_three = available_powerups.slice(0, 3)
	
	# Create 3 cards
	for powerup_type in chosen_three:
		var card = POWERUP_CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.setup(powerup_type)
		card.card_selected.connect(_on_powerup_card_selected)
	
	# Show panel
	if powerup_selection_panel:
		powerup_selection_panel.visible = true
	
	print("3 powerup cards displayed")

func _on_powerup_card_selected(powerup_type: int) -> void:
	print("=== POWERUP SELECTED ===")
	print("Type: ", PowerupManager.POWERUP_DATA[powerup_type]["name"])
	
	# Add powerup to manager
	PowerupManager.add_powerup(powerup_type)
	
	# Special handling for Lucky Number (needs user to choose number)
	if powerup_type == PowerupManager.PowerupType.LUCKY_NUMBER:
		# For now, auto-assign 7 as lucky number
		# Later you can add UI to let player choose
		PowerupManager.powerup_data[powerup_type] = 7
		print("Lucky number set to 7")
	
	# Hide panel
	if powerup_selection_panel:
		powerup_selection_panel.visible = false
	
	# Continue game
	game_state = GameState.IDLE
	unlock_buttons()
	
	print("Powerup applied! Active powerups: ", PowerupManager.get_active_powerup_names())
