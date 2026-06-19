extends Node2D

@export var level_button_parent_path : NodePath = "../UI_foreground/LevelButtonParent"
@export var won_level_ui_path: NodePath = "../UI_foreground/Won_Level_UI"
@export var won_game_ui_path: NodePath = "../UI_foreground/Won_Game_UI"
@export var game_moves_counter_label_path: NodePath = "../UI_foreground/Won_Game_UI/VBoxContainer/Moves_This_Game_Label"
@export var sfx_toggle_path : NodePath = "../Settings/SoundToggleCheckButton"
@export var bkgd_toggle_path : NodePath = "../Settings/BkgdToggleCheckButton"

@export var blocks : Array[Block]

@export var levels : Array[Array] = [
	[ # 0
		2,2,3,3,
		0,0,0,1,
		5,6,7,1,
		-1,-1,-1,9
	],
	[ # 1 
		0,1,2,3,
		5,5,4,4,
		-1,-1,9,10,
		-1,-1,9,10,
	],
	[ # 2
		0,1,2,3,
		4,4,5,5,
		6,7,8,8,
		-1,-1,9,10
	],
	[ # 3
		0,1,2,3,
		4,1,5,5,
		4,7,8,8,
		-1,-1,9,10
	],
	[ #4 
		0,1,1,1,
		5,5,4,4,
		-1,2,9,10,
		-1,3,9,10,
	],
	[ # 5
		2,2,3,3,
		0,0,1,1,
		5,-1,-1,-1,
		-1,6,6,6
	],
	[ #6
		0,0,3,3,
		2,2,2,1,
		5,6,7,1,
		-1,-1,-1,9
	],
	[ #7
		-1, -1, -1, -1,
		-1, 1, 1, 1,
		-1, 0, 0, 0,
		2, 2, 2, -1,
	],
	#[
		#-1, -1, -1, -1,
		#-1, -1, -1, -1,
		#-1, 0, 0, 0,
		#-1, -1, -1, -1,
	#],
]


const breaker_tiles_level_0 : Array[Vector2] = [Vector2(1,0), Vector2(2,0)]
const breaker_tiles_level_1 : Array[Vector2] = [Vector2(0, 3), Vector2(1, 3)]
const breaker_tiles_level_2 : Array[Vector2] = [Vector2(2, 0), Vector2(3,0)]
const breaker_tiles_level_3 : Array[Vector2] = [Vector2(0, 2), Vector2(0, 3)]
const breaker_tiles_level_4 : Array[Vector2] = [Vector2(0, 0), Vector2(1,0)]
const breaker_tiles_level_5 : Array[Vector2] = [Vector2(1, 0), Vector2(2,0)]
const breaker_tiles_level_6 : Array[Vector2] = [Vector2(2, 3), Vector2(3,3)]
#const breaker_tiles_level_7 : Array[Vector2] = [Vector2(1, 0), Vector2(2,0)]
# locations for wind breaker tiles in each level
var breaker_tiles_levels = [
	breaker_tiles_level_0,
	breaker_tiles_level_1,
	breaker_tiles_level_2,
	breaker_tiles_level_3,
	breaker_tiles_level_4,
	breaker_tiles_level_5,
	breaker_tiles_level_6,
	#breaker_tiles_level_7
]
var level_move_counts : Array[int] = []
var current_level = 0
var block_prefab: PackedScene = preload("res://scenes_scripts/block.tscn")
var wind_prefab: PackedScene = preload("res://scenes_scripts/wind_sprite.tscn")
var umbrella_prefab: PackedScene = preload("res://scenes_scripts/umbrella.tscn")
@onready var block_parent = $BlockParent
@onready var breaker_parent = $BreakerParent

@onready var audio_sfx = $"../SFXPlayer"
@onready var audio_sfx2 = $"../SFXPlayer2"
@onready var audio_bkgd_music = $"../BkgdMusicPlayer"
@onready var selected_sound = preload("res://audio/deep_woo_desc.wav")
@onready var deselected_sound = preload("res://audio/quick_boop.wav")
@onready var break_block_sound = preload("res://audio/multiboop_convex.wav")
@onready var won_sound = preload("res://audio/won_game_sfx.wav")

var sfx_toggle : Node
var bkgd_toggle : Node

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
var moves_this_level: int = 0

var selected_block: Node


###
### NODE METHODS
###

func _ready() -> void:
	
	bkgd_toggle = get_node(bkgd_toggle_path)
	sfx_toggle = get_node(sfx_toggle_path)
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
	$"../UI_foreground/Won_Level_UI/WonLevelButton".pressed.connect(_on_next_level_button_pressed)
	
	_on_bkgd_music_restart_timer_timeout()
		
	current_level = 0
	load_level(current_level)

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
	if is_instance_valid(selected_block):
		# if a block is already selected, do nothing
		if block.block_id == selected_block.block_id:
			return
		
		# if another block was selected previously, deselect it
		selected_block.end_drag()
		
	selected_block = block
	play_sound(selected_sound)
	

func receive_block_just_deselected(
	block: Block, prev_pos: Vector2, new_pos: Vector2
):
	update_array(prev_pos, new_pos, block.dims, block.block_id)
	check_for_win()
	check_breaker_tiles()
	selected_block = null
	play_sound(deselected_sound)

func play_sound(audio_clip, priority=false):
	if priority:
		audio_sfx.stop()
		if audio_sfx2 and audio_clip and sfx_toggle.button_pressed:
			audio_sfx2.stream = audio_clip
			audio_sfx2.play()
			return
	
		
	if audio_sfx and audio_clip and sfx_toggle.button_pressed:
		audio_sfx.stream = audio_clip
		audio_sfx.play()
	

func _on_next_level_button_pressed() -> void:
	if current_level < len(levels):
		load_level(current_level + 1, true)
	

func _on_reset_level_button_pressed() -> void:
	moves_this_level = 0
	load_level(current_level)


func _on_initial_load_timer_timeout() -> void:
	pass #_ready()#load_level(0)


###
### EVENTS
###

func _on_clickable_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if !event.is_pressed():
				if is_instance_valid(selected_block):
					selected_block.end_drag()


###
### CUSTOM METHODS
###

func update_level_move_counts_ui():	
	
	var moves_this_game = 0
	var idx = 0
	# Tally up moves in other levels 
	for level_moves in level_move_counts:
		if idx != current_level: # only other levels
			moves_this_game += level_moves
		idx += 1
	# Add moves so far this level
	moves_this_game += moves_this_level
	for l in range(len(levels)):
		level_button_parent.get_child(l).get_child(0).text = str(level_move_counts[l]) if level_move_counts[l] else ""
	$"../UI_foreground/HBoxContainer/MoveCounterLabel2".text = str(moves_this_level)
	$"../UI_foreground/HBoxContainer/TotalMoveCounterLabel".text = str(moves_this_game) + " Total Moves"
	game_moves_counter_label.text = str(moves_this_game) + " TOTAL MOVES"

func check_for_win():
	if array[WIN_ARRAY_IDX] == SUN_TILE_IDX:
		if current_level == len(level_move_counts):
			level_move_counts.append(0)
		level_move_counts[current_level] = moves_this_level
		update_level_move_counts_ui()
		print("win")
		play_sound(won_sound)
		if current_level < len(levels) -1:
			won_level_ui.visible = true
		else:
			won_game_ui.visible = true
			

func load_level(level_idx:int, add_to_total: bool=false):
	level_button_parent.get_child(current_level).self_modulate = Color.WHITE
	# record move counts
	if add_to_total:
		level_move_counts[current_level] = moves_this_level
	current_level = level_idx
	if level_idx < len(levels):
		array = levels[level_idx].duplicate(true)
		x_size = 4
		y_size = 4
		breaker_tiles = breaker_tiles_levels[level_idx].duplicate(true)
		#breaker_tiles.append_array(breaker_tiles_outside)
		cells = x_size * y_size
		level_button_parent.get_child(level_idx).self_modulate = Constants.THEME_COLORS[3]
	else:
		push_warning("Using default level, no valid current_level in levels array")
		push_warning("level_idx=" + str(level_idx))
		var level_text = "levels=\n"
		for l in levels:
			level_text += str(l) + "      \n"
		push_warning(levels)
	init_array()
	spawn_blocks()
	spawn_breaker_markers()
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

func spawn_breaker_markers():
	for wind in breaker_parent.get_children():
		wind.queue_free()
	var is_umbrella = true
	for tile in breaker_tiles:
		var wind
		if is_umbrella:
			wind = umbrella_prefab.instantiate()
			wind.started_move.connect(receive_umbrella_started_moving)
		else:
			wind = wind_prefab.instantiate()
		snap_to_position_from_row_col(wind, tile)
		breaker_parent.add_child(wind)
		is_umbrella = not is_umbrella


func receive_umbrella_started_moving():
	check_breaker_tiles()

func snap_to_position_from_row_col(node_to_move: Node, grid_pos, dims_of_node = Vector2(1,1)):
	var new_position = (grid_pos + 0.5 * dims_of_node) * Constants.PIXELS_PER_UNIT
	node_to_move.position = new_position
		

func receive_level_button_pressed(sibling_idx: int):
	load_level(sibling_idx)

### finds a block by its id
func get_block(block_id) -> Block:
	for block in blocks:
		if block.block_id == block_id:
			return block
	
	return null

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

func set_array(val: int, x: int, y: int) -> void:
	var idx = (y * x_size) + x
	array[idx] = val

func increment_move_counters(increment=1):
	moves_this_level += increment
	update_level_move_counts_ui()

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

### will check wether a block is fully on top of the special "breaker" tiles
func check_breaker_tiles():
	var id = Constants.EMPTY
	var should_break_block = true
	
	for tile in breaker_tiles:
		var id_at_tile = get_array(tile.x, tile.y)
		
		if id_at_tile == Constants.EMPTY:
			should_break_block = false
			break
		else:
			if id != id_at_tile:
				if id == Constants.EMPTY:
					id = id_at_tile
				else:
					should_break_block = false
					break
	
	if should_break_block:
		_break_block(id)

### finds the lowest id number that's not being used by a block
func _find_lowest_unoccupied_id() -> int:
	var ids_present = []
	for block in blocks:
		ids_present.push_back(block.block_id)
	
	var i = -1
	while i == -1 or i in ids_present:
		i += 1
	
	return i


### breaks a block down into smaller blocks
### breaker_tiles will all be nonempty and occupied by the same block
### some limitations: logic can't deal with breaking a 2x2 tile with a 2x1 breaker
### breaker_tiles also needs to follow some rules: only 1xn, horizontal, 
### and ordered by x value
func _break_block(id: int) -> void:
	var N = breaker_tiles.size()
	var original_width # width of the original block
	var x_offset # offset of the bottom-left corner of a block from the breaker tile
	
	for i in N:
		var tile = breaker_tiles[i]
		var id_at_tile = get_array(tile.x, tile.y)
		var b: Block = get_block(id_at_tile)
		
		# first loop: take the original block and change it to 1xn
		if i == 0:
			# if the tile is to the left of the breaking tile, then
			# its width should be increased to match
			x_offset = max(tile.x - b.grid_pos.x, 0)
			original_width = b.dims.x
			b.set_variables(id_at_tile, 1 + x_offset, 1, tile.x - x_offset, tile.y)
		else: # second loop: create new blocks and add them to the level
			var new_id = _find_lowest_unoccupied_id()
			set_array(new_id, tile.x, tile.y)
			
			# last iteration
			if i == N - 1:
				var extra = original_width - N - x_offset
				
				# if there are extra tiles to the right, then
				# update their ids in the level array
				for j in extra:
					set_array(new_id, tile.x + j + 1, tile.y)
			
			blocks.push_back(_create_block(new_id, tile.x, tile.y))
			b.show_break()  # particles
			play_sound(break_block_sound, true)
	
	print(array)


func _on_bkgd_music_restart_timer_timeout() -> void:
	
	bkgd_toggle = get_node(bkgd_toggle_path)
	sfx_toggle = get_node(sfx_toggle_path)
	
	audio_bkgd_music.stream_paused = !sfx_toggle.pressed
	if bkgd_toggle.button_pressed: 
		audio_bkgd_music.play()


func _on_bkgd_toggle_check_button_toggled(toggled_on: bool) -> void:
	audio_bkgd_music.stream_paused = !toggled_on
	audio_bkgd_music.volume_db = 0 if toggled_on else -100
	if toggled_on:
		audio_bkgd_music.play()
	else:
		audio_bkgd_music.stop()
