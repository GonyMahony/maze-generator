extends Node2D

enum tile_type {ROOM, WALL, NONE, START, NURSERY, WATER, CARPENTER, FOOD, QUEEN}

var maze
var current
@export var initial_steps = 20
var steps = 0
@export var chance_to_branch = 0.2
var start_room
var start_branches = []
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
	generate_map()
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
					Color(0.408, 0.246, 0.076, 1.0)
				)
			
			if n.type == tile_type.WALL:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.23, 0.126, 0.049, 1.0)
				)
				
			if n.type == tile_type.QUEEN:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(1.0, 0.004, 0.0, 1.0)
				)
				
				
			if n.type == tile_type.NURSERY:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.79, 0.214, 0.53, 1.0)
				)
			
			if n.type == tile_type.FOOD:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.302, 0.455, 0.203, 1.0)
				)
			
			if n.type == tile_type.CARPENTER:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.313, 0.318, 0.065, 1.0)
				)
			
			if n.type == tile_type.WATER:
				draw_rect(
					Rect2(x * block_size_x, y * block_size_y, block_size_x, block_size_y),
					Color(0.209, 0.477, 0.685, 1.0)
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
	rooms.clear()
	walls.clear()
	dead_ends.clear()
	steps = initial_steps
	maze = Grid.new(mx, my)
	#start with random cell away from borders
	init_start_room()
	current = start_room

func generate_map():
	while true:
		# Reset state
		_init_maze(size_x, size_y)

		# Generate
		map_step()

		# Detect dead ends
		find_dead_ends()
		
		for d in dead_ends:
			print(d.x, ", ", d.y)

		# Stop when we have enough dead ends
		if dead_ends.size() >= 5:
			spread_rooms()
			break



func map_step():
	while steps > 0 :#and current != null: #if we made enough rooms or we cannot make more we stop
		steps -= 1
		
		#--------setup for node----------
		if rooms.is_empty():
			rooms.append(current)
			#current.type = tile_type.START
		else:
			current = rooms[rooms.size() -1]
			#current.type = tile_type.ROOM #should already be a room if its not start
		current.visited = true
		
		#------------check for candidates for next room---------------
		var candidates = []
		for n in get_node_neighbors(current):
			if n.visited == false:  #if unvisited add neighbor
				candidates.append(n)
		if candidates.is_empty() or randf() < chance_to_branch : # if there are no unvisited neighbors check places to branch
			var branchable_nodes = find_branchable_nodes()
			if branchable_nodes.is_empty(): # if there are no more branchable nodes were done
				break
			else: 
				for b in branchable_nodes:
					candidates.append(b)
		
		#----- set up stuff with the next room
		var next_room = candidates[randi() % candidates.size()] #choose a random room to add
		rooms.append(next_room) #add it to the rooms
		next_room.visited = true #mark as visited
		next_room.type = tile_type.ROOM #change the type to room for branching 
		make_walls(current) #turn neighbors that are not rooms into walls
		#make_walls(next_room) #this would be wrong because we would not continue anywhere, if all neighbors are walls
	
	var last_room = rooms[rooms.size() -1]
	make_walls(last_room)



func init_start_room(): #choose a random start room and add 4 neighbors as rooms to it
	start_room = maze.get_cell((randi() % size_x -2)+1, (randi() % size_y -2)+1)
	start_room.type = tile_type.ROOM #make it a room until the end
	steps -= 1
	for n in get_node_neighbors(start_room):
		steps -= 1
		rooms.append(n)
		start_branches.append(n)
		n.type = tile_type.ROOM
		n.visited = true
		make_walls(n)

func make_walls(node: Grid_Node):
	var neighbors = get_node_neighbors(node)
	for n in neighbors:
		if n.type == tile_type.NONE: #check for unused cells
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
			if n.type == tile_type.ROOM || n.type == tile_type.START: #count room neighbors
				amount_rooms += 1
		if amount_rooms == 1: #if there is exactly 1 adjacent room
			branchable_nodes.append(w) #add it to the branchable_rooms
		amount_rooms = 0
	for b in start_branches:
		if !b.visited:
			branchable_nodes.append(b)
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

func get_room_neighbors(node: Grid_Node) -> Array:
	var neighbors := []

	for n in get_node_neighbors(node):
		# Any tile that is not a WALL or NONE is walkable
		if n.type != tile_type.WALL and n.type != tile_type.NONE:
			neighbors.append(n)

	return neighbors


func spread_rooms():
	dead_ends[0].type = tile_type.QUEEN #0 is already the furthest so remove it
	print("Queen set at: ", dead_ends[0].x, ", ", dead_ends[0].y)
	dead_ends.remove_at(0) #remove from rooms
	
	var i = randi_range(0, dead_ends.size()-1)
	dead_ends[i].type = tile_type.WATER
	print("water set at: ", dead_ends[i].x, ", ", dead_ends[i].y)
	dead_ends.remove_at(i)
	
	i = randi_range(0, dead_ends.size()-1)
	dead_ends[i].type = tile_type.CARPENTER
	print("Carpenter set at: ", dead_ends[i].x, ", ", dead_ends[i].y)
	dead_ends.remove_at(i)
	
	i = randi_range(0, dead_ends.size()-1)
	dead_ends[i].type = tile_type.NURSERY
	print("Nursery set at: ", dead_ends[i].x, ", ", dead_ends[i].y)
	dead_ends.remove_at(i)
	
	i = randi_range(0, dead_ends.size()-1)
	dead_ends[i].type = tile_type.FOOD
	print("Food set at: ", dead_ends[i].x, ", ", dead_ends[i].y)
	dead_ends.remove_at(i)
	
	start_room.type = tile_type.START
	print("start set")



func find_dead_ends():
	var room_count = 0
	for r in rooms:
		for n in get_node_neighbors(r):
			if n.type == tile_type.ROOM:
				room_count += 1
		if room_count == 1 && !dead_ends.has(r): #if it is already in there dont add it
			dead_ends.append(r)
			#rooms.erase(r)
		room_count = 0
	#now we order them by distance to the start point:
	var furthest_dead_end = find_furthest_dead_end_from_start(start_room)
	dead_ends.erase(furthest_dead_end) # remove it from wherever it is
	dead_ends.insert(0, furthest_dead_end) # put it at the front

#TODO: review this
func find_furthest_dead_end_from_start(start: Grid_Node) -> Grid_Node:
	# ------------------------------------------------------------------
	# Breadth-First Search (BFS) starting from the START room
	# Goal:
	#   Find which DEAD-END room has the greatest walking distance
	#   (number of room-to-room steps) from the start room.
	#
	# Assumptions:
	#   - 'start' is a valid room (type START or ROOM)
	#   - 'dead_ends' array is already populated
	#   - Rooms are connected orthogonally (no diagonals)
	# ------------------------------------------------------------------

	# Queue for BFS.
	# Rooms are explored in the order they are discovered.
	# This guarantees shortest-path distances.
	var queue := []

	# Dictionary mapping:
	#   Grid_Node -> distance from START
	# This also serves as a "visited" set.
	var distance := {}

	# Begin BFS at the start room.
	queue.append(start)
	distance[start] = 0

	# Track the furthest dead end found so far.
	# Initialized to null because we haven't found any yet.
	var furthest_dead_end: Grid_Node = null

	# Track the maximum distance encountered among dead ends.
	# Start at -1 so any valid distance (>= 0) will replace it.
	var max_distance := -1

	# --------------------------------------------------------------
	# Main BFS loop
	# --------------------------------------------------------------
	while queue.size() > 0:
		# Remove the oldest room from the queue.
		# This enforces BFS (not DFS).
		var current: Grid_Node = queue.pop_front()

		# Iterate over all walkable neighboring rooms.
		# Walls and NONE tiles are excluded.
		for n in get_room_neighbors(current):
			# If this neighbor is NOT in the distance map,
			# it means we have never visited it before.
			if not distance.has(n):
				# Set the neighbor's distance.
				# It is exactly one step further than the current room.
				distance[n] = distance[current] + 1

				# Add the neighbor to the queue so its neighbors
				# will be explored later.
				queue.append(n)

				# --------------------------------------------------
				# Check if this room is a dead end
				# --------------------------------------------------
				# We ONLY care about dead ends for the final result,
				# but we still BFS through all rooms so distances
				# remain correct.
				if dead_ends.has(n):
					# If this dead end is further than any we have
					# seen so far, update the result.
					if distance[n] > max_distance:
						max_distance = distance[n]
						furthest_dead_end = n

	# --------------------------------------------------------------
	# BFS is complete.
	# At this point:
	#   - All reachable rooms have a correct distance value
	#   - 'furthest_dead_end' is the dead end with the
	#     greatest walking distance from START
	# --------------------------------------------------------------
	return furthest_dead_end


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
