class_name SettingsMenu extends CanvasLayer

# opening this menu pauses the game, so you don't have to worry about blocking input
# from anything underneath it
signal language_changed(language: String)

@onready var master_slider: HSlider = %MasterSlider as HSlider
@onready var music_slider: HSlider = %MusicSlider as HSlider
@onready var sfx_slider: HSlider = %SFXSlider as HSlider
@onready var language_dropdown: OptionButton = %LanguageDropdown as OptionButton
@onready var close_button: Button = %CloseButton as Button
@onready var MASTER_BUS_ID: int = AudioServer.get_bus_index("Master")
@onready var SFX_BUS_ID: int = AudioServer.get_bus_index("SFX")
@onready var MUSIC_BUS_ID: int = AudioServer.get_bus_index("Music")

var user_prefs: UserPrefs

var _prev_tree_paused := false


func _ready():
	# load (or create) file with these saved preferences
	user_prefs = UserPrefs.load_or_create()

	# set saved values (will be default values if first load)
	if master_slider:
		master_slider.value = user_prefs.master_volume
	if music_slider:
		music_slider.value = user_prefs.music_volume
	if sfx_slider:
		sfx_slider.value = user_prefs.sfx_volume
	if language_dropdown:
		var lang = Globals.get_selected_language()
		var lang_index = Const.LANGUAGES.find(lang)
		language_dropdown.selected = lang_index

func close_settings() -> void:
	Globals.settings_menu = null
	var pause_menu: Node = get_tree().get_first_node_in_group(PauseMenu.PAUSE_MENU_GROUP)
	if pause_menu is PauseMenu:
		(pause_menu as PauseMenu).return_focus()
	queue_free()

func _on_close_button_pressed():
	AudioManager.play_sfx("inventory_select")
	close_settings()

func _on_master_slider_value_changed(_value: float) -> void:
	AudioServer.set_bus_volume_db(MASTER_BUS_ID, linear_to_db(_value))
	AudioServer.set_bus_mute(MASTER_BUS_ID, _value < .05)
	user_prefs.master_volume = _value

func _on_music_slider_value_changed(_value):
	AudioServer.set_bus_volume_db(MUSIC_BUS_ID, linear_to_db(_value))
	AudioServer.set_bus_mute(MUSIC_BUS_ID, _value < .05)
	user_prefs.music_volume = _value

func _on_sfx_slider_value_changed(_value):
	AudioServer.set_bus_volume_db(SFX_BUS_ID, linear_to_db(_value))
	AudioServer.set_bus_mute(SFX_BUS_ID, _value < .05)
	user_prefs.sfx_volume = _value

func _on_language_dropdown_item_selected(_index):
	var lang = Const.LANGUAGES[_index]
	user_prefs.language = lang
	language_changed.emit(lang)

func _notification(what):
	match what:
		NOTIFICATION_ENTER_TREE:
			_prev_tree_paused = get_tree().paused
			get_tree().paused = true
		NOTIFICATION_EXIT_TREE:
			if Globals.settings_menu == self:
				Globals.settings_menu = null
			user_prefs.save()
			get_tree().paused = _prev_tree_paused
