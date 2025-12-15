extends Node3D

var maze
var cell
var visited = 0
@export var steps = 1000
var path = []
@export var size_x = 15
@export var size_y = 15
var block_size_x = 0.5 * 16 # to keep 16:9 ratio
var block_size_y = 0.5 * 9
var block_height = 2.0

func _ready() -> void:
	_init_maze(size_x, size_y)
	visited = 0
	calculate_maze()
	build_maze()

func calculate_maze():
	cell = maze.get_cell(0, 0)
	cell.visited = true
	path.append(cell)  # Start the path at (0,0)
	#step generator
	while visited < size_x * size_y and steps > 0 and cell != null:
		steps -= 1
		next_step()


func build_maze():
	make_floor()
	maze.get_cell(0,0).walls["n"] = false # make an entrance
	#maze.get_cell(0,0).walls["s"] = false
	#maze.get_cell(0,1).walls["n"] = false
	for x in range(size_x):
		for y in range(size_y):
			var n = maze.get_cell(x, y)

			if n.has_wall("n"):
				#make a block north of here that is a wall
				create_block_between_points(
					Vector3(x * block_size_x, 0, y * block_size_y),
					Vector3((x + 1) * block_size_x, block_height, y * block_size_y)
				)
			if n.has_wall("w"):
				#block west
				create_block_between_points(
					Vector3(x * block_size_x, 0, y * block_size_y),
					Vector3(x * block_size_x, block_height, (y+1) * block_size_y)
				)
			if n.has_wall("e"):
				create_block_between_points(
					Vector3((x + 1) * block_size_x, 0, y * block_size_y),
					Vector3((x + 1) * block_size_x, block_height, (y + 1) * block_size_y)
				)
			if n.has_wall("s"):
				create_block_between_points(
					Vector3(x * block_size_x, 0, (y + 1) * block_size_y),
					Vector3((x + 1) * block_size_x, block_height, (y + 1) * block_size_y)
				)


func draw_border_walls():

	# TOP BORDER (north, y = 0)
	for x in range(size_x):
		create_block_between_points(
			Vector3(x * block_size_x, 0, 0),
			Vector3((x + 1) * block_size_x, block_height, 0)
		)

	# BOTTOM BORDER (south, y = size_y)
	for x in range(size_x):
		create_block_between_points(
			Vector3(x * block_size_x, 0, size_y * block_size_y),
			Vector3((x + 1) * block_size_x, block_height, size_y * block_size_y)
		)

	# LEFT BORDER (west, x = 0)
	for y in range(size_y):
		create_block_between_points(
			Vector3(0, 0, y * block_size_y),
			Vector3(0, block_height, (y + 1) * block_size_y)
		)

	# RIGHT BORDER (east, x = size_x)
	for y in range(size_y):
		create_block_between_points(
			Vector3(size_x * block_size_x, 0, y * block_size_y),
			Vector3(size_x * block_size_x, block_height, (y + 1) * block_size_y)
		)


func make_floor():
	create_block_between_points(
		Vector3(0, -1* block_size_x, 0),
		Vector3(size_x * block_size_x, 0, size_y * block_size_y)
	)

func create_block_between_points(point_a: Vector3, point_b: Vector3, wall_thickness := 0.2) -> StaticBody3D:
	var size = (point_b - point_a).abs()
	var center = (point_a + point_b) * 0.5

	# Adjust thickness
	if size.x < size.z:
		size.x = wall_thickness
	else:
		size.z = wall_thickness
	
	# Create StaticBody3D
	var wall = StaticBody3D.new()
	wall.transform.origin = center
	add_child(wall)
	#create mesh with appropriate size
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	#apply it
	var block = MeshInstance3D.new()
	block.mesh = box_mesh
	block.transform.origin = Vector3.ZERO
	wall.add_child(block)
	
	# Create collision shape
	var shape = BoxShape3D.new()
	shape.size = size # half-extents
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.transform.origin = Vector3.ZERO  # local to wall
	wall.add_child(collision)
	return wall






#region maze logic
func _init_maze(mx: int, my: int) -> void:
	maze = Grid.new(mx, my)

func next_step():
	#while there are unvisited cells:
	if path.size() == 0:
		#pick a random unvisited starting point
		cell = get_valid_path_start()
		if cell == null: return # bad way to end the algorithm
		path.append(cell)
		cell.visited = true
		visited += 1
	
	#pick a random neighbor with random walk
	random_walk()
	cell = path[path.size() -1]
	if cell.visited:
		add_path_to_maze()
		path.clear()
		var c = hunt_next_cell()
		if c != null:
			path.append(c)
	else:
		cell.visited = true
		visited += 1


# selects a random unvisited cell
func get_valid_path_start():
	var cells = []
	for x in range(maze.cols):
		for y in range(maze.rows):
			#if its unvisited, append it
			if !maze.get_cell(x,y).visited: cells.append(maze.get_cell(x,y))
	
	# return null if empty and random in range(modulo) of cells size
	if cells.is_empty():
		return null
	return cells[randi() % cells.size()]

func hunt_next_cell():
	#find a random cell neighboring a visited one
	var cells = []
	for x in range(maze.cols):
		for y in range(maze.rows):
			#if its unvisited, append it
			if !maze.get_cell(x,y).visited: cells.append(maze.get_cell(x,y))
	cells.shuffle()
	for c in cells:
		var neighbors = c.get_neighbors()
		for n in neighbors:
			if n.neighbor.visited:
				n.edge.is_wall = false
				return c
	return null


func random_walk():
	var last = path[path.size() -1]
	var neighbors = last.get_neighbors()
	var candidates = []
	for n in neighbors:
		if !n.neighbor.visited:
			#if a neighbor is unvisited add it as a candidate
			candidates.append(n)
	if candidates.size() > 0 : neighbors = candidates #either move on or use another candidate
	var pick = neighbors[randi() % neighbors.size()]
	path.append(pick.neighbor)

func add_path_to_maze():
	path[0].visited = true #first set 0 to visited
	for i in range(1, path.size()-1): #range instead of "for i in path" so we have a and b
		var a = path[i] #current cell
		var b = path[i-1] #last cell
		a.visited = true #we visited this cell
		for e in a.edges: #set the wall in between to false
			if e.is_connecting_nodes(a, b): e.is_wall = false


#endregion

#region classes
#Grid
class Grid:
	var rows
	var cols
	var edges: Array = []
	var arr: Array = []
	
	func _init(_size_x: int, _size_y: int):
		rows = _size_y
		cols = _size_x
		edges = []
		arr = []
		#create the nodes:
		for r in range(rows):
			arr.append([])
			for c in range(cols):
				#make an empty matrix full of nodes
				arr[r].append(Grid_Node.new(c, r))
		
		#create all edges
		for r in range(rows):
			for c in range(cols):
				if r < rows - 1:
					#add edge south
					var e = Grid_Edge.new(arr[r][c], arr[r+1][c])
					edges.append(e)
				else: arr[r][c].walls["s"] = true   # bottom border
				if c < cols -1:
					var e = Grid_Edge.new(arr[r][c], arr[r][c+1])
					edges.append(e)
				else: arr[r][c].walls["e"] = true   # right border
		
		
	
	func get_cell(x: int, y: int):
		return arr[y][x]

#Node
class Grid_Node:
	var col
	var row
	var visited
	var edges: Array = []
	var walls = {
		"s": true,
		"n": true,
		"e": true,
		"w": true
	}
	func _init(_x: int, _y: int):
		col = _x
		row = _y
		visited = false
	
	func add_edge(new_edge):
		edges.append(new_edge)
	
	func has_wall(direction): #needs to be "s", "n",...
		self.evaluate_walls()
		return self.walls[direction]
	
	func get_neighbors():
		var neighbors: Array = []
		for e in edges:
			var other_node = e.a
			if self == other_node :
				other_node = e.b
			neighbors.append({"edge": e, "neighbor": other_node})
		return neighbors
	
	func get_unvisited_neighbors():
		var neighbors: Array = []
		for e in edges:
			var other_node = e.a
			if self == other_node :
				other_node = e.b
			if !other_node.visited:
				neighbors.append({"edge": e, "neighbor": other_node})
		return neighbors
	
	func evaluate_walls():
		for e in edges:
			#for every node get another node
			var other_node = e.a
			if self == other_node : #if that one is ourself, take the other
				other_node = e.b
			
			if row == other_node.row:
				#same row = horizontal i.e. east or west
				if col < other_node.col:
					walls["e"] = e.is_wall
				else:
					walls["w"] = e.is_wall
			else: #same column so check north or south
				if row < other_node.row:
					walls["s"] = e.is_wall
				else:
					walls["n"] = e.is_wall

#Edge
class Grid_Edge:
	var a
	var b
	var is_wall;
	func _init(node_a: Grid_Node, node_b: Grid_Node):
		a = node_a
		b = node_b
		a.add_edge(self)
		b.add_edge(self)
		is_wall = true
	
	func is_connecting_nodes(node_a, node_b):
		if((a == node_a && b == node_b) || (a == node_b && b == node_a)):
			return true
		return false
#endregion
