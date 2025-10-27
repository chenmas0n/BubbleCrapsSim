extends Node3D

var active_numbers: Array[int] = []
var total: int = 0
signal total_changed(total: int)
@onready var sum_label: Label = $CanvasLayer/SumLabel


func _ready() -> void:
	 # Connect all number buttons
	for button in get_tree().get_nodes_in_group("number_buttons"):
		button.number_toggled.connect(_on_number_toggled)


func set_total(v: int) -> void:
	total = v
	total_changed.emit(total)
	sum_label.text = "Sum: " + str(total)
	sum_label.visible = true
	var anim_player = sum_label.get_parent().get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("ResultAnim")
	print(total)
	check_sum_match()
	
func _on_number_toggled(number: int, is_active: bool):
	if is_active:
		active_numbers.append(number)
	else:
		active_numbers.erase(number)
	print("Active numbers: ", active_numbers)

func check_sum_match() -> void:
	var active_sum = 0
	if total in active_numbers:
		sum_label.add_theme_color_override("font_color", Color(0, 1, 0)) # Green
		print("dicehit")
	else:
		sum_label.add_theme_color_override("font_color", Color(1, 1, 1)) # Default white
