extends RigidBody2D

var corpse_index := -1
var decay = 0

func _ready():
	# Make completely static - no physics at all
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	
	# Disable all physics properties
	can_sleep = false
	sleeping = true
	contact_monitor = false
	
	# Set initial opacity based on decay
	update_opacity()

# Called after add_child()
func setup(new_index: int):
	corpse_index = new_index
	
	# Ensure it stays frozen
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	
	update_opacity()
	
	await get_tree().physics_frame

func update_opacity():
	# Fade from 100% to 0% as decay goes from 0 to 100
	var opacity = 1.0 - (decay / 100.0)
	modulate.a = clamp(opacity, 0.0, 1.0)
	
	# If fully decayed, remove it
	if decay >= 100:
		remove_from_save()
		queue_free()

func remove_from_save():
	if corpse_index >= 0 and corpse_index < Death.save_data["corpses"].size():
		Death.save_data["corpses"].remove_at(corpse_index)
		Death.save_to_file()
		
		# Update indices for corpses after this one
		for child in Death.get_children():
			if child is RigidBody2D and "corpse_index" in child:
				if child.corpse_index > corpse_index:
					child.corpse_index -= 1
