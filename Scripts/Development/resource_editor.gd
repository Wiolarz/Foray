class_name ResourceEditor
extends CanvasLayer

## Resource tree needs to double clicked or selected using the small button on the right
## as current default godot implementation requires selected item to be highlighted first


var resource_directory_path : String

## field to allow keeping proper ids count
## during recursive calls in load_tiles_dir
var next_resource_id : int = 0

## currently edited unit data
## WARNING: do not change this until save is clicked
## not saved changes are kept on `dirty_changes`
var edited_resource : Resource

var dirty_changes : Resource

## Dictionary int -> String (DataTile path)
var browser_tree_id_to_resource_path : Dictionary = {}

## prepared resized texture for open button in browser
var open_button_texture : Texture2D

## label showing path to currently edited data unit
@onready var currently_edited_label : Label = %ResourceName

## unit form for preview and storing unsaved changes temporarily
@onready var resource_preview_form : Node2D = \
	$HBoxContainer/Edition/VBoxContainer/Preview/Center/ResourcePreview

## try display for selecting unit to edit
@onready var resource_browser_tree : Tree = $HBoxContainer/ResourceBrowserTree

@onready var resource_name_edit : TextEdit = $HBoxContainer/Edition/VBoxContainer/Bottom/HBox/ResourceName


#region INIT

func _ready():
	_init_resource_tree()
	_load_open_button_texture()
	_init_resource_type()
	_load_resources()
	_select_first_item()


## resizes texture for open button in resource browser tree
func _load_open_button_texture():
	var base_texture = load("res://Art/old/push.png")
	var image = base_texture.get_image()
	image.resize(32, 32)
	open_button_texture = ImageTexture.create_from_image(image)


func _init_resource_tree() -> void:
	resource_browser_tree.button_clicked.connect(_on_browser_open_button_clicked)
	resource_browser_tree.item_activated.connect(_on_browser_item_activated)
	resource_browser_tree.hide_root = true


## initializes `resource_browser_tree` and `browser_tree_id_to_resource_path`
## tree buttons get ids corresponding to indexes in that array
func _load_resources() -> void:
	resource_browser_tree.clear()
	var root = resource_browser_tree.create_item()

	var dir = DirAccess.open(resource_directory_path)
	if dir:
		next_resource_id = 0
		_load_resources_dir_recursive(dir, root);
	else:
		push_error("Error opening folder: ", resource_directory_path)


## initializes `resource_browser_tree` and `browser_tree_id_to_resource_path`
## tree buttons get ids corresponding to indexes in that array
func _load_resources_dir_recursive(dir : DirAccess, parent : TreeItem):
	for file in dir.get_files():
		var file_in_the_tree = resource_browser_tree.create_item(parent)
		file_in_the_tree.set_text(0, file)
		file_in_the_tree.add_button( \
				0, open_button_texture, next_resource_id, false, "tooltip")

		browser_tree_id_to_resource_path[next_resource_id] = \
				dir.get_current_dir() + "/" + file
		#print("loaded ", browser_tree_id_to_resource_path[next_resource_id], \
				#" on id ", next_resource_id)

		next_resource_id += 1

	for child_directory in dir.get_directories():
		var directory_in_the_tree = resource_browser_tree.create_item(parent)
		directory_in_the_tree.set_text(0, child_directory)
		directory_in_the_tree.set_custom_bg_color(0, Color.DARK_BLUE)
		directory_in_the_tree.set_selectable(0, false)

		var child_dir_access = DirAccess.open( \
				dir.get_current_dir()+"/"+child_directory)
		_load_resources_dir_recursive(child_dir_access, directory_in_the_tree)


func _select_first_item() -> void:
	load_resource(browser_tree_id_to_resource_path[0])

#endregion INIT


#region Overrideable functions

func _init_resource_type() -> void:
	pass


func apply_texture_to_preview() -> void:
	pass


func save_resource() -> void:
	edited_resource.texture_path = dirty_changes.texture_path
	ResourceSaver.save(edited_resource, edited_resource.resource_path)
	# WARNING clears uids
	# see https://github.com/godotengine/godot/issues/83259
	# use uid_fixer script to fix


## Parses name for new resource and validates it. Returns empty string on error.
func _get_validated_resource_name() -> String:
	var name : String = resource_name_edit.text
	if name.length() == 0 or not name.is_valid_filename() or name[0] == ".":
		return ""
	return name

#endregion Overrideable functions


#region Buttons

## Sets DataTile on specified path as `edited_resource`
## Updates `resource_preview_form`, `symbol_pickers`, `currently_edited_label` etc
func load_resource(path : String):
	var data = load(path)
	edited_resource = data
	dirty_changes = edited_resource.duplicate()

	currently_edited_label.text = edited_resource.resource_path

	apply_texture_to_preview()


## load resource when clicking open button
func _on_browser_open_button_clicked(_item, _column, id:int, _mouse_button):
	load_resource(browser_tree_id_to_resource_path[id])


## load tile when double clicking or pressing enter
func _on_browser_item_activated():
	var selected = resource_browser_tree.get_selected()
	var open_button_id = selected.get_button_id(0, 0)
	load_resource(browser_tree_id_to_resource_path[open_button_id])


## shows art picking dialog
func _on_pick_art_button_pressed():
	$PickArtDialog.show()


## applies new art to the edited resource
func _on_pick_art_dialog_file_selected(path : String):
	dirty_changes.texture_path = path
	resource_preview_form._set_texture(load(path))


func _on_delete_pressed():
	DirAccess.remove_absolute(edited_resource.resource_path)
	_load_resources()  # unload new resource from the Resource Browser tree
	_select_first_item()
	UI.resources_list_changed.emit()


## Creates a new resource which is a duplicate of the selected resource but with a new name
func _on_add_pressed():
	var resource_name : String = _get_validated_resource_name()
	if resource_name.length() <= 0:
		resource_name_edit.text = "Invalid name"
		resource_name_edit.modulate = Color.FIREBRICK
		return
	var save_path : String = resource_directory_path + resource_name + ".tres"
	if FileAccess.file_exists(save_path):
		resource_name_edit.text = "Name is already Taken"
		resource_name_edit.modulate = Color.FIREBRICK
		# TODO add warning that file under that name already exists
		return
	print("Saved new resource")
	resource_name_edit.modulate = Color.WHITE
	ResourceSaver.save(dirty_changes, save_path)
	_load_resources()  # loads new resource into the Resource Browser tree
	load_resource(save_path)  # auto selects newly created resource
	UI.resources_list_changed.emit()


## applies changes in `resource_preview_form` to `edited_resource` resource
func _on_save_pressed():
	assert(edited_resource and not edited_resource.resource_path.is_empty(), "can only edit existing resources, open a resource first")
	save_resource()


## return to main menu
func _on_back_button_pressed():
	hide()
	IM.go_to_main_menu()

#endregion Buttons
