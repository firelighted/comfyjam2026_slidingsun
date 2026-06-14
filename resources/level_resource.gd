extends Resource
class_name LevelResource

@export var easy_edit_array : Array[String] = ["0,1,2,3", "5,5,4,4", "-1,-1,9,10", "-1,-1,9,10"]
@export var x_size = 4
@export var y_size = 4
@export var goal_tiles : Array[Vector2] = [Vector2.ZERO]
@export var breaker_tiles : Array[Vector2] = []


func initial_array() -> Array[int]:
	var output: Array[int] = [] #[] * 
	for i in range(x_size * y_size):
		output.append(Constants.EMPTY)
	var x = 0
	var y = 0
	for row in easy_edit_array:
		x = 0
		for col in row.split(','):
			output[y * x_size + x] = int(col)
			x += 1
		y += 1
	return output
