extends Node2D



@export var anim_player_path: NodePath = "AnimationPlayer"
var anim_player: AnimationPlayer

var is_open = true

func _ready():
	anim_player = get_node(anim_player_path)
	change_state(false)
	
	
func change_state(new_state_is_open):
	if is_open != new_state_is_open:
		is_open = new_state_is_open
		if new_state_is_open:
			anim_player.play("open")
			anim_player.queue("open_idle")
		else:
			anim_player.play("close")
			anim_player.queue("close_idle")
		


func _on_button_pressed() -> void:
	change_state(!is_open)
