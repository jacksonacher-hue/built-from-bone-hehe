extends Node

@export var corpse_scene: PackedScene = preload("res://corpse.tscn")
@export var frozen_corpse_scene: PackedScene = preload("res://frozen_corpse.tscn")

var save_path := "user://corpses.save"

var save_data = {
	"corpses": []
}

func _ready():
	load_from_file()
	get_tree().scene_changed.connect(_on_scene_changed)

func _on_scene_changed():
	await get_tree().process_frame
	var scene = get_tree().current_scene
	load_corpses_if_valid_scene(scene)

func load_corpses_if_valid_scene(scene):
	if scene == null:
		return
	
	if scene.scene_file_path != "res://touchdown.tscn":
		return
	
	# Clear existing corpses first
	for child in get_children():
		child.queue_free()
	
	print("Loading ", save_data["corpses"].size(), " corpses")
	
	for i in range(save_data["corpses"].size()):
		var c = save_data["corpses"][i]
		
		# Skip corpses that are fully decayed
		if c.get("decay", 0) >= 100:
			continue
		
		var corpse = frozen_corpse_scene.instantiate()
		corpse.global_position = c["pos"]
		corpse.global_rotation = c["rot"]
		corpse.decay = c.get("decay", 0)
		corpse.name = "Corpse_" + str(i)
		add_child(corpse)
		corpse.setup(i)
	
	print("✅ Loaded ", get_child_count(), " frozen corpses")

# ☠️ Death function
func die(pos: Vector2):
	# Increment decay on all existing corpses
	increment_all_corpse_decay()
	
	var corpse = corpse_scene.instantiate()
	corpse.global_position = pos
	get_tree().current_scene.add_child(corpse)

	var result = await corpse.fall()

	save_data["corpses"].append({
		"pos": result["pos"],
		"rot": result["rot"],
		"decay": 0  # New corpse starts at 0 decay
	})

	save_to_file()
	corpse.queue_free()

	print("💀 Saved corpse #", save_data["corpses"].size(), " at ", result["pos"])
	remove_corpses()
	get_tree().change_scene_to_file("res://title_screen.tscn")

# Increment decay on all corpses by 10
func increment_all_corpse_decay():
	var corpses_to_remove = []
	
	for i in range(save_data["corpses"].size()):
		save_data["corpses"][i]["decay"] += 6
		
		# Mark for removal if fully decayed
		if save_data["corpses"][i]["decay"] >= 100:
			corpses_to_remove.append(i)
	
	# Remove fully decayed corpses (backwards to avoid index issues)
	for i in range(corpses_to_remove.size() - 1, -1, -1):
		save_data["corpses"].remove_at(corpses_to_remove[i])
	
	save_to_file()
	
	if corpses_to_remove.size() > 0:
		print("🗑️ Removed ", corpses_to_remove.size(), " fully decayed corpses")
func remove_corpses():
	for corpse in get_tree().get_nodes_in_group("corpses"):
		corpse.queue_free()
		print("corpse gone")
# 💾 SAVE
func save_to_file():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(save_data)

# 📂 LOAD
func load_from_file():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		save_data = file.get_var()
		print("📂 Loaded save with ", save_data["corpses"].size(), " corpses")

func full_reset():
	save_data = {
		"corpses": []
	}

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	# Clear all corpses
	for child in get_children():
		child.queue_free()

	print("🔄 Full reset done.")	
