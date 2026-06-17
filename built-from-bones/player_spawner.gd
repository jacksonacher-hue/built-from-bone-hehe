extends Node2D
@export var player_scene: PackedScene = preload("res://player.tscn")
func _ready() -> void:
	ensure_player_exists()
func ensure_player_exists():
	print("does player exist")
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		print("no player womp womp")
		var new_player = player_scene.instantiate()
		add_child(new_player)
		new_player.add_to_group("player")
	else:
		print("player is here yippee")
