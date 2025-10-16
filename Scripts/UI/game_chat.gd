extends Control


class DisappearingEntry:
	var content : String
	var time_left : float


## Messages and similar which are showed some time even when the chat is not
## activated.
var entries : Array[DisappearingEntry]

## this variable is needed to successfully remove focus from text field when
## content is submitted
var just_submitted : bool = false

## full log is shown when text input is active -- it stores all messages and can be scrolled
@onready var full_log = $VBoxContainer/HBoxContainer/FullLog
@onready var full_log_content = $VBoxContainer/HBoxContainer/FullLog/FullLogContent
@onready var scroll_bar = full_log.get_v_scroll_bar()

## short log shows only a few last messages for a short time
@onready var short_log = $VBoxContainer/HBoxContainer/ShortInactiveLog

@onready var text_input : LineEdit = $VBoxContainer/ChatLineEdit

func _ready():
	NET.chat_message_arrived.connect(_on_message_arrived)
	NET.chat_log_cleared.connect(clear_short_log)
	# deactivation at start forces the input to be turned off
	deactivate()


func _exit_tree():
	NET.chat_message_arrived.disconnect(_on_message_arrived)
	NET.chat_log_cleared.disconnect(clear_short_log)


func _process(delta : float):
	# TODO move these inputs to some invisible button probably
	var should_activate : bool = not just_submitted and \
		is_visible_in_tree() and \
		Input.is_action_just_pressed("KEY_ACTIVATE_CHAT")

	if should_activate:
		activate()
	just_submitted = false
	roll_entries(delta)


func roll_entries(delta : float):
	var threshold : int = -1
	for i in range(entries.size()):
		var entry = entries[i]
		entry.time_left -= delta
		if entry.time_left < 0.0:
			threshold = i
	if threshold >= 0:
		entries = entries.slice(threshold + 1)
		refresh_short_log()


func refresh_short_log():
	if is_active():
		return
	const max_messages = 9
	for child in short_log.get_children():
		short_log.remove_child(child)
		child.queue_free()
	var index : int = max(0, entries.size() - max_messages)
	while index < entries.size():
		var message : Label = _create_short_log_line(entries[index].content)
		short_log.add_child(message)
		index = index + 1


func refresh_full_log():
	var should_scroll_down = scroll_bar.ratio >= 1
	full_log_content.text = NET.chat_log # maybe better way than direct read?
	if should_scroll_down:
		scroll_bar.ratio = 1


func is_active():
	return full_log.visible


## opens chat text input and shows *full_log* and hides *short_log*
func activate():
	text_input.editable = true
	text_input.grab_focus()
	text_input.modulate = Color.WHITE
	text_input.mouse_filter = MOUSE_FILTER_STOP
	short_log.hide()
	full_log.show()
	refresh_full_log()
	scroll_chat_down()


## hides chat input and *full_log*, shows *short_log*
func deactivate():
	text_input.editable = false
	# this is needed to completely loose focus
	text_input.hide()
	text_input.show()

	text_input.modulate = Color.TRANSPARENT
	text_input.mouse_filter = MOUSE_FILTER_IGNORE
	short_log.show()
	full_log.hide()
	refresh_short_log()


func clear_short_log():
	entries = []


func scroll_chat_down():
	scroll_bar.ratio = 1


func send_chat_message(content : String):
	if content.length() > 0:
		NET.send_chat_message(content)
		scroll_chat_down()
	just_submitted = true


func _create_short_log_line(text : String) -> Label:
	var line := Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(0.0, 15.0)
	line.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	line.text = text
	return line



func _on_message_arrived(content : String):
	var entry = DisappearingEntry.new()
	entry.content = content
	entry.time_left = 15.0
	entries.append(entry)
	if is_active():
		refresh_full_log()
	else:
		refresh_short_log()


func _on_chat_line_edit_text_submitted(new_text : String):
	# Check if message is a cheat
	if new_text.length() <= 4 and (new_text.begins_with("gg") or new_text.begins_with("GG")):
		BM.force_surrender() # TODO add check in which game mode player is in


	if new_text.length() >= 1 and new_text[0] == '/':
		# Split message by arguments
		var args = new_text.split(" ", false)
		var cheat = args[0].substr(1).strip_edges().to_lower()

		# Get number values from cheat arguments
		args = Array(args).filter(func(arg): return arg.is_valid_int())
		# Convert number values from string to int
		args = Array(args).map(func(arg): return int(arg))

		# Cheats
		match cheat:
			"help":
				send_chat_message("money, fast, brain, levelup (optional number of levels), maxupgrade, win")
			"money":
				WM.cheat_money.callv(args)
				print("money cheat")
			"fast":
				WM.hero_speed_cheat.callv(args)
				print("travel cheat")
			"brain":
				BM.toggle_ai_preview()
				print("ai move preview cheat")
			"levelup":
				WM.hero_level_up.callv(args)
				print("levelup cheat")
			"maxupgrade":
				WM.city_upgrade_cheat()
				print("city max upgrade cheat")
			"win":
				BM.force_win_battle()
				print("force win cheat")
			"gg":
				send_chat_message("GG WP")
				BM.force_surrender() # TODO add check in which game mode player is in

			_:
				print("unknown cheat")

	else:
		send_chat_message(new_text)

	text_input.clear()
	deactivate()


func _on_chat_line_edit_focus_entered():
	if not is_active():
		activate()
