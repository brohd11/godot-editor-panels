#! namespace EditorPanels class TabPanel
@tool
extends Control

#! import_p Keys,

const RightClickHandler = preload("uid://cs6pl78crcr0g") #! resolve UtilR.Nodes.PopupMenus.Placer
const UFile = preload("uid://bqfy5cvhth0m1") #! resolve UtilR.Files.UFile
const EditorIcons = preload("uid://viocyrti6wce") #! resolve UIPlugin.EditorIcons
const UObject = preload("uid://3ris0kamdyic") #! resolve UtilR.Objects.UObject
const UWindow = preload("uid://d1yl3cuumcudy") #! resolve UtilR.Nodes.UWindow
const LineSubmit = preload("uid://vtkuh2gtwy1b") #! resolve Dialogs.Handlers.LineSubmit

static func get_scene_path():
	return "uid://ctutcmmga2vy6" #! ensure-path


var right_click_handler: RightClickHandler
var tab_v: VBoxContainer
var tab_bar: TabBar
var new_tab_button: Button
var dock_button: Button
var v_box: VBoxContainer
var _tab_bar_panel: PanelContainer

var load_default:= true
var _default_tabs:Array = []

var _standalone_panel:=true

## Use this to create an instance with a default path set.
static func get_instance(default_paths:Array):
	var ins = new()
	ins._default_tabs = default_paths
	return ins

func _init() -> void:
	_build_ui()

# Built in _init so the node refs are valid right after new(), before _ready.
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	right_click_handler = RightClickHandler.new()
	add_child(right_click_handler)
	
	var top_v = VBoxContainer.new()
	add_child(top_v)
	top_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_v.add_theme_constant_override("separation", 0)
	
	tab_v = VBoxContainer.new()
	top_v.add_child(tab_v)
	
	var h = HBoxContainer.new()
	tab_v.add_child(h)
	
	_tab_bar_panel = PanelContainer.new()
	h.add_child(_tab_bar_panel)
	_tab_bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	tab_bar = TabBar.new()
	_tab_bar_panel.add_child(tab_bar)
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	tab_bar.drag_to_rearrange_enabled = true
	tab_bar.tabs_rearrange_group = 0
	tab_bar.select_with_rmb = true
	
	new_tab_button = Button.new()
	h.add_child(new_tab_button)
	new_tab_button.focus_mode = Control.FOCUS_NONE
	
	dock_button = Button.new()
	h.add_child(dock_button)
	dock_button.visible = false
	dock_button.custom_minimum_size = Vector2(24, 24)
	dock_button.focus_mode = Control.FOCUS_NONE
	
	tab_v.add_child(Control.new()) # spacer
	
	v_box = VBoxContainer.new()
	top_v.add_child(v_box)
	v_box.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	var ed_theme = EditorInterface.get_editor_theme()
	_tab_bar_panel.add_theme_stylebox_override("panel", ed_theme.get_stylebox("tabbar_background", "TabContainer"))
	
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	
	tab_bar.gui_input.connect(_on_tab_bar_gui_input)
	tab_bar.tab_clicked.connect(_on_tab_clicked)
	tab_bar.tab_rmb_clicked.connect(_on_tab_rmb_clicked)
	tab_bar.tab_close_pressed.connect(_close_tab)
	tab_bar.mouse_entered.connect(_on_tab_bar_mouse_entered)
	tab_bar.mouse_exited.connect(_on_tab_bar_mouse_exited)
	tab_bar.tab_changed.connect(_on_tab_changed)
	tab_bar.tab_hovered.connect(_on_tab_hovered)
	
	new_tab_button.pressed.connect(_on_new_tab_pressed)
	new_tab_button.icon = EditorInterface.get_base_control().get_theme_icon("Add", "EditorIcons")
	new_tab_button.theme_type_variation = &"MainScreenButton"
	dock_button.theme_type_variation = &"MainScreenButton"
	
	await get_tree().process_frame
	if load_default and tab_bar.tab_count == 0:
		_load_default()

func set_standalone_panel(toggled:bool):
	_standalone_panel = toggled
	dock_button.visible = _standalone_panel

func get_split_options() -> RightClickHandler.Options:
	var options:RightClickHandler.Options
	var tab_contol = get_current_tab_control()
	if is_instance_valid(tab_contol) and tab_contol.has_method("get_split_options"):
		options = tab_contol.get_split_options()
	else:
		options = RightClickHandler.Options.new()
	
	var msg_text = "Hide Tab Bar" if tab_v.visible else "Show Tab Bar"
	var icon = EditorIcons.get_visibility_icon(tab_v.visible)
	var val = not tab_v.visible
	
	options.add_option(msg_text, _toggle_tab_bar.bind(val), [icon])
	return options


func set_dock_data(data:Dictionary):
	if data.is_empty():
		return
	
	_toggle_tab_bar(data.get(Keys.DATA_TAB_BAR_VIS, true))
	var tabs_data = data.get(Keys.DATA_ALL_TABS_DATA, {})
	var default = data.get(Keys.DATA_DEFAULT_TABS)
	if default != null:
		_default_tabs = default
	
	if tabs_data.is_empty():
		_load_default()
		return
	
	for idx:String in tabs_data.keys():
		var tab_data = tabs_data.get(idx)
		
		var file_path = tab_data.get(Keys.DATA_TAB_UID, "")
		if not FileAccess.file_exists(file_path):
			file_path = tab_data.get(Keys.DATA_TAB_FILE_PATH, "")
			if not FileAccess.file_exists(file_path):
				print("Could not load dock, no file path.")
				continue
		var plugin_control = load_plugin_control(file_path)
		if not is_instance_valid(plugin_control):
			continue
		
		var dock_data = tab_data.get(Keys.DATA_TAB_DATA, {})
		if plugin_control.has_method(Keys.METHOD_SET_DOCK_DATA):
			plugin_control.call(Keys.METHOD_SET_DOCK_DATA, dock_data)
		
		_add_tab(plugin_control)
		var title = tab_data.get(Keys.DATA_TAB_TITLE)
		if title:
			tab_bar.set_tab_title(tab_bar.tab_count - 1, title)
		
	
	var current_tab = data.get(Keys.DATA_CURRENT_TAB, 0)
	tab_bar.current_tab = current_tab
	get_tab_control(current_tab).show()
	
	_panel_checks()


func get_dock_data():
	var data = {}
	
	#data[Keys.DATA_DEFAULT_TABS] = _default_paths
	data[Keys.DATA_TAB_BAR_VIS] = tab_v.visible
	data[Keys.DATA_CURRENT_TAB] = tab_bar.current_tab
	var tabs_data = {}
	for i in range(tab_bar.get_tab_count()):
		var tab_control = v_box.get_child(i)
		var tab_data = {}
		
		tab_data[Keys.DATA_TAB_TITLE] = tab_bar.get_tab_title(i)
		if tab_control.has_method(Keys.METHOD_GET_DOCK_DATA):
			tab_data[Keys.DATA_TAB_DATA] = tab_control.call(Keys.METHOD_GET_DOCK_DATA)
		else:
			tab_data[Keys.DATA_TAB_DATA] = {}
		
		var path = UObject.get_object_file_path(tab_control)
		tab_data[Keys.DATA_TAB_FILE_PATH] = path
		tab_data[Keys.DATA_TAB_UID] = UFile.path_to_uid(path)
		
		tabs_data[i] = tab_data
	
	data[Keys.DATA_ALL_TABS_DATA] = tabs_data
	return data


func _on_new_plugin_tab(tab_control=null, select:=false):
	if tab_control == null:
		if not _default_tabs.is_empty():
			tab_control = load_plugin_control(_default_tabs[0])
	if tab_control == null:
		print("Could not new load tab, no control or default provided.")
		return
	_add_tab(tab_control)
	
	_panel_checks()
	if select:
		_show_tab(tab_bar.tab_count - 1)

func add_tab(tab_control:Control):
	_add_tab(tab_control)
	_panel_checks()

func _add_tab(tab_control:Control):
	v_box.add_child(tab_control)
	tab_control.hide()
	var title = tab_control.name
	if tab_control.has_method(Keys.METHOD_GET_TAB_TITLE):
		title = tab_control.call(Keys.METHOD_GET_TAB_TITLE)
	tab_bar.add_tab(title)
	var last_tab = tab_bar.tab_count - 1
	tab_bar.set_tab_metadata(last_tab, tab_control)
	
	#if Keys.VAR_PLUGIN_TAB_CONTAINER in tab_control:
	tab_control.set(Keys.VAR_PLUGIN_TAB_CONTAINER, self)
	
	if tab_control.has_signal(Keys.SIGNAL_NEW_PLUGIN_TAB):
		tab_control.connect(Keys.SIGNAL_NEW_PLUGIN_TAB, _on_new_plugin_tab)
	
	tab_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _load_default():
	if not _default_tabs.is_empty():
		for path in _default_tabs:
			var plugin_control = load_plugin_control(path)
			if plugin_control:
				_add_tab(plugin_control)
		if tab_bar.tab_count > 0:
			_show_tab(0)
	else:
		print("Plugin Tab Container does not have default paths.")
	
	_panel_checks()


func _on_tab_clicked(tab:int):
	_show_tab(tab)

func _show_tab(tab:int):
	for i in range(tab_bar.tab_count):
		var tab_control = get_tab_control(i)
		if i == tab:
			tab_control.show()
		else:
			tab_control.hide()

func _rename_tab(tab:int):
	var old_name = tab_bar.get_tab_title(tab)
	var rect = tab_bar.get_tab_rect(tab)
	rect.position += UWindow.get_control_absolute_position(tab_bar)
	var line = LineSubmit.new(self, rect, false)
	var resp:Dialogs.Response = await line.handled
	var new = resp.payload
	if resp.cancelled or new == old_name or new == "":
		return
	tab_bar.set_tab_title(tab, new)

func _close_tab(tab:int):
	var control = get_tab_control(tab)
	tab_bar.remove_tab(tab)
	control.queue_free()
	_on_tab_clicked(tab_bar.current_tab)
	_check_close_policy()


func _on_tab_changed(tab:int):
	var control = get_tab_control(tab)
	if not is_instance_valid(control):
		return
	if control.get_parent() != v_box:
		control.reparent(v_box)
	_show_tab(tab)
	_check_close_policy()


func _on_tab_bar_mouse_entered():
	var window = get_window()
	if window.gui_is_dragging():
		var drag_data = window.gui_get_drag_data()
		var from_path = drag_data.get("from_path")
		if from_path == null:
			return
		var from_node:TabBar = Engine.get_main_loop().root.get_node(from_path)
		var hovered_node = window.gui_get_hovered_control()
		if hovered_node is not TabBar:
			return
		if from_node == tab_bar:
			return
		else:
			if from_node.get_tab_count() <= 1:
				tab_bar.tabs_rearrange_group = -1
			else:
				tab_bar.tabs_rearrange_group = 55

func _on_tab_bar_mouse_exited():
	tab_bar.tabs_rearrange_group = 55

func _on_tab_hovered(tab:int):
	var window = get_window()
	if window.gui_is_dragging():
		tab_bar.current_tab = tab
		_show_tab(tab)


func _on_tab_rmb_clicked(tab:int):
	var options = RightClickHandler.Options.new()
	options.add_option("Rename", _rename_tab.bind(tab), ["Edit"])
	if _current_tab_can_be_freed():
		options.add_option("Close", _close_tab.bind(tab), ["Close"])
	
	right_click_handler.display_popup(options)

func _on_tab_bar_gui_input(event:InputEvent):
	
	
	pass

func _on_new_tab_pressed():
	var options = RightClickHandler.Options.new()
	#for path in _default_paths:
		#path = UFile.uid_to_path(path)
		#var icon = EditorInterface.get_base_control().get_theme_icon("GDScript", "EditorIcons")
		#if path.ends_with(".tscn"):
			#icon = EditorInterface.get_base_control().get_theme_icon("PackedScene", "EditorIcons")
		#options.add_option(path.get_file(), _new_tab_button_path_chosen.bind(path), [icon])
	
	var tabs = EditorPanelSingleton.get_registered_tabs()
	for _name in tabs.keys():
		var data = tabs.get(_name)
		var path = data.get("path")
		var icon = EditorInterface.get_base_control().get_theme_icon("GDScript", "EditorIcons")
		if path.ends_with(".tscn"):
			icon = EditorInterface.get_base_control().get_theme_icon("PackedScene", "EditorIcons")
		options.add_option(_name, _new_tab_button_path_chosen.bind(path), [icon])
	
	options.add_option("Open...", _open_choose_scene_dialog, ["Load"])
	#options.add_option("Save", _on_save_pressed, ["Save"])
	
	var win_pos = right_click_handler.get_centered_control_position(new_tab_button)
	right_click_handler.display_popup(options, true, win_pos)

func _new_tab_button_path_chosen(scene_path:String):
	var control = load_plugin_control(scene_path)
	_on_new_plugin_tab(control)
	if tab_bar.tab_count == 1:
		_show_tab(0)

func _open_choose_scene_dialog():
	var dialog = Dialogs.Handlers.FilePicker.Editor.file(self)
	var resp = await dialog.get_response()
	if resp.cancelled:
		return
	var control = load_plugin_control(resp.payload) as Control
	if control:
		_on_new_plugin_tab(control)

func _on_save_pressed():
	print("This does nothing")
	pass

func load_plugin_control(path:String):
	if FileAccess.file_exists(path):
		var loaded = load(path)
		if loaded is PackedScene:
			return loaded.instantiate()
		elif loaded is GDScript:
			return loaded.new()
	print("Could not load control: %s" % path)

func get_tab_control(tab:int):
	return tab_bar.get_tab_metadata(tab)

func get_current_tab_control():
	if tab_bar.current_tab < 0:
		return
	return tab_bar.get_tab_metadata(tab_bar.current_tab)

func get_all_tab_controls():
	var tabs = []
	for i in range(tab_bar.tab_count):
		tabs.append(tab_bar.get_tab_metadata(i))
	return tabs

func _panel_checks():
	await get_tree().process_frame
	_check_close_policy()
	tab_bar.queue_redraw()
	if tab_bar.tab_count == 1:
		_show_tab(0)


func _current_tab_can_be_freed():
	var current_control = get_current_tab_control()
	if not current_control:
		return false
	if current_control.has_method(Keys.METHOD_CAN_BE_FREED):
		return current_control.call(Keys.METHOD_CAN_BE_FREED)
	return tab_bar.tab_count > 1

func _check_close_policy():
	if _current_tab_can_be_freed():
		tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	else:
		tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	tab_bar.queue_redraw()

func _toggle_tab_bar(toggled:bool):
	tab_v.visible = toggled


class Keys:
	const VAR_PLUGIN_TAB_CONTAINER = "plugin_tab_container"
	const SIGNAL_NEW_PLUGIN_TAB = "new_plugin_tab"
	const METHOD_GET_TAB_TITLE = "get_tab_title"
	const METHOD_CAN_BE_FREED = "can_be_freed"
	const METHOD_GET_DOCK_DATA = "get_dock_data"
	const METHOD_SET_DOCK_DATA = "set_dock_data"
	
	const DATA_CURRENT_TAB = "current_tab"
	const DATA_DEFAULT_TABS = "default_tabs"
	const DATA_ALL_TABS_DATA = "tabs_data"
	const DATA_TAB_DATA = "dock_data"
	const DATA_TAB_TITLE = "tab_title"
	const DATA_TAB_FILE_PATH = "tab_file_path"
	const DATA_TAB_UID = "tab_uid"
	const DATA_TAB_BAR_VIS = &"DATA_TAB_BAR_VIS"

class Tabs:
	var _data = {}
	
	func get_data() -> Dictionary:
		return _data
	
	func set_current_tab(idx:int) -> void:
		var tabs_data = _data.get_or_add(Keys.DATA_ALL_TABS_DATA, {})
		var tab_count = tabs_data.size()
		if idx < tab_count:
			_data[Keys.DATA_CURRENT_TAB] = idx
		else:
			print("Cannot set current tab to %s, only have %s tabs." % [idx, tab_count])
	
	func set_default_tabs(default_tabs:PackedStringArray) -> void:
		_data[Keys.DATA_DEFAULT_TABS] = default_tabs
	
	func add_tab(title:String, tab_path:String, data:Dictionary={}) -> void:
		var tabs_data = _data.get_or_add(Keys.DATA_ALL_TABS_DATA, {})
		var next_idx = tabs_data.size()
		tabs_data[var_to_str(next_idx)] = {
			Keys.DATA_TAB_FILE_PATH:tab_path,
			Keys.DATA_TAB_UID: UFile.path_to_uid(tab_path),
			Keys.DATA_TAB_DATA : data
		}
		if not _data.has(Keys.DATA_CURRENT_TAB):
			_data[Keys.DATA_CURRENT_TAB] = 0
		
