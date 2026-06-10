extends Node2D

@export var block_parent_path : NodePath = "BlockParent"
@export var level_button_parent_path : NodePath = "../UI/LevelButtonParent"
@export var levels_folder_path : String = "res://levels/"
@export var blocks : Array[Node]
@export var levels : Array[LevelResource]
var current_level = 0
var block_prefab: PackedScene = preload("res://scenes_scripts/block.tscn")
var block_parent : Node
var selected_block: Node
var level_button_parent: Node

const EMPTY = -1

var array = [0,1,2,2,4,EMPTY,EMPTY,3,6,6,7]
var level_state: Array[Node]
var x_size: int
var y_size: int
var cells: int

var is_dragging = false

func _ready() -> void:
	if not levels:
		levels = get_levels_from_folder(levels_folder_path)
	
	block_parent = get_node(block_parent_path)
	level_button_parent = get_node(level_button_parent_path)
	# make buttons for choosing level
	var level_button_prefab = preload("res://scenes_scripts/level_button.tscn")
	for i in range(len(levels)):
		var button = level_button_prefab.instantiate()
		button.text = "Level " + str(i)
		button.sibling_button_pressed.connect(receive_level_button_pressed)
		level_button_parent.add_child(button)
	# start level 0
	load_level(0)
	
func load_level(level_idx:int):
	if level_idx < len(levels):
		array = levels[level_idx].initial_array()
		x_size = levels[level_idx].x_size
		y_size = levels[level_idx].y_size
		cells = x_size * y_size
	else:
		print("Using default level, no valid current_level in levels array")
	init_array()
	spawn_blocks()
	
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

#func _unhandled_input(event):
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#if event.is_pressed():
				#print("start drag")
				#drag_start = event.position
				#is_dragging = true
			#else:
				#print("stop drag")
				#drag_end = event.position
				#selected_block.snap_to_position_from_row_col()
				#is_dragging = false


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
				if block_id != EMPTY:
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

# TODO: should probably be linked to block's get_drag method?
func receive_block_want_to_move(block_id, grid_pos, dir):
	pass #print("block want to move")

func receive_block_just_selected(block_id, grid_pos):
	print('receive_block_just_selected')
	for block in block_parent.get_children():
		if (block.block_id == block_id):
			selected_block = block
			block.is_selected = true
			selected_block.is_dragging = false
			
			#var prev_pos = block.grid_pos
			#var new_pos = block.set_row_col_from_pos()
			#
			#print(prev_pos, new_pos)
			#
			## update array NOT WORKING -- wrong values being set
			## set_array(block.i_row, block.i_col, block.block_id)  # doesn't change
			#set_array(prev_pos, new_pos, block.dims, block.block_id)
		#else:
			#block.snap_to_position_from_row_col()
			
		
	print(array)

func receive_block_just_deselected(
	block: Block, prev_pos: Vector2, new_pos: Vector2
):
	update_array(prev_pos, new_pos, block.dims, block.block_id)

func init_array():
	if len(array) < cells - 1: # pad with empty
		for i in range(len(array), cells):
			array.append(EMPTY)
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

func update_array(
	prev_pos: Vector2, new_pos: Vector2, block_dims: Vector2, val: int
):
	var dir = new_pos - prev_pos
	
	# TODO: finish these for loops
	if dir.x == 0:
		# movement in y direction
		for i in block_dims.x:
			var idx = ((new_pos.y + block_dims.y - 1) * x_size) + new_pos.x
			array[idx] = val
		
			var del_idx = (prev_pos.y * x_size) + prev_pos.x
			array[del_idx] = -1
		pass
	elif dir.y == 0:
		# movement in x direction
		for i in block_dims.y:
			var idx = (new_pos.y * x_size) + new_pos.x - (block_dims.x - 1)
			array[idx] = val
		
			var del_idx = (prev_pos.y * x_size) + prev_pos.x
			array[del_idx] = -1
	

func check_move_legality(block_id: int, direction: int) -> bool:
	return true
