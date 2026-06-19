extends Button

signal sibling_button_pressed(sibling_idx: int)

func _ready() -> void:
	get_child(0).text = ""
	text = str(get_index())
	# pressed.connect(_on_pressed)


func _on_pressed() -> void:
	sibling_button_pressed.emit(get_index())
