@tool
extends EditorScript

## Saving resources in game mode in our editors clears uid field
## This script resaves all resources with editor to fix uid's and similar issues
## to run use File > Run (default shortcut ctrl + shift + X)

const START_DIR = "res://Resources"
const EXTENSIONS = [ "tres", "res" , "png", "tscn" ]


func _run():
	process_dir(START_DIR)


func process_dir(dir_name: String) -> void:
	print("----- Processing dir: " + dir_name)
	dir_name = remove_trailing_slash(dir_name)
	var dir := DirAccess.open(dir_name)
	if not dir:
		push_error("An error occurred when trying to access the path: ", dir_name)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var is_dir = dir.current_is_dir()
	while file_name != "":
		if is_dir:
			process_dir(dir_name + "/" + file_name)
		elif file_name.get_extension() in EXTENSIONS:
			fix_file(dir_name, file_name)
		file_name = dir.get_next()
		is_dir = dir.current_is_dir()
	dir.list_dir_end()


func remove_trailing_slash(dir_name: String) -> String:
	if dir_name.ends_with("/"):
		return dir_name.trim_suffix("/")
	return dir_name


func fix_file(dir_name:String, file_name:String) -> void:
	print("\tProcessing file: " + dir_name + "/" + file_name)
	var res := ResourceLoader.load(dir_name + "/" + file_name)
	ResourceSaver.save(res) # resave fixes uid
