extends Sprite2D


func _ready() -> void:
	randomize()
	# random delay before animations start to prevent
	# all wind from doing the same anim at the same exact time
	await get_tree().create_timer(randf_range(0,2)).timeout
	get_child(0).play("idle")
