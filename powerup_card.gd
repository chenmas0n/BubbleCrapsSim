extends PanelContainer
# Individual powerup card UI

signal card_selected(powerup_type)

var powerup_type: int = -1

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var rarity_label: Label = $VBoxContainer/RarityLabel
@onready var select_button: Button = $VBoxContainer/SelectButton

func _ready():
	if select_button:
		select_button.pressed.connect(_on_select_pressed)

func setup(type: int) -> void:
	powerup_type = type
	var data = PowerupManager.POWERUP_DATA[type]
	
	if name_label:
		name_label.text = data["name"]
	
	if description_label:
		description_label.text = data["description"]
	
	if rarity_label:
		rarity_label.text = data["rarity"].capitalize()
		
		# Color based on rarity
		match data["rarity"]:
			"common":
				rarity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			"rare":
				rarity_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1))
			"legendary":
				rarity_label.add_theme_color_override("font_color", Color(1, 0.8, 0))

func _on_select_pressed() -> void:
	card_selected.emit(powerup_type)
