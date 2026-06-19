extends Node2D

signal started_move

@export var is_moving: bool = false
@export var anim_player_path: NodePath = "AnimationPlayer"
var anim_player: AnimationPlayer

var is_open = true


func _ready():
	anim_player = get_node(anim_player_path)
	
	if is_open and randf() < 0.5: 
		anim_player.play("open_idle")
	else:
		is_open = false
		anim_player.play("close_idle")

	
func change_state(new_state_is_open):
	if is_moving: # can't double-click
		return
	if is_open != new_state_is_open:
		started_move.emit()
		is_moving = true
		is_open = new_state_is_open
		if new_state_is_open:
			anim_player.play("open")
			anim_player.queue("open_idle")
		else:
			anim_player.play("close")
			anim_player.queue("close_idle")
		


func _on_button_pressed() -> void:
	pass #change_state(!is_open)


func _on_touch_screen_button_pressed() -> void:
	change_state(!is_open)


func _on_open_close_umbrella_button_mouse_entered() -> void:
	change_state(!is_open)
