extends Area2D
## The campfire cooking station. E opens the cooking panel for its methods.

@export var station_id := "campfire"

@onready var flame: AnimatedSprite2D = $Flame


func _ready() -> void:
	add_to_group("interactable")
	flame.sprite_frames = Art.campfire_frames()
	flame.play(&"burn")


func is_available() -> bool:
	return true


func prompt_text() -> String:
	return "E   Cook at the campfire"


func interact(game: Node) -> void:
	game.open_cooking(station_id)


func methods() -> Array:
	return Array(Data.equipment(station_id).get("methods", []))
