extends ResourceEditor


## order of symbols here is the same order as in symbol pickers
var all_data_symbols : Array[DataSymbol] = []


@onready var symbol_container : Control = $HBoxContainer/Edition/VBoxContainer/Preview/Center

## OptionButtons for picking symbols, ordered matching direction codes
@onready var symbol_pickers : Array[OptionButton] = [
	symbol_container.get_node("ChangeW"),
	symbol_container.get_node("ChangeNW"),
	symbol_container.get_node("ChangeNE"),
	symbol_container.get_node("ChangeE"),
	symbol_container.get_node("ChangeSE"),
	symbol_container.get_node("ChangeSW"),
]


## override -> applies DataUnit type to edited Resource
func _init_resource_type() -> void:
	dirty_changes = DataUnit.new()
	resource_directory_path = CFG.UNITS_PATH
	_load_all_data_symbols()
	_fill_symbol_pickers()


## override
func apply_texture_to_preview() -> void:
	resource_preview_form.apply_graphics(dirty_changes, CFG.NEUTRAL_COLOR)
	for dir in range(6):
		_set_symbol_picker(dir, dirty_changes.symbols[dir])


## override
func save_resource() -> void:
	for i in range(6):
		edited_resource.symbols[i] = dirty_changes.symbols[i]

	super()  # saves the resource


#region Symbols

## scan and collect all DataSymbol resources
## so they can be referred as int index for symbol pickers
func _load_all_data_symbols():
	var path = CFG.SYMBOLS_PATH
	var dir = DirAccess.open(path)
	for f in dir.get_files():
		all_data_symbols.append(load(path+f) as DataSymbol)


## adds items to all pickers, based on `all_data_symbols`
func _fill_symbol_pickers():
	var direction = 0
	for picker in symbol_pickers:
		fill_symbol_picker(picker, direction)
		direction += 1


## adds items to a picker, based on `all_data_symbols`
func fill_symbol_picker(picker : OptionButton, direction : int):
	picker.clear()
	for data_symbol in all_data_symbols:
		picker.add_item(data_symbol.symbol_name)
	# bind direction in callback
	var callback = func onSelected(_index):
		on_symbol_selected(direction, _index)
	picker.item_selected.connect(callback)


## chooses specified symbol on a specified picker
func _set_symbol_picker(dir: int, value: DataSymbol):
	var symbol_idx = all_data_symbols.find(value)
	symbol_pickers[dir].select(symbol_idx)


## updates `resource_preview_form` when symbol is picked
func on_symbol_selected(dir : int, picker_index : int):
	var picked_symbol = all_data_symbols[picker_index]
	print("selected dir %d %s - symbol %s - %s" % \
			[dir, GenericHexGrid.direction_to_name(dir as GenericHexGrid.GridDirections), \
			picked_symbol.symbol_name, picked_symbol.symbol_name])

	resource_preview_form.get_symbol(dir).apply_sprite(dir, picked_symbol.texture_path)
	dirty_changes.symbols[dir] = picked_symbol

#endregion Symbols
