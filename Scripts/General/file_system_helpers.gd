class_name FileSystemHelpers

static func list_files_in_folder(
		folder_path : String,
		return_full_path : bool = false,
		scan_subfolders : bool = false) -> Array[String]:
	var dir = DirAccess.open(folder_path)
	if not dir:
			print("Error opening folder:", folder_path)
			return []
	var result:Array[String] = []
	for file in dir.get_files():
		var name_to_add = file
		if return_full_path:
			name_to_add = dir.get_current_dir() + "/" + name_to_add
		result.append(name_to_add)
	if scan_subfolders:
		for subdir in dir.get_directories():
			var subdir_files = list_files_in_folder(\
				dir.get_current_dir() + "/" + subdir, return_full_path, true)
			if not return_full_path:
				for i in range(subdir_files.size()):
					subdir_files[i] = subdir + "/" + subdir_files[i]
			result.append_array(subdir_files)
	return result


static func list_folders_in_folder(
		folder_path : String,
		return_full_path : bool = false,
		scan_subfolders : bool = false) -> Array[String]:
	var dir = DirAccess.open(folder_path)
	if not dir:
			print("Error opening folder:", folder_path)
			return []
	var result : Array[String] = []
	for folder in dir.get_directories():
		var name_to_add = folder
		if return_full_path:
			name_to_add = dir.get_current_dir() + "/" + name_to_add
		result.append(name_to_add)
	if scan_subfolders:
		for subdir in dir.get_directories():
			var subdir_files = list_folders_in_folder(\
				dir.get_current_dir() + "/" + subdir, return_full_path, true)
			if not return_full_path:
				for i in range(subdir_files.size()):
					subdir_files[i] = subdir + "/" + subdir_files[i]
			result.append_array(subdir_files)
	return result


func _init():
	assert(false, "static class do not instantiate")
