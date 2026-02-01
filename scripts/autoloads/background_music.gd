extends Node

## Background Music Manager
## Autoload that plays background music continuously, cycling through tracks

signal track_changed(track_index: int, track_name: String)

@export var tracks: Array[AudioStream] = []
@export var shuffle: bool = false ## Randomize track order
@export var crossfade_duration: float = 1.0 ## Seconds to crossfade between tracks

var current_track_index: int = -1
var is_playing: bool = false

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _crossfade_tween: Tween

# Default tracks - loaded in _ready
const DEFAULT_TRACKS := [
	"res://DownloadedAssets/keep-it-kinetic-moire-main-version-00-36-15392.mp3",
	"res://DownloadedAssets/steal-in-60-seconds-moire-main-version-22080-03-12.mp3",
	"res://DownloadedAssets/old-town-moire-main-version-26987-02-02.mp3",
]


func _ready() -> void:
	# Create audio players; PROCESS_MODE_ALWAYS so music plays when tree is
	# paused (e.g. settings menu).
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = &"Music"
	_player_a.process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a.finished.connect(_on_track_finished)
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.bus = &"Music"
	_player_b.process_mode = Node.PROCESS_MODE_ALWAYS
	_player_b.volume_db = -80.0 # Start silent
	add_child(_player_b)

	_active_player = _player_a

	# Load default tracks if none provided
	if tracks.is_empty():
		_load_default_tracks()

	# Auto-start music
	play()


func _load_default_tracks() -> void:
	for path in DEFAULT_TRACKS:
		var stream := load(path) as AudioStream
		if stream:
			tracks.append(stream)
		else:
			push_warning("BackgroundMusic: Failed to load track: %s" % path)


## Start playing music
func play() -> void:
	if tracks.is_empty():
		push_warning("BackgroundMusic: No tracks to play")
		return

	is_playing = true
	_play_next_track()


## Stop playing music
func stop() -> void:
	is_playing = false
	_player_a.stop()
	_player_b.stop()


## Pause music
func pause() -> void:
	_player_a.stream_paused = true
	_player_b.stream_paused = true


## Resume music
func resume() -> void:
	_player_a.stream_paused = false
	_player_b.stream_paused = false


## Skip to next track
func next_track() -> void:
	_play_next_track()


## Skip to previous track
func previous_track() -> void:
	current_track_index -= 2
	if current_track_index < -1:
		current_track_index = tracks.size() - 2
	_play_next_track()


## Set volume (0.0 to 1.0)
func set_volume(volume: float) -> void:
	var db := linear_to_db(clampf(volume, 0.0, 1.0))
	_player_a.volume_db = db
	_player_b.volume_db = db


## Get current track name
func get_current_track_name() -> String:
	if current_track_index >= 0 and current_track_index < tracks.size():
		var stream := tracks[current_track_index]
		if stream.resource_path:
			return stream.resource_path.get_file().get_basename()
	return ""


func _play_next_track() -> void:
	if tracks.is_empty():
		return

	# Determine next track
	if shuffle:
		var new_index := randi() % tracks.size()
		# Avoid repeating same track if possible
		if tracks.size() > 1 and new_index == current_track_index:
			new_index = (new_index + 1) % tracks.size()
		current_track_index = new_index
	else:
		current_track_index = (current_track_index + 1) % tracks.size()

	var next_stream := tracks[current_track_index]

	# Crossfade to next track
	if crossfade_duration > 0 and _active_player.playing:
		_crossfade_to(next_stream)
	else:
		_active_player.stream = next_stream
		_active_player.volume_db = 0.0
		_active_player.play()

	track_changed.emit(current_track_index, get_current_track_name())


func _crossfade_to(next_stream: AudioStream) -> void:
	# Cancel existing crossfade
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	# Determine which player to fade to
	var fade_out_player := _active_player
	var fade_in_player := _player_b if _active_player == _player_a else _player_a

	# Setup fade in player
	fade_in_player.stream = next_stream
	fade_in_player.volume_db = -80.0
	fade_in_player.play()

	# Crossfade
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.tween_property(fade_out_player, "volume_db", -80.0, crossfade_duration)
	_crossfade_tween.tween_property(fade_in_player, "volume_db", 0.0, crossfade_duration)
	_crossfade_tween.chain().tween_callback(fade_out_player.stop)

	_active_player = fade_in_player


func _on_track_finished() -> void:
	if is_playing:
		_play_next_track()
