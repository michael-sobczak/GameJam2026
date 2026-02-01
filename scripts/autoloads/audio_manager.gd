## Autoload for playing sound effects throughout the game.
## Access via AudioManager.play_sfx("sfx_name")
extends Node

# Preloaded sound effects
var sfx_inventory_select: AudioStream = preload("res://assets/audio/sfx/inventory_select.ogg")
var sfx_item_use: AudioStream = preload("res://assets/audio/sfx/item_use.ogg")
var sfx_night_vision_on: AudioStream = preload("res://assets/audio/sfx/night_vision_on.ogg")
var sfx_night_vision_off: AudioStream = preload("res://assets/audio/sfx/night_vision_off.ogg")
var sfx_disguise_on: AudioStream = preload("res://assets/audio/sfx/disguise_on.ogg")
var sfx_disguise_off: AudioStream = preload("res://assets/audio/sfx/disguise_off.ogg")
var sfx_guard_alert: AudioStream = preload("res://assets/audio/sfx/guard_alert.ogg")
var sfx_flashlight_toggle: AudioStream = preload("res://assets/audio/sfx/flashlight_toggle.ogg")
var sfx_treasure_pickup: AudioStream = preload(
	"res://Kenny Audio Pack/Audio/confirmation_002.ogg")

# Audio player pool for overlapping sounds
var _audio_players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 8

func _ready() -> void:
	# Create a pool of audio players; PROCESS_MODE_ALWAYS so SFX plays when
	# tree is paused (e.g. settings menu).
	for i in range(MAX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_audio_players.append(player)

## Play a sound effect by name.
func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = null

	match sfx_name:
		"inventory_select":
			stream = sfx_inventory_select
		"item_use":
			stream = sfx_item_use
		"night_vision_on":
			stream = sfx_night_vision_on
		"night_vision_off":
			stream = sfx_night_vision_off
		"disguise_on":
			stream = sfx_disguise_on
		"disguise_off":
			stream = sfx_disguise_off
		"guard_alert":
			stream = sfx_guard_alert
		"flashlight_toggle":
			stream = sfx_flashlight_toggle
		"treasure_pickup":
			stream = sfx_treasure_pickup
		_:
			push_warning("AudioManager: Unknown SFX name: %s" % sfx_name)
			return

	if stream:
		_play_stream(stream, volume_db)

## Play a sound effect stream directly.
func play_stream(stream: AudioStream, volume_db: float = 0.0) -> void:
	_play_stream(stream, volume_db)

## Internal: Find an available player and play the stream.
func _play_stream(stream: AudioStream, volume_db: float) -> void:
	# Find an available player
	for player in _audio_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return

	# If all players are busy, use the first one (interrupting it)
	_audio_players[0].stream = stream
	_audio_players[0].volume_db = volume_db
	_audio_players[0].play()
