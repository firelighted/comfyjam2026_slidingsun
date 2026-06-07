extends Node2D

@export var block_parent_path : NodePath = "BlockParent"
@export var level_button_parent_path : NodePath = "../UI/LevelButtonParent"
@export var blocks : Array[Node]
@export var levels : Array[LevelResource]
var current_level = 0
var block_prefab: PackedScene = preload("res://scenes_scripts/block.tscn")
var block_parent : Node
var selected_block: Node
var level_button_parent: Node

const EMPTY = -1

var array = [0,1,2,2,4,EMPTY,EMPTY,3, 6,6,7]
var x_size = 4
var y_size = 5
var cells  = x_size * y_size

var is_dragging = false

func _ready() -> void:
	
	block_parent = get_node(block_parent_path)
	level_button_parent = get_node(level_button_parent_path)
	var level_button_script = load("res://scenes_scripts/sibling_button.gd")
	for i in range(len(levels)):
		var button = Button.new()
		button.script = level_button_script
		button.set_script(level_button_script)
		button.text = str(i)
		button.sibling_button_pressed.connect(receive_level_button_pressed)
		level_button_parent.add_child(button)
	
	load_level(0)
	
func load_level(new_level:int):
	current_level = new_level
	if current_level < len(levels):
		array = levels[current_level].initial_array()
		x_size = levels[current_level].x_size
		y_size = levels[current_level].y_size
	else:
		print("Using default level, no valid current_level in levels array")
	init_array()
	spawn_blocks()
	
func receive_level_button_pressed(sibling_idx: int):
	load_level(sibling_idx)

func _process(delta):
	if selected_block:
		selected_block.is_dragging = is_dragging

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

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				print("start drag")
				drag_start = event.position
				is_dragging = true
			else:
				print("stop drag")
				drag_end = event.position
				is_dragging = false
			


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
				# print("(%d, %d) -> %d" % [x, y, block_id])
				if block_id != EMPTY:
					blocks.push_back(_create_block(block_id, x, y))
					complete_blocks.push_back(block_id)

func _create_block(block_id, row, col):
	var block = block_prefab.instantiate()
	block.set_variables(block_id, get_block_width(block_id), get_block_height(block_id), row, col)
	block_parent.add_child(block)
	block.want_to_move.connect(receive_block_want_to_move)
	block.just_selected.connect(receive_block_just_selected)
	return block

func receive_block_want_to_move(block_id, row, col, dir):
	pass #print("block want to move")

func receive_block_just_selected(block_id, row, col):
	for block in block_parent.get_children():
		block.is_selected = (block.block_id == block_id)

		if (block.block_id == block_id):
			if selected_block:
				selected_block.is_dragging = false # finish old drag
			selected_block = block
			selected_block.is_dragging = false
		else:
			block.snap_to_position_from_row_col()
		var row_col = block.set_row_col_from_pos()
		
		# update array NOT WORKING -- wrong values being set
		# set_array(block.i_row, block.i_col, block.block_id)  # doesn't change
		set_array(row_col.x, row_col.y, block.block_id)
	print_array()

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

func set_array(x: int, y: int, val: int):
	var idx = (y * x_size) + x
	array[idx] = val
