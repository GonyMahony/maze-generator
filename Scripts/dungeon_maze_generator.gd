extends Node2D

enum tile_type {ROOM, WALL, NONE, BOSS, SHOP, ITEM, START}

var maze
var current
@export var steps = 20
@export var chance_to_branch = 0.2
var start_room
var rooms = []
var walls = []
var dead_ends = []
@export var size_x = 10
@export var size_y = 10
var block_size_x = 2 * 16 # to keep 16:9 ratio
var block_size_y = 2 * 9

func _ready() -> void:
	block_size_x = float(get_viewport_rect().size.x) / size_x
	block_size_y = float(get_viewport_rect().size.y) / size_y
	_init_maze(size_x, size_y)
	start_room = maze.get_cell(randi() % size_x, randi() % size_y) #start with random cell
	current = start_room
	map_step()
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.WHITE)

	# Draw maze walls and unvisited blocks
	for x in range(size_x):
		for y in range(size_y):
			var n = maze.get_cell(x, y)
			#draw rooms depending on what room they are
			if not n.visited:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.5, 0.5, 0.5)
				)
			
			if n.type == tile_type.ROOM:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(1.0, 1.0, 1.0, 1.0)
				)
			
			if n.type == tile_type.WALL:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.264, 0.148, 0.062, 1.0)
				)
				
			if n.type == tile_type.ITEM:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.85, 0.589, 0.091, 1.0)
				)
			
			if n.type == tile_type.SHOP:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.237, 0.468, 0.212, 1.0)
				)
			
			if n.type == tile_type.BOSS:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.557, 0.08, 0.187, 1.0)
				)
			
			if n.type == tile_type.START:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.401, 0.065, 0.632, 1.0)
				)
	# Step generator
	#if steps > 0 and current != null:
		#steps -= 1
		#draw_circle(
			#Vector2(current.x * block_size_x + block_size_x / 2,
			#current.y * block_size_y + block_size_y / 2),
			#block_size_x / 2,
			#Color.BLACK
		#)
		#print(rooms.size())
		#print("x: ", current.x, " y: ", current.y)
		#map_step()
	


#region maze logic
func _init_maze(mx: int, my: int) -> void:
	maze = Grid.new(mx, my)

func map_step():
	while steps > 0 and current != null:
		steps -= 1
		if rooms.is_empty():
			rooms.append(current)
			current.type = tile_type.START
		else:
			current = rooms[rooms.size() -1]
			current.type = tile_type.ROOM
		current.visited = true
		var candidates = []
		for n in get_node_neighbors(current):
			if n.visited == false:  #if unvisited add neighbor
				candidates.append(n)
		if candidates.is_empty() or randf() < chance_to_branch : # if there are no unvisited neighbors check places to branch
			# TODO: or maybe random lets see
			var branchable_nodes = find_branchable_nodes()
			for b in branchable_nodes:
				candidates.append(b)
		var next_room = candidates[randi() % candidates.size()] #choose a random room to add
		rooms.append(next_room) #add it to the rooms
		next_room.visited = true #mark as visited
		next_room.type = tile_type.ROOM #change the type to room for branching 
		make_walls(current) #turn neighbors that are not rooms into walls
	
	find_dead_ends()
	if dead_ends.size() < 3:
		map_step()
	spread_rooms()


func make_walls(node: Grid_Node):
	var neighbors = get_node_neighbors(node)
	for n in neighbors:
		if n.type != tile_type.ROOM:
			n.type = tile_type.WALL
			walls.append(n)
		if !n.visited:
			n.visited = true


func find_branchable_nodes():
	# take all walls and see if they have exactly only 1 room as neighbor
	var branchable_nodes = []
	var amount_rooms = 0
	for w in walls: #go through all walls
		for n in get_node_neighbors(w): #go through their neighbors
			if n.type == tile_type.ROOM: #count room neighbors
				amount_rooms += 1
		if amount_rooms == 1: #if there is exactly 1 adjacent room
			branchable_nodes.append(w) #add it to the branchable_rooms
		amount_rooms = 0
	return branchable_nodes


func get_node_neighbors(node: Grid_Node):
	var neighbors = []
	var x = node.x
	var y = node.y
	if x - 1 >= 0: # LEFT
		neighbors.append(maze.get_cell(x - 1, y))
	if x + 1 < maze.x: # RIGHT
		neighbors.append(maze.get_cell(x + 1, y))
	if y - 1 >= 0: # UP
		neighbors.append(maze.get_cell(x, y - 1))
	if y + 1 < maze.y: # DOWN
		neighbors.append(maze.get_cell(x, y + 1))

	return neighbors

func spread_rooms():
	dead_ends[0].type = tile_type.BOSS
	#remove from rooms?
	dead_ends[1].type = tile_type.ITEM
	dead_ends[2].type = tile_type.SHOP
	start_room.type = tile_type.START

func find_dead_ends():
	var walls = 0
	for r in rooms:
		for n in get_node_neighbors(r):
			if n.type == tile_type.WALL:
				walls += 1
		if walls == 3:
			dead_ends.append(r)
		walls = 0


#endregion

#region classes
#Grid
class Grid:
	var x
	var y
	var arr: Array = []
	
	func _init(_size_x: int, _size_y: int):
		x = _size_x
		y = _size_y
		arr = []
		#create the nodes:
		for ix in range(x):
			arr.append([])
			for iy in range(y):
				#make an empty matrix full of nodes
				arr[ix].append(Grid_Node.new(ix, iy))
	
	func get_cell(_x: int, _y: int):
		return arr[_x][_y]

#Node
class Grid_Node:
	var x
	var y
	var visited
	var type
	func _init(_x: int, _y: int):
		x = _x
		y = _y
		visited = false
		type = tile_type.NONE

#endregion
