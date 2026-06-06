extends CharacterBody2D
class_name Block

signal want_to_move(block_id, i_row, i_col, dir: Vector2)
signal just_selected(block_id, i_row, i_col)

var block_id = -1
var i_width = 1
var i_height = 1
var i_row = -1
var i_col = -1
var is_selected: bool = false
@export var collider_path : NodePath = "CollisionShape2D"
@export var clickable_path : NodePath = "Clickable"
@export var label_path : NodePath = "Label"
@export var sprite_path : NodePath = "Clickable/Sprite2D"

var collider
var clickable
var label
var sprite

const PIXELS_PER_UNIT = 130

const THEME_COLORS = [
	"#FBC697",
	"#732F54",
	"#F7738E",
	"#F6A8B3",
	"#FFEDD7",
	"#D1505B",
	"#5AB9A2",
	"#6ED6A4",
	"#D2EC99",
	"#549A8D",
	"#367C50",
	"#702D51",
	"#8B3A49",
	"#B2555D",
	"#4C2242",
	"#3B132B",
]

var arrow_key_speed = 300

func _ready() -> void:
	collider = get_node(collider_path)
	clickable = get_node(clickable_path)
	label = get_node(label_path)
	sprite = get_node(sprite_path)

func set_variables(block_id, width: int, height: int, row: int, col: int):
	self.block_id = block_id
	self.i_width = width
	self.i_height = height
	self.i_row = row
	self.i_col = col
	$Clickable/base_texture.self_modulate = Color(THEME_COLORS[block_id  % len(THEME_COLORS)])
	$Label.text = str(block_id)
	position = Vector2(row + 0.5 * width, col + 0.5 * height) * PIXELS_PER_UNIT  
	$Clickable.scale = Vector2(width, height)
	$CollisionShape2D.scale = Vector2(width, height)

func get_input(): # arrow keys can move selected tile
	var input_dir : Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * arrow_key_speed
	want_to_move.emit(block_id, i_row, i_col, input_dir)

func _physics_process(delta):
	if is_selected:
		get_input()
		get_drag()
		set_row_col_from_pos()
		move_and_collide(velocity * delta)
	

func get_drag():
	pass

func _process(_delta)-> void:
	if is_selected != sprite.visible:
		sprite.visible = is_selected

func snap_to_position_from_row_col():
	position = Vector2(i_row + 0.5 * i_width, i_col + 0.5 * i_height) * PIXELS_PER_UNIT

func set_row_col_from_pos():
	# save row/ col position based on current position to allow snapping to new location
	self.i_row = round((position.x / PIXELS_PER_UNIT) - 0.5 * i_width)
	self.i_col = round((position.y / PIXELS_PER_UNIT) - 0.5 * i_height)
	return Vector2i(self.i_row, self.i_col)

func _on_clickable_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	just_selected.emit(block_id, i_row, i_col)
