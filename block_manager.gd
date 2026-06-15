extends Node2D

@export var level_button_parent_path : NodePath = "../UI_foreground/LevelButtonParent"
@export var won_level_ui_path: NodePath = "../UI_foreground/Won_Level_UI"
@export var won_game_ui_path: NodePath = "../UI_foreground/Won_Game_UI"
@export var game_moves_counter_label_path: NodePath = "../UI_foreground/Won_Game_UI/Moves_This_Game_Label"
@export var levels_folder_path : String = "res://levels/"
@export var blocks : Array[Node]
@export var levels : Array[LevelResource]
var level_move_counts : Array[int] = []
var current_level = 0
var block_prefab: PackedScene = preload("res://scenes_scripts/block.tscn")
@onready var block_parent = $BlockParent
var selected_block: Node
var level_button_parent: Node
var won_level_ui : Node
var won_game_ui : Node
var game_moves_counter_label : Node

const SUN_TILE_IDX = 0
const WIN_ARRAY_IDX = 15 # lower right corner of 4x4 array
var array = [0,1,2,2,4,Constants.EMPTY,Constants.EMPTY,3,6,6,7]
var x_size: int
var y_size: int
var cells: int
var moves_this_level: int = 0

var is_dragging = false


###
### NODE METHODS
###

func _ready() -> void:
	if not levels:
		levels = get_levels_from_folder(levels_folder_path)
	
	level_button_parent = get_node(level_button_parent_path)
	won_level_ui = get_node(won_level_ui_path)
	won_game_ui = get_node(won_game_ui_path)
	game_moves_counter_label = get_node(game_moves_counter_label_path)
	# make buttons for choosing level
	var level_button_prefab = preload("res://scenes_scripts/level_button.tscn")
	for i in range(len(levels)):
		var button = level_button_prefab.instantiate()
		button.text = "Level " + str(i)
		button.sibling_button_pressed.connect(receive_level_button_pressed)
		level_button_parent.add_child(button)
		level_move_counts.append(0)
	# start level 0
	load_level(0)
	won_level_ui.visible = false
	won_game_ui.visible = false
	moves_this_level = 0

func _notification(what):
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		if is_instance_valid(selected_block):
			selected_block.end_drag()

###
### RECEIVERS 
###

# TODO: should probably be linked to block's get_drag method?
func receive_block_want_to_move(block_id, grid_pos, dir):
	pass #print("block want to move")

func receive_block_just_selected(block: Block, block_id, grid_pos):
	print('receive_block_just_selected')
	
	if is_instance_valid(selected_block):
		# if a block is already selected, do nothing
		if block.block_id == selected_block.block_id:
			return
		
		# if another block was selected previously, deselect it
		selected_block.end_drag()
		
	selected_block = block

func receive_block_just_deselected(
	block: Block, prev_pos: Vector2, new_pos: Vector2
):
	update_array(prev_pos, new_pos, block.dims, block.block_id)
	print(array)
	check_for_win()


###
### CUSTOM METHODS
###

func check_for_win():
	if array[WIN_ARRAY_IDX] == SUN_TILE_IDX:
		if current_level > -1 and current_level < len(level_move_counts):
			level_move_counts[current_level] = moves_this_level
		print("win")
		if current_level < len(levels) -1:
			won_level_ui.visible = true
		else:
			var moves_this_game = 0
			for i in level_move_counts:
				moves_this_game += i
			game_moves_counter_label.text = str(moves_this_game) + " TOTAL MOVES"
			won_game_ui.visible = true
			

func load_level(level_idx:int, add_to_total: bool=true):
	if current_level > -1 and current_level < len(level_move_counts):
		level_move_counts[current_level] = moves_this_level
	if level_idx < len(levels):
		current_level = level_idx
		array = levels[level_idx].initial_array()
		x_size = levels[level_idx].x_size
		y_size = levels[level_idx].y_size
		cells = x_size * y_size
	else:
		print("Using default level, no valid current_level in levels array")
	init_array()
	spawn_blocks()
	won_level_ui.visible = false
	won_game_ui.visible = false
	moves_this_level = 0
	increment_move_counters(0)
	var sun_goal_position = (Vector2(x_size-1, y_size-1) + 0.5 * Vector2(1, 1)) * Constants.PIXELS_PER_UNIT
	$valid_tile_area_bkgd/SunGoalPosition.global_position = sun_goal_position
	
func get_levels_from_folder(folder_path: String):
	var resources : Array[LevelResource] = []
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = folder_path + "/" + file_name
				var resource = load(full_path)
				if resource:
					resources.append(resource)
			file_name = dir.get_next()
	else:
		printerr("Failed to open directory: ", folder_path)

	return resources
	
func receive_level_button_pressed(sibling_idx: int):
	load_level(sibling_idx)


func get_block_width(block_id):
	var width = 0
	for y in range(y_size):
		for x in range(x_size):
			if get_array(x, y) == block_id:
				width += 1
		
		# assume rect blocks
		if width: # only check the row containing the block
			return width
	
	return width
			
func get_block_height(block_id):
	var height = 0
	for x in range(x_size): # by col
		for y in range(y_size):
			if get_array(x, y) == block_id:
				height += 1
		
		# assume rect blocks
		if height: # only check the first col containing the block
			return height
	
	return height
	
var drag_start = Vector2.ZERO
var drag_end = Vector2.ZERO

func spawn_blocks():
	for block in block_parent.get_children():
		block.queue_free()
	blocks.clear()
	selected_block = null
	
	var complete_blocks = []  # unique blocks, to prevent duplicates for large blocks
	for y in range(y_size):
		for x in range(x_size):
			var block_id = array[(y * x_size) + x]
			if block_id not in complete_blocks:
				if block_id != Constants.EMPTY:
					blocks.push_back(_create_block(block_id, x, y))
					complete_blocks.push_back(block_id)

func _create_block(block_id, row, col):
	var block = block_prefab.instantiate()
	block.set_variables(block_id, get_block_width(block_id), get_block_height(block_id), row, col)
	block_parent.add_child(block)
	
	block.want_to_move.connect(receive_block_want_to_move)
	block.just_selected.connect(receive_block_just_selected)
	block.just_deselected.connect(receive_block_just_deselected)
	return block

func init_array():
	if len(array) < cells - 1: # pad with empty
		for i in range(len(array), cells):
			array.append(Constants.EMPTY)
	elif len(array) > cells:
		push_warning("array longer than x_size * y_size")

func print_array():
	print(array)
	#var output = ""
	#for y in range(y_size):
		#for x in range(x_size):
			#output += " " + str(array[(y * x_size) + x]) + ","
		#print(output)
		#output = ""
		#for x in range(x_size):
			#print("(%d, %d) -> %d" % [x, y, array[(y * x_size) + x]])


func get_array(x: int, y: int) -> int:
	var idx = (y * x_size) + x
	return array[idx]

func increment_move_counters(increment=1):
	moves_this_level += increment
	var moves_this_game = 0
	for i in level_move_counts:
		moves_this_game += i
	moves_this_game += moves_this_level
	$"../UI_foreground/HBoxContainer/MoveCounterLabel".text = str(moves_this_level) + " in Level " + str(current_level) + ", " + str(moves_this_game) + " Total Moves"

func update_array(
	prev_pos: Vector2, new_pos: Vector2, block_dims: Vector2, val: int
) -> void:
	if new_pos == prev_pos: return # no update to be made
	increment_move_counters()
	var dir = new_pos - prev_pos # dir != Vector2.ZERO
	var sign_x = signi(dir.x)
	var sign_y = signi(dir.y)
	
	if dir.x == 0:
		# movement in y direction
		for i in block_dims.x:
			for j in block_dims.y:
				var idx = ((new_pos.y + j) * x_size) + new_pos.x + i
				array[idx] = val
		
			# delete
			for j in abs(dir.y):
				var del_idx = 0
				if sign_y > 0:
					del_idx = ((prev_pos.y + j) * x_size) + prev_pos.x + i
				elif sign_y < 0:
					del_idx = ((prev_pos.y + block_dims.y - j - 1) * x_size) + prev_pos.x + i
			
				array[del_idx] = -1
	elif dir.y == 0:
		# movement in x direction
		for i in block_dims.y:
			for j in block_dims.x:
				var idx = ((new_pos.y + i) * x_size) + new_pos.x + j
				array[idx] = val
			
			for j in abs(dir.x):
				var del_idx = 0
				if sign_x > 0:
					del_idx = ((prev_pos.y + i) * x_size) + prev_pos.x + j
				elif sign_x < 0:
					del_idx = ((prev_pos.y + i) * x_size) + prev_pos.x + block_dims.x - j - 1
				
				array[del_idx] = -1
	

# TODO: should probably refactor to use get_array()
### direction: either -1, 0, or 1
func max_legal_distance(block: Block, axis: String, direction: int) -> int:
	var max_distance = 0
	if direction == 0: return max_distance
	
	var pos = block.grid_pos
	var dims = block.dims
	var break_out = false
	
	if axis == 'x':
		for j in range(x_size):
			if break_out: break
			
			for i in range(dims.y):
				if break_out: break
				
				if direction > 0:
					var x_to_right = pos.x + dims.x + j
					if x_to_right == x_size:
						max_distance = j
						break_out = true
					elif array[(pos.y + i)*x_size + x_to_right] != Constants.EMPTY:
						max_distance = j
						break_out = true
				elif direction < 0:
					if pos.x - j == 0:
						max_distance = j
						break_out = true
					elif array[(pos.y + i)*x_size + pos.x - j - 1] != Constants.EMPTY:
						max_distance = j
						break_out = true
	elif axis == 'y':
		for j in range(y_size):
			if break_out: break
			
			for i in range(dims.x):
				if break_out: break
				
				if direction > 0:
					var y_above = pos.y + dims.y + j
					if y_above == y_size:
						max_distance = j
						break_out = true
					elif array[y_above*x_size + pos.x + i] != Constants.EMPTY:
						max_distance = j
						break_out = true
				elif direction < 0:
					if pos.y - j == 0:
						max_distance = j
						break_out = true
					elif array[(pos.y - j - 1)*x_size + pos.x + i] != Constants.EMPTY:
						max_distance = j
						break_out = true
	
	return max_distance


func _on_next_level_button_pressed() -> void:
	if current_level < len(levels):
		load_level(current_level + 1)
	

func _on_reset_level_button_pressed() -> void:
	moves_this_level = 0
	load_level(current_level)
