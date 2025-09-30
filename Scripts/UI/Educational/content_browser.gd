class_name ContentBrowser
extends Panel

@onready var _column_container : BoxContainer = $MarginContainer/VBoxContainer/Columns

@onready var _list : Control = _column_container.get_node("ScrollContainer")
@onready var _content : Control = _column_container.get_node("VBoxContainer")

@onready var _description : Label = _content.get_node("Description")
@onready var _play_button : Button = _content.get_node("PlayButton")
@onready var _content_buttons_container : BoxContainer = _list.get_node("Content")

var _selected_item : Variant

var content_folder_path : String


func _ready():
	_set_types()
	refresh_content_list()


#region Overridable

## Defines folder path for "content_folder_path" and Variant for "_selected_item"
func _set_types() -> void:
	assert(false, "has to be overriden")


## Optional Override
func get_description() -> String:
	return ""


func activate_content() -> void:
	assert(false, "has to be overriden")


## Optional Override
func additonal_selected_content_function() -> void:
	pass

#endregion Overridable


func _on_visibility_changed():
	# sometimes called before ready inits @onready
	if _play_button:
		refresh_content_list()


func refresh_content_list():
	Helpers.remove_all_children(_content_buttons_container)
	var content_paths = FileSystemHelpers.list_files_in_folder(content_folder_path)

	for content_path in content_paths:
		var button = Button.new()
		button.text = content_path
		button.name = content_path
		button.text_overrun_behavior = TextServer.OverrunBehavior.OVERRUN_TRIM_ELLIPSIS
		button.clip_text = true
		button.custom_minimum_size = Vector2(0, 64)
		button.pressed.connect(_on_content_clicked.bind(content_path))
		_content_buttons_container.add_child(button)

	#TODO addsome kind of checkmarks for completed tutorials, and auto-select first uncompleted from the top
	_on_content_clicked(content_paths[0]) # auto selects first tutorial


func _on_content_clicked(content_path : String):
	_selected_item = load(content_folder_path + content_path)
	var displayed_text : String = get_description()

	_description.set_text(displayed_text)
	additonal_selected_content_function()


func _on_play_button_pressed():
	activate_content()
