## Screen shown after pressing Try Again (defeat). Plays a short community-service
## animation (~2s): player walks across with NPC guards, then transitions to main menu. No dialogue.
extends Node2D

const START_SCREEN_PATH := "res://scenes/menus/start_screen.tscn"

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")

@onready var player_sprite: AnimatedSprite2D = $Stage/PlayerSprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	# Steal SpriteFrames from player scene so we get walk-right etc.
	var temp_player: Node = PLAYER_SCENE.instantiate()
	var player_anim: AnimatedSprite2D = temp_player.get_node_or_null("AnimatedSprite2D")
	if player_anim and player_anim.sprite_frames:
		player_sprite.sprite_frames = player_anim.sprite_frames
	temp_player.queue_free()

	# AnimationPlayer autoplay = "community_service"; connection in scene calls _on_animation_finished


func _on_animation_finished(_anim_name: StringName) -> void:
	_go_to_main_menu()


func _go_to_main_menu() -> void:
	# Silent swap: no loading screen so "Loading... (very slow on Firefox)" only appears on initial start-screen load
	SceneManager.swap_scenes(START_SCREEN_PATH, get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE, false)
