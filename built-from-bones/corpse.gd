extends RigidBody2D

var settled := false
var decay = 0

func _ready():
	# Enable contact monitoring so the code can read what it collides with
	contact_monitor = true
	max_contacts_reported = 4
	
	# Start with low friction for a natural fall/roll
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = 0.3
	physics_material.rough = false
	physics_material_override = physics_material

func _integrate_forces(state: PhysicsDirectBodyState2D):
	# Skip custom alignment if already settled or frozen
	if settled or freeze:
		return

	# Look through all active collisions to find the ground
	if state.get_contact_count() > 0:
		# Use the first contact point's normal
		var contact_normal = state.get_contact_local_normal(0)
		
		# If the normal is pointing mostly upwards, treat it like a floor
		if contact_normal.dot(Vector2.UP) > 0.5:
			# Calculate the exact target angle to snap cleanly to the slope
			var target_rotation = contact_normal.angle() + PI/2
			
			# Smoothly lerp the rotation to match the surface, just like the player
			var step_lerp = lerp_angle(global_rotation, target_rotation, 15.0 * state.step)
			state.transform = Transform2D(step_lerp, global_position)

func fall() -> Dictionary:
	settled = false
	sleeping = false
	freeze = false
	
	# 1. Wait until the physics engine brings the corpse to a functional stop
	while not settled:
		await get_tree().physics_frame
		
		# Low velocity thresholds mean it has landed and stopped rolling/sliding
		if linear_velocity.length() < 15.0 and abs(angular_velocity) < 0.1:
			settled = true
	
	# 2. Wait exactly 2 seconds while resting before finalizing
	await get_tree().create_timer(2.0).timeout
	
	# 3. Increase friction massively so it behaves like a solid, stable platform
	var high_friction_material = PhysicsMaterial.new()
	high_friction_material.friction = 1.0
	high_friction_material.rough = true
	physics_material_override = high_friction_material
	
	# Freeze the physics simulation entirely so the player can safely stand on it
	freeze = true
	
	return {
		"pos": global_position,
		"rot": global_rotation,
		"decay": 0
	}
