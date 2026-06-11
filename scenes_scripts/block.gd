extends CharacterBody2D
class_name Block

signal want_to_move(block_id: int, grid_pos: Vector2, dir: Vector2)
signal just_selected(block: Block, block_id: int, grid_pos: Vector2)
signal just_deselected(
	block: Block, prev_grid_pos: Vector2, new_grid_pos: Vector2
)

@onready var main_node = get_tree().get_root().get_node('Node').get_node('Main2D')
@onready var collider = $CollisionShape2D
@onready var clickable = $Clickable
@onready var label = $Label
@onready var selected_sprite = $Clickable/selected_texture

var block_id = -1
var dims = Vector2(1, 1)
var grid_pos = Vector2(-1, -1)
var is_selected: bool = false
var is_dragging: bool = false

@export var special_texture : Texture = preload("res://images/tiles/sun.png")

var arrow_key_speed = 300

var drag_start : Vector2  = Vector2.ZERO
var drag_start_pos: Vector2 = Vector2.ZERO

###
### NODE METHODS
###

func _ready() -> void:
	set_row_col_from_pos()

func _process(_delta)-> void:
	if is_selected != selected_sprite.visible:
		selected_sprite.visible = is_selected
	if is_selected:
		selected_sprite.self_modulate = Color.WHITE if is_dragging else Color(255,255,255,0.5)

func _physics_process(_delta):
	if is_selected:
		if is_dragging: 
			get_drag()
		else: 
			get_input()

###
### CUSTOM METHODS
###

func set_variables(new_block_id, width: int, height: int, row: int, col: int):
	self.block_id = new_block_id
	self.dims.x = width
	self.dims.y = height
	self.grid_pos.x = row
	self.grid_pos.y = col
	$Clickable/base_texture.self_modulate = Color(
		Constants.THEME_COLORS[block_id  % len(Constants.THEME_COLORS)]
	)
	$Label.text = str(block_id)
	position = Vector2(row + 0.5 * width, col + 0.5 * height) * Constants.PIXELS_PER_UNIT  
	$Clickable.scale = Vector2(width, height)
	$CollisionShape2D.scale = Vector2(width, height)
	if block_id == 0:
		$special_texture.texture = special_texture

func get_input(): # arrow keys can move selected tile
	var input_dir : Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * arrow_key_speed
	want_to_move.emit(block_id, grid_pos, input_dir)

func start_drag():
	drag_start = get_global_mouse_position()
	is_dragging = true
	is_selected = true
	drag_start_pos = position
	$"../../../DEBUG_mouseclick".global_position = drag_start
	$"../../../DEBUG_dragoffset".clear_points()
	$"../../../DEBUG_dragoffset".add_point(get_global_mouse_position())
	$"../../../DEBUG_dragoffset".add_point(global_position)
	just_selected.emit(self, block_id, grid_pos)


func end_drag():
	var prev_pos = grid_pos
	is_dragging = false
	is_selected = false
	
	set_row_col_from_pos()
	snap_to_position_from_row_col()
	
	print(prev_pos, grid_pos)
	just_deselected.emit(self, prev_pos, grid_pos)

func get_drag():
	if is_dragging:
		var overall_offset = get_global_mouse_position() - drag_start
		var legal_move = true
		
		# TODO: should probably move this up to block_manager
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

func snap_to_position_from_row_col():
	var new_position = (grid_pos + 0.5 * dims) * Constants.PIXELS_PER_UNIT
	if (position - new_position).length_squared() < 5000:
		position = new_position
		

func set_row_col_from_pos():
	# save row/ col position based on current position to allow snapping to new location
	grid_pos.x = round((position.x / Constants.PIXELS_PER_UNIT) - 0.5 * dims.x)
	grid_pos.y = round((position.y / Constants.PIXELS_PER_UNIT) - 0.5 * dims.y)
	$DEBUG_array_idxs.text = str(grid_pos.x)+ ", " + str(grid_pos.y)
	return Vector2(grid_pos)

###
### INTERACTIVITY
###

func _on_clickable_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				start_drag()
			else:
				end_drag()
