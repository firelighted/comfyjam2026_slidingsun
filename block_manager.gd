extends Node2D

@export var level_button_parent_path : NodePath = "../UI_foreground/LevelButtonParent"
@export var won_level_ui_path: NodePath = "../UI_foreground/Won_Level_UI"
@export var won_game_ui_path: NodePath = "../UI_foreground/Won_Game_UI"
@export var game_moves_counter_label_path: NodePath = "../UI_foreground/Won_Game_UI/Moves_This_Game_Label"
@export var blocks : Array[Node]
@export var levels : Array[Array] = [
	[
		2,2,3,3,
		0,0,0,1,
		5,6,7,1,
		-1,-1,-1,9
	],
	[
		0,1,2,3,
		5,5,4,4,
		-1,-1,9,10,
		-1,-1,9,10,
	],
	[
		0,1,2,3,
		4,4,5,5,
		6,7,8,8,
		-1,-1,9,10
	]
]
var level_move_counts : Array[int] = []
var current_level = 0
var block_prefab: PackedScene = preload("res://scenes_scripts/block.tscn")
@onready var block_parent = $BlockParent
var level_button_parent: Node
var won_level_ui : Node
var won_game_ui : Node
var game_moves_counter_label : Node

const SUN_TILE_IDX = 0
const WIN_ARRAY_IDX = 15 # lower right corner of 4x4 array
var array = [0,1,2,2,4,Constants.EMPTY,Constants.EMPTY,3,6,6,7]
var breaker_tiles: Array[Vector2] = []
var x_size: int
var y_size: int
var cells: int
var block_num: int = 0

var selected_block: Node
var is_dragging = false


###
### NODE METHODS
###

func _ready() -> void:
	
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
		print("loaded level " + str(i))
	# start level 0
	won_level_ui.visible = false
	won_game_ui.visible = false
	moves_this_level = 0
	$"../UI_foreground/HBoxContainer/ResetLevelButton".pressed.connect(_on_reset_level_button_pressed)
	$"../UI_foreground/Won_Level_UI/Button".pressed.connect(_on_next_level_button_pressed)
	load_level(1)

func _notification(what):
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		if is_instance_valid(selected_block):
			selected_block.end_drag()

	#if what == NOTIFICATION_DRAG_END:
		## Drag data is no longer available and has been disposed already
		#print("Drag ended. Success: ", get_viewport().gui_is_drag_successful())
		#if is_instance_valid(selected_block):
			#selected_block.end_drag()
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
	check_breaker_tiles()
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
		array = levels[level_idx].initial_array()
		x_size = levels[level_idx].x_size
		y_size = levels[level_idx].y_size
		breaker_tiles = levels[level_idx].breaker_tiles
		cells = x_size * y_size
	else:
		push_warning("Using default level, no valid current_level in levels array")
		push_warning("level_idx=" + str(level_idx))
		var level_text = "levels=\n"
		for l in levels:
			level_text += str(l) + "      \n"
		push_warning(levels)
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

func clear_blocks():
	for block in block_parent.get_children():
		block.queue_free()
	blocks.clear()
	selected_block = null
	block_num = 0

func spawn_blocks():
	clear_blocks()
	
	var complete_blocks = []  # unique blocks, to prevent duplicates for large blocks
	for y in range(y_size):
		for x in range(x_size):
			var block_id = array[(y * x_size) + x]
			if block_id not in complete_blocks:
				if block_id != Constants.EMPTY:
					blocks.push_back(_create_block(block_id, x, y))
					complete_blocks.push_back(block_id)
	
	block_num = complete_blocks.size()

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
		push_warning("array "+ str(len(array)) + " longer than x_size * y_size (=" + str(x_size) + " * " + str(y_size) + "), " + str(array))

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
	var idx = 0
	# Tally up moves in other levels 
	for level_moves in level_move_counts:
		if idx != current_level: # only other levels
			moves_this_game += level_moves
		idx += 1
	# Add moves so far this level
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
					elif get_array(x_to_right, pos.y + i) != Constants.EMPTY:
						max_distance = j
						break_out = true
				elif direction < 0:
					if pos.x - j == 0:
						max_distance = j
						break_out = true
					elif get_array(pos.x - j - 1, pos.y + i) != Constants.EMPTY:
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
					elif get_array(pos.x + i, y_above) != Constants.EMPTY:
						max_distance = j
						break_out = true
				elif direction < 0:
					if pos.y - j == 0:
						max_distance = j
						break_out = true
					elif get_array(pos.x + i, pos.y - j - 1) != Constants.EMPTY:
						max_distance = j
						break_out = true
	
	return max_distance


func _on_next_level_button_pressed() -> void:
	if current_level < len(levels):
		load_level(current_level + 1)
	

func _on_reset_level_button_pressed() -> void:
	moves_this_level = 0
	load_level(current_level)


func _on_initial_load_timer_timeout() -> void:
	pass #_ready()#load_level(0)

func check_breaker_tiles():
	var id = EMPTY
	var should_break_block = true
	
	for tile in breaker_tiles:
		var id_at_tile = get_array(tile.x, tile.y)
		
		if id_at_tile == EMPTY:
			should_break_block = false
			break
		else:
			if id != id_at_tile:
				if id == EMPTY:
					id = id_at_tile
				else:
					should_break_block = false
					break
	
	if should_break_block:
		_break_block(id)

### breaker_tiles will all be nonempty and occupied by the same block
func _break_block(id: int) -> void:
	print("break this block")
	#for tile in breaker_tiles:
		#var id_at_tile = get_array(tile.x, tile.y)
