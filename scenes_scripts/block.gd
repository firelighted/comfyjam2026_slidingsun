extends CharacterBody2D
class_name Block

signal want_to_move(block_id: int, grid_pos: Vector2, dir: Vector2)
signal just_selected(block_id: int, grid_pos: Vector2)

@onready var main_node = get_tree().get_root().get_node('Node').get_node('Main2D')

var block_id = -1
var dims = Vector2(1, 1)
var grid_pos = Vector2(-1, -1)
var is_selected: bool = false
var is_dragging: bool = false
@export var collider_path : NodePath = "CollisionShape2D"
@export var clickable_path : NodePath = "Clickable"
@export var label_path : NodePath = "Label"
@export var sprite_path : NodePath = "Clickable/Sprite2D"

@export var special_texture : Texture = preload("res://images/tiles/sun.png")

var collider
var clickable
var label
var sprite

const PIXELS_PER_UNIT = 130

const THEME_COLORS = [
	"#FBC697", # sandy yellow brown
	"#732F54",
	"#F7738E",
	"#F6A8B3",
	"#D1505B",
	"#5AB9A2",
	"#6ED6A4",
	"#D2EC99",
	"#549A8D", # dull teal
	"#367C50",
	"#702D51",
	"#8B3A49",
	"#B2555D",
	"#4C2242",
	"#3B132B", # dark purple
	"#FFEDD7", # palest yellow
]

var arrow_key_speed = 300
var mouse_drag_speed = 10

var drag_start : Vector2  = Vector2.ZERO
var drag_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	collider = get_node(collider_path)
	clickable = get_node(clickable_path)
	label = get_node(label_path)
	sprite = get_node(sprite_path)
	set_row_col_from_pos()

func set_variables(block_id, width: int, height: int, row: int, col: int):
	self.block_id = block_id
	self.dims.x = width
	self.dims.y = height
	self.grid_pos.x = row
	self.grid_pos.y = col
	$Clickable/base_texture.self_modulate = Color(THEME_COLORS[block_id  % len(THEME_COLORS)])
	$Label.text = str(block_id)
	position = Vector2(row + 0.5 * width, col + 0.5 * height) * PIXELS_PER_UNIT  
	$Clickable.scale = Vector2(width, height)
	$CollisionShape2D.scale = Vector2(width, height)
	if block_id == 0:
		$special_texture.texture = special_texture

func get_input(): # arrow keys can move selected tile
	var input_dir : Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * arrow_key_speed
	want_to_move.emit(block_id, grid_pos, input_dir)

func _physics_process(_delta):
	# velocity approach
	if is_selected:
		if is_dragging: 
			get_drag()
		else: 
			get_input()
		set_row_col_from_pos()
		move_and_slide()


func start_drag():
	drag_start = get_global_mouse_position()
	is_dragging = true
	drag_start_pos = position
	$"../../../DEBUG_mouseclick".global_position = drag_start
	$"../../../DEBUG_dragoffset".clear_points()
	$"../../../DEBUG_dragoffset".add_point(get_global_mouse_position())
	$"../../../DEBUG_dragoffset".add_point(global_position)


func end_drag():
	is_dragging = false
	is_selected = false
	snap_to_position_from_row_col()

func get_drag():
	if is_dragging:
		var overall_offset = get_global_mouse_position() - drag_start
		var legal_move = true
		
		if abs( overall_offset.x) > abs( overall_offset.y):
			overall_offset = Vector2(overall_offset.x, 0)

			var direction = 1 if overall_offset.x > 0 else -1

			legal_move = main_node.check_move_legality(block_id, direction)
		else:
			overall_offset = Vector2(0, overall_offset.y)
			
			var direction = 1 if overall_offset.y > 0 else -1

			legal_move = main_node.check_move_legality(block_id, direction)
		
		if !legal_move:
			overall_offset = Vector2.ZERO
		
		position = drag_start_pos + overall_offset

func _process(_delta)-> void:
	if is_selected != sprite.visible:
		sprite.visible = is_selected
	if is_selected:
		sprite.self_modulate = Color.WHITE if is_dragging else Color(255,255,255,0.5)

func snap_to_position_from_row_col():
	var new_position = (grid_pos + 0.5 * dims) * PIXELS_PER_UNIT
	if (position - new_position).length_squared() < 5000:
		position = new_position
		

func set_row_col_from_pos():
	# save row/ col position based on current position to allow snapping to new location
	grid_pos.x = round((position.x / PIXELS_PER_UNIT) - 0.5 * dims.x)
	grid_pos.y = round((position.y / PIXELS_PER_UNIT) - 0.5 * dims.y)
	$DEBUG_array_idxs.text = str(grid_pos.x)+ ", " + str(grid_pos.y)
	return Vector2(grid_pos)

func _on_clickable_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				just_selected.emit(block_id, grid_pos)
				start_drag()
			else:
				end_drag()
				set_row_col_from_pos()
