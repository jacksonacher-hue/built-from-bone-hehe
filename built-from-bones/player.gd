extends CharacterBody2D

@export var speed := 400.0
@export var sprint_speed := 800.0
@export var jump_velocity := 600.0
@export var gravity := 900.0
@export var death_y = 1000
@export var acceleration := 1200.0
@export var friction := 800.0
@export var show_debug_arrows := true
var dead = false
var last_floor_normal := Vector2.UP

# Debug arrow nodes
var arrow_jump: Line2D
var arrow_left: Line2D
var arrow_right: Line2D

func _ready():
	# Crucial adjustment: turn off standard floor processing rules 
	# because we are overriding them manually below.
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(180)
	floor_snap_length = 32.0
	
	if show_debug_arrows:
		arrow_jump = create_arrow(Color.GREEN)
		arrow_left = create_arrow(Color.RED)
		arrow_right = create_arrow(Color.RED)

func create_arrow(color: Color) -> Line2D:
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.z_index = 100
	add_child(line)
	return line

func update_arrow(arrow: Line2D, direction: Vector2, length: float):
	if length < 5.0:
		arrow.clear_points()
		return
		
	var end = direction * length
	var head_size = 10.0
	var perp = direction.rotated(PI/2) * head_size * 0.5
	
	arrow.clear_points()
	arrow.add_point(Vector2.ZERO)
	arrow.add_point(end)
	arrow.add_point(end - direction * head_size + perp)
	arrow.add_point(end)
	arrow.add_point(end - direction * head_size - perp)

func _physics_process(delta):
	# 1. Track environmental orientation safely
	if is_on_floor():
		last_floor_normal = get_floor_normal()
		up_direction = last_floor_normal
		
		# VISUAL SMOOTHING: Calculate where the sprite SHOULD face
		var target_rotation = last_floor_normal.angle() + PI/2
		
		# We check if the angle change is massive (like an instant 90-degree snap).
		# If it is a sudden snap, we slow down the interpolation weight so it doesn't jitter.
		var angle_difference = abs(angle_difference(rotation, target_rotation))
		var rotation_speed = 8.0 if angle_difference > 0.5 else 25.0
		
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	else:
		up_direction = last_floor_normal
		velocity += -last_floor_normal * gravity * delta
		
		# Smoothly ease back to a stable angle if you fly off a corner into the air
		var target_rotation = last_floor_normal.angle() + PI/2
		rotation = lerp_angle(rotation, target_rotation, 10.0 * delta)

	# 2. Process Input Directions
	var input_dir = Input.get_axis("move_left", "move_right")
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else speed

	# 3. Project velocity cleanly into local 2D space relative to current VISUAL rotation
	# Using the actual smoothed transform prevents the velocity vector from jittering with the collision normal
	var local_velocity_x = velocity.dot(transform.x)
	var local_velocity_y = velocity.dot(transform.y)

	# 4. Handle Sideways Movement / Friction
	if input_dir != 0:
		local_velocity_x = move_toward(local_velocity_x, input_dir * current_speed, acceleration * delta)
	else:
		local_velocity_x = move_toward(local_velocity_x, 0, friction * delta)

	# 5. Handle Jump Action
	if Input.is_action_just_pressed("jump") and is_on_floor():
		local_velocity_y = -jump_velocity
		floor_snap_length = 0.0
	else:
		if is_on_floor():
			# Slightly increased downward force to compress the collision box firmly into the corner
			local_velocity_y = 150.0 
		floor_snap_length = 32.0

	# 6. Reconstruct the global velocity vector
	velocity = (transform.x * local_velocity_x) + (transform.y * local_velocity_y)
	
	# Update debug arrows based on actual movement
	if show_debug_arrows:
		var local_floor_normal = last_floor_normal.rotated(-rotation)
		var local_move_dir = local_floor_normal.rotated(-PI/2)
		var floor_velocity = velocity.dot(last_floor_normal.rotated(-PI/2))
		var arrow_scale = 0.1
		
		if floor_velocity > 5.0:
			update_arrow(arrow_right, local_move_dir, floor_velocity * arrow_scale)
		else:
			arrow_right.clear_points()
		
		if floor_velocity < -5.0:
			update_arrow(arrow_left, -local_move_dir, abs(floor_velocity) * arrow_scale)
		else:
			arrow_left.clear_points()
		
		var jump_velocity_component = velocity.dot(last_floor_normal)
		if jump_velocity_component > 10.0:
			update_arrow(arrow_jump, local_floor_normal, jump_velocity_component * arrow_scale)
		else:
			arrow_jump.clear_points()
	
	# Execute movement
	move_and_slide()
	
	# Death collisions
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider != null and collider.is_in_group("fatal"):
			die()

		if collider is RigidBody2D:
			var body = collider
			if not body.freeze:
				var push_force = 1000
				body.apply_central_impulse(-collision.get_normal() * push_force * delta)

func die():
	if dead: return
	dead = true
	Death.die(global_position)
	queue_free()
