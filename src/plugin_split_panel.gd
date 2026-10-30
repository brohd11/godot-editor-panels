#! namespace EditorPanels class SplitPanel
extends Control
#! import_p Keys,

const PluginSplitPanel = preload("res://addons/_lib/editor_panels/src/plugin_split_panel.gd")

const RightClickHandler = preload("uid://cs6pl78crcr0g") #! resolve UtilR.Nodes.PopupMenus.Placer
const ClickState = preload("uid://c8l2o7cw3fklh") #! resolve UtilR.Inputs.ClickState
const UFile = preload("uid://bqfy5cvhth0m1") #! resolve UtilR.Files.UFile
const UObject = preload("uid://3ris0kamdyic") #! resolve UtilR.Objects.UObject

const EditorColors = preload("uid://cpw0fsrs38esk") #! resolve UtilE.Colors

const DogEarButton = preload("uid://b2uqpfbaofv4p") #! resolve UIRuntime.DogEarButton

var right_click_handler:RightClickHandler

var buttons_h:HBoxContainer
var dock_button:Button
var layout_button:Button
var vbox:VBoxContainer
var main_container
var dock_overlay:DockOverlay

var _style_box_h:StyleBoxFlat
var _style_box_v:StyleBoxFlat

enum SplitType { 
	HORIZONTAL_L,
	HORIZONTAL_R,
	VERTICAL_U,
	VERTICAL_D,
	}

enum DropZone {
	NIL,
	CENTER,
	LEFT,
	RIGHT,
	UP,
	DOWN
	}


func _ready():
	var editor_scale = EditorInterface.get_editor_scale()
	
	EditorInterface.get_base_control().theme_changed.connect(_on_editor_theme_changed)
	_create_style_boxes()
	
	right_click_handler = RightClickHandler.new()
	add_child(right_click_handler)
	
	vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	main_container = MarginContainer.new()
	# not sure about this, scaling is odd...
	#main_container = Margin.new_plugin_margin_container()
	vbox.add_child(main_container)
	main_container.name = "MainContainer"
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	#var main_marg = 0
	#var minor_version = ALibRuntime.Utils.UVersion.get_minor_version()
	#if minor_version >= 6:
		#main_marg = -2 * editor_scale
	#main_container.add_theme_constant_override("margin_top", main_marg)
	#main_container.add_theme_constant_override("margin_left", main_marg)
	#main_container.add_theme_constant_override("margin_right", main_marg)
	#main_container.add_theme_constant_override("margin_bottom", main_marg)
	
	var dog_ear_size = 16 * editor_scale
	var dog_ear = DogEarButton.new(DogEarButton.Position.TOP_RIGHT, dog_ear_size)
	add_child(dog_ear)
	
	var buttons_bg = ColorRect.new()
	add_child(buttons_bg)
	buttons_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	buttons_bg.color = EditorColors.get_theme_color(EditorColors.ThemeColor.BACKGROUND)
	buttons_bg.hide()
	
	var margin = MarginContainer.new()
	buttons_bg.add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var button_marg = 2 * editor_scale
	margin.add_theme_constant_override("margin_top", button_marg)
	margin.add_theme_constant_override("margin_left", button_marg)
	margin.add_theme_constant_override("margin_right", button_marg)
	margin.add_theme_constant_override("margin_bottom", button_marg)
	
	margin.resized.connect(
		func():
			buttons_bg.custom_minimum_size = margin.size
			buttons_bg.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	)
	
	buttons_h = HBoxContainer.new()
	buttons_h.mouse_filter = Control.MOUSE_FILTER_PASS
	buttons_h.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_child(buttons_h)
	
	layout_button = Button.new()
	buttons_h.add_child(layout_button)
	layout_button.icon = EditorInterface.get_base_control().get_theme_icon("FileThumbnail", "EditorIcons")
	layout_button.mouse_filter = Control.MOUSE_FILTER_PASS
	layout_button.theme_type_variation = &"MainScreenButton"
	layout_button.focus_mode = Control.FOCUS_NONE
	layout_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout_button.pressed.connect(_on_layout_button_pressed)
	
	dock_button = Button.new()
	buttons_h.add_child(dock_button)
	dock_button.mouse_filter = Control.MOUSE_FILTER_PASS
	dock_button.theme_type_variation = &"MainScreenButton"
	dock_button.focus_mode = Control.FOCUS_NONE
	dock_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	dog_ear.left_clicked.connect(func():buttons_bg.show())
	buttons_bg.mouse_exited.connect(func():buttons_bg.hide())
	
	dock_overlay = DockOverlay.new()
	add_child(dock_overlay)
	dock_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dock_overlay.hide()
	dock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_overlay.move_panel.connect(_move_panel_to_split)
	dock_overlay.swap_panels.connect(_swap_panels)
	
	var panel = _new_movable_panel()
	main_container.add_child(panel)
	
	EditorPanelSingleton.register_split_panel_instance(self)


func get_dock_data():
	return get_layout_data()

func set_dock_data(data):
	_load_layout(data)

func load_layout(layout:Layout):
	_load_layout(layout.get_layout_data())


func split_panel(target_panel: Control, direction: SplitType):
	var new_panel = _new_movable_panel()
	_new_split_panel(target_panel, new_panel, direction)

func _move_panel_to_split(dragging_panel: Control, target_panel: Control, direction:DropZone):
	detach_panel(dragging_panel, false)
	var split_type:SplitType
	match direction:
		DropZone.UP: split_type = SplitType.VERTICAL_U
		DropZone.DOWN: split_type = SplitType.VERTICAL_D
		DropZone.LEFT: split_type = SplitType.HORIZONTAL_L
		DropZone.RIGHT: split_type = SplitType.HORIZONTAL_R
	_new_split_panel(target_panel, dragging_panel, split_type)

func new_split(calling_node: Control, new_panel:Control, direction: SplitType):
	var target_panel = calling_node
	while is_instance_valid(target_panel):
		if target_panel is MoveablePanel:
			break
		target_panel = target_panel.get_parent()
		
	if not is_instance_valid(target_panel):
		print("COULD NOT GET PANEL")
		return
	
	var new_movable_panel = _new_movable_panel()
	
	_new_split_panel(target_panel, new_movable_panel, direction)
	
	new_movable_panel.add_control(new_panel)

func _new_split_panel(target_panel: MoveablePanel, new_panel:Control, direction: SplitType):
	var parent = target_panel.get_parent()
	var vertical = direction == SplitType.VERTICAL_U or direction == SplitType.VERTICAL_D
	var new_split = _new_split_node(vertical)
	
	if parent == main_container: # Special case: Splitting the absolute root
		main_container.remove_child(target_panel)
		main_container.add_child(new_split)
	else: # Standard case: Replacing a child in an existing split
		var index = target_panel.get_index()
		parent.remove_child(target_panel)
		parent.add_child(new_split)
		parent.move_child(new_split, index)
	
	if direction == SplitType.HORIZONTAL_R or direction == SplitType.VERTICAL_D:
		new_split.add_child(target_panel) 
		new_split.add_child(new_panel)
	else:
		new_split.add_child(new_panel)
		new_split.add_child(target_panel) 

# Call with dispose = true when clicking "Close"
# Call with dispose = false when starting a drag/move
func detach_panel(panel: Control, dispose: bool = true):
	var parent_container = panel.get_parent()
	if parent_container == main_container:
		if dispose:
			parent_container.remove_child(panel)
			panel.queue_free()
		else:
			parent_container.remove_child(panel)
		return
	
	var split = parent_container
	var grand_parent = split.get_parent()
	
	var sibling = null
	for child in split.get_children():
		if child != panel:
			sibling = child
			break
	
	if sibling:
		var split_index = split.get_index()
		sibling.reparent(grand_parent, false)
		grand_parent.move_child(sibling, split_index)
		sibling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sibling.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	if dispose: # CASE: CLOSING
		pass 
	else: # CASE: MOVING
		split.remove_child(panel)
	split.queue_free()

func _close_panel(target_panel):
	detach_panel(target_panel, true)
	if main_container.get_child_count() == 0:
		var panel = _new_movable_panel()
		main_container.add_child(panel)

func _toggle_panel(panel:Control):
	var split = panel.get_parent()
	if split is SplitContainer:
		split.vertical = not split.vertical
		_set_split_style_box(split)

func _on_panel_right_clicked(panel:MoveablePanel):
	var options:RightClickHandler.Options
	var control = panel.get_control()
	if control.has_method("get_split_options"):
		options = control.get_split_options()
	else:
		options = RightClickHandler.Options.new()
	
	options.add_option("Split/Left", split_panel.bind(panel, SplitType.HORIZONTAL_L))
	options.add_option("Split/Right", split_panel.bind(panel, SplitType.HORIZONTAL_R))
	options.add_option("Split/Up", split_panel.bind(panel, SplitType.VERTICAL_U))
	options.add_option("Split/Down", split_panel.bind(panel, SplitType.VERTICAL_D))
	if panel.get_parent() is SplitContainer:
		options.add_option("Toggle Split", _toggle_panel.bind(panel))
	
	options.add_option("Close", _close_panel.bind(panel))
	
	right_click_handler.display_popup(options)

func _on_layout_button_pressed():
	var options = RightClickHandler.Options.new()
	var layouts = EditorPanelSingleton.get_registered_layouts()
	for _name in layouts.keys():
		var data = layouts.get(_name)
		var layout = data.get("layout")
		var icon = data.get("icon")
		options.add_option(_name, load_layout.bind(layout), [icon])
	
	var new_pos = right_click_handler.get_centered_control_position(layout_button)
	right_click_handler.display_popup(options, true, new_pos)

func _on_drag_started(panel):
	#if get_panel_count() < 2:
		#return
	for panel_container in EditorPanelSingleton.get_split_panel_instances():
		if is_instance_valid(panel_container):
			panel_container.start_drag(panel)

func start_drag(panel):
	dock_overlay.show()
	dock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var panel_nodes = _get_panels()
	var panel_rects = {}
	for p:MoveablePanel in panel_nodes:
		panel_rects[p.get_global_rect()] = p
	
	dock_overlay.panel_rects = panel_rects
	
	while get_window().gui_is_dragging():
		await get_tree().process_frame
	
	dock_overlay.hide()
	dock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _swap_panels(panel_a: Control, panel_b: Control):
	var panel_a_parent = panel_a.get_parent()
	var panel_b_parent = panel_b.get_parent()
	
	var panel_a_idx = panel_a.get_index()
	var panel_b_idx = panel_b.get_index()
	
	panel_a_parent.remove_child(panel_a)
	panel_b_parent.remove_child(panel_b)
	
	panel_a_parent.add_child(panel_b)
	panel_b_parent.add_child(panel_a)
	
	panel_a_parent.move_child(panel_b, panel_a_idx)
	panel_b_parent.move_child(panel_a, panel_b_idx)


func get_layout_data():
	if main_container.get_child_count() == 0:
		return {}
	var root_node = main_container.get_child(0)
	var layout_data = _serialize_node(root_node)
	return layout_data

func _serialize_node(node: Control) -> Dictionary:
	var data = {}
	if node is SplitContainer:
		data[Keys.TYPE] = Keys.TYPE_SPLIT
		data[Keys.DIRECTION] = Keys.DIR_VERTICAL if node.vertical else Keys.DIR_HORIZONTAL
		data[Keys.OFFSET] = node.split_offset
		
		var children_data = []
		for child in node.get_children(): # Recursively save children
			children_data.append(_serialize_node(child))
		
		data[Keys.CHILDREN] = children_data
		
	else: # node is movable panel
		data[Keys.TYPE] = Keys.TYPE_PANEL
		if node.get_child_count() > 0:
			var control = node.get_control()
			var path = UObject.get_object_file_path(control)
			if path:
				data[Keys.CONTENT_PATH] = path
				var uid = UFile.path_to_uid(path)
				data[Keys.CONTENT_UID] = uid
			
			if control.has_method(Keys.METHOD_GET_DOCK_DATA):
				data[Keys.PANEL_DOCK_DATA] = control.call(Keys.METHOD_GET_DOCK_DATA)
				#data[Keys.PANEL_DOCK_DATA] = control.get_dock_data()
			
		else:
			data[Keys.CONTENT_PATH] = "" # Empty panel
	
	return data

func _load_layout(data:Dictionary):
	if data.is_empty():
		return
	_clear_current_layout()
	_deserialize_node(data, main_container)

func _clear_current_layout():
	for child in main_container.get_children():
		child.queue_free()

func _deserialize_node(data: Dictionary, parent: Control):
	if data[Keys.TYPE] == Keys.TYPE_SPLIT:
		var vertical = data[Keys.DIRECTION] == Keys.DIR_VERTICAL
		var split = _new_split_node(vertical)
		parent.add_child(split)
		split.split_offset = data.get(Keys.OFFSET, 0)
		
		for child_data in data[Keys.CHILDREN]:
			_deserialize_node(child_data, split)
		
	elif data[Keys.TYPE] == Keys.TYPE_PANEL:
		var p = _new_movable_panel()
		parent.add_child(p)
		var panel_dock_data = data.get(Keys.PANEL_DOCK_DATA)
		var path = data.get(Keys.CONTENT_UID, "")
		if not FileAccess.file_exists(path):
			path = data.get(Keys.CONTENT_PATH, "")
		else:
			path = UFile.uid_to_path(path)
		if path != "":
			var scene = UObject.instance_scene_or_script(path)
			if scene:
				p.add_control(scene)
				if panel_dock_data and scene.has_method(Keys.METHOD_SET_DOCK_DATA):
					scene.call(Keys.METHOD_SET_DOCK_DATA, panel_dock_data)
					#scene.set_dock_data(panel_dock_data)
			else:
				pass
				#print("Could not find scene: ", path)
				# Maybe load an error label or empty picker here


func _new_movable_panel():
	var panel = MoveablePanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.picker_clicked.connect(_on_picker_clicked)
	panel.drag_started.connect(_on_drag_started)
	panel.right_clicked.connect(_on_panel_right_clicked)
	panel.swap_panels.connect(_swap_panels)
	panel.move_panel.connect(_move_panel_to_split)
	return panel

func _new_split_node(_vertical:bool=false):
	var split = SplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12 * EditorInterface.get_editor_scale())
	split.vertical = _vertical
	_set_split_style_box(split)
	return split

func _set_split_style_box(split:SplitContainer):
	if split.vertical:
		split.add_theme_stylebox_override("split_bar_background", _style_box_v)
	else:
		split.add_theme_stylebox_override("split_bar_background", _style_box_h)

func get_panel_count() -> int:
	var panels = _get_panels()
	return panels.size()

func get_panels():
	return _get_panels()

func _get_panels():
	var nodes = []
	for c in main_container.get_children():
		nodes.append_array(_get_panel_recur(c))
	return nodes

func _get_panel_recur(node: Control) -> Array:
	var nodes = []
	if node is SplitContainer:
		for child in node.get_children():
			nodes.append_array(_get_panel_recur(child))
	elif node is MoveablePanel:
		nodes.append(node)
	return nodes


func _on_picker_clicked(panel:MoveablePanel):
	var options = RightClickHandler.Options.new()
	var panels = EditorPanelSingleton.get_registered_panels()
	for _name in panels.keys():
		var data = panels.get(_name)
		var path = data.get("path")
		var icon = EditorInterface.get_base_control().get_theme_icon("GDScript", "EditorIcons")
		if path.ends_with(".tscn"):
			icon = EditorInterface.get_base_control().get_theme_icon("PackedScene", "EditorIcons")
		options.add_option(_name, _on_picker_option_picked.bind(panel, path), [icon])
	
	options.add_option("Open...", _on_picker_open_picked.bind(panel), ["Load"])
	
	var new_pos = right_click_handler.get_centered_control_position(panel._scene_picker.get_child(0))
	right_click_handler.display_popup(options, true, new_pos)


func _on_picker_option_picked(panel:MoveablePanel, path:String):
	var control = UObject.instance_scene_or_script(path)
	if control == null:
		return
	panel.add_control(control)

func _on_picker_open_picked(panel:MoveablePanel):
	var dialog = Dialogs.Handlers.FilePicker.Editor.file(self)
	var resp = await dialog.get_response()
	if resp.cancelled:
		return
	_on_picker_option_picked(panel, resp.payload)

func _on_editor_theme_changed():
	_create_style_boxes()

func _create_style_boxes():
	var ed_scale = EditorInterface.get_editor_scale()
	_style_box_h = StyleBoxFlat.new()
	_style_box_h.bg_color = EditorColors.get_theme_color(EditorColors.ThemeColor.BACKGROUND)
	_style_box_h.border_color = EditorColors.get_theme_color(EditorColors.ThemeColor.BASE)
	_style_box_h.border_width_left = 4 * ed_scale
	_style_box_h.border_width_right = 4 * ed_scale
	#_style_box_h.expand_margin_top = 6
	
	_style_box_v = StyleBoxFlat.new()
	_style_box_v.bg_color = EditorColors.get_theme_color(EditorColors.ThemeColor.BACKGROUND)
	_style_box_v.border_color = EditorColors.get_theme_color(EditorColors.ThemeColor.BASE)
	_style_box_v.border_width_top = 4 * ed_scale
	_style_box_v.border_width_bottom = 4 * ed_scale
	#_style_box_v.expand_margin_top = 6


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		EditorPanelSingleton.unregister_split_panel_instance(self)

class MoveablePanel extends Control:
	
	signal picker_clicked(panel)
	signal drag_started(panel)
	signal right_clicked(panel)
	signal swap_panels(from_panel, to_panel)
	signal move_panel(from_panel, to_panel, zone)
	
	var current_split_panel:PluginSplitPanel
	var _vbox:VBoxContainer
	var _scene_picker
	
	func _ready():
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		_vbox = VBoxContainer.new()
		add_child(_vbox)
		_vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		
		_scene_picker = Control.new()
		_vbox.add_child(_scene_picker)
		_scene_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var _scene_picker_button = Button.new()
		_scene_picker.add_child(_scene_picker_button)
		_scene_picker_button.text = "Pick Scene/File"
		_scene_picker_button.custom_minimum_size = Vector2(75, 35)
		_scene_picker_button.set_anchors_and_offsets_preset(PRESET_CENTER,Control.PRESET_MODE_KEEP_SIZE)
		_scene_picker_button.focus_mode = Control.FOCUS_NONE
		_scene_picker_button.pressed.connect(_on_picker_pressed)
		
		var dog_ear_size = 16 * EditorInterface.get_editor_scale()
		var _dog_ear = DogEarButton.new(DogEarButton.Position.TOP_LEFT, dog_ear_size)
		add_child(_dog_ear)
		_dog_ear.right_clicked.connect(func(): right_clicked.emit(self))
		_dog_ear.left_clicked.connect(func(): right_clicked.emit(self))
		
		set_split_panel()
		tree_entered.connect(_on_tree_entered)
	
	func _on_tree_entered():
		set_split_panel()
	
	func set_split_panel():
		var parent = get_parent()
		while is_instance_valid(parent):
			if parent is PluginSplitPanel:
				current_split_panel = parent
				break
			parent = parent.get_parent()
	
	func get_dock_overlay():
		return current_split_panel.dock_overlay
	
	func get_control():
		return _vbox.get_child(0)
	
	func _on_picker_pressed():
		picker_clicked.emit(self)
	
	func add_control(control:Control):
		if is_instance_valid(_scene_picker):
			_vbox.remove_child(_scene_picker)
			_scene_picker.queue_free()
		if _vbox.get_child_count() > 0:
			print("Panel already has control, can not save more than one.")
		_vbox.add_child(control)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	func _get_drag_data(_at_position):
		var preview = Label.new()
		preview.text = "Moving " + name
		set_drag_preview(preview)
		drag_started.emit(self)
		return { "type": Keys.DROP_DATA_TYPE, "node": self }


class DockOverlay extends Control:
	
	const EDGE_MARGIN = 0.25 # Top 25% creates a split, Center 50% swaps
	
	signal swap_panels(from_panel, to_panel)
	signal move_panel(from_panel, to_panel, zone)
	
	var panel_rects = {}
	var draw_data:= {}
	
	func _ready() -> void:
		mouse_exited.connect(_on_mouse_exited)
	
	func _on_mouse_exited():
		draw_data.clear()
		queue_redraw()
	
	func _draw() -> void:
		if draw_data.is_empty():
			return
		var color = Color.WHITE
		var rect = draw_data.rect as Rect2
		var zone = draw_data.zone as DropZone
		if zone == DropZone.CENTER:
			draw_rect(rect, color, false)
		else:
			match zone:
				DropZone.LEFT: draw_line(rect.position, rect.position + Vector2(0, rect.size.y), color)
				DropZone.RIGHT: draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, color)
				DropZone.UP: draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), color)
				DropZone.DOWN: draw_line(rect.position + Vector2(0, rect.size.y), rect.position + rect.size, color)
	
	
	func _can_drop_data(at_position, data):
		draw_data.clear()
		queue_redraw()
		
		var source_panel = data["node"]
		var to_panel = _get_panel_at_position(at_position)
		if to_panel == source_panel:
			return false
		var zone = _calculate_drop_zone(at_position)
		if zone == DropZone.NIL:
			return false
		if zone != DropZone.CENTER: # stop a split panel from being emptied
			if source_panel.current_split_panel.get_panel_count() < 2:
				return false
		
		var rect = _get_rect_at_position(at_position)
		if rect == null:
			return false
		draw_data = {
			"position": at_position,
			"panel": to_panel,
			"zone":zone,
			"rect": rect
		}
		return data is Dictionary and data.get("type") == Keys.DROP_DATA_TYPE

	func _drop_data(at_position, data):
		var source_panel = data["node"]
		var to_panel = _get_panel_at_position(at_position)
		if to_panel == source_panel:
			return
		var zone = _calculate_drop_zone(at_position)
		if zone == DropZone.NIL:
			return
		#prints(source_panel, to_panel, DropZone.keys()[zone])
		if zone == DropZone.CENTER:
			swap_panels.emit(source_panel, to_panel)
		else:
			move_panel.emit(source_panel, to_panel, zone)
	
	func _calculate_drop_zone(at_position: Vector2) -> DropZone:
		var rect = _get_rect_at_position(at_position)
		if rect == null:
			return DropZone.NIL
		var s = rect.size
		var localized_pos = at_position - rect.position
		if localized_pos.y < s.y * EDGE_MARGIN:
			return DropZone.UP
		if localized_pos.y > s.y * (1.0 - EDGE_MARGIN):
			return DropZone.DOWN
		if localized_pos.x < s.x * EDGE_MARGIN:
			return DropZone.LEFT
		if localized_pos.x > s.x * (1.0 - EDGE_MARGIN):
			return DropZone.RIGHT
		return DropZone.CENTER
	
	func _get_rect_at_position(at_position:Vector2):
		for rect:Rect2 in panel_rects.keys():
			var adj_rect = _get_adjusted_rect(rect)
			if adj_rect.has_point(at_position):
				return adj_rect
	
	func _get_panel_at_position(at_position:Vector2):
		for rect:Rect2 in panel_rects.keys():
			var adj_rect = _get_adjusted_rect(rect)
			if adj_rect.has_point(at_position):
				return panel_rects[rect]
	
	func _get_adjusted_rect(rect:Rect2):
		rect.position -= global_position
		return rect


class Layout:
	enum Direction {
		VERTICAL,
		HORIZONTAL
	}
	var _root: Dictionary = {}
	var _panel_refs: Array[Dictionary] = []
	
	func get_layout_data() -> Dictionary:
		return _root
	
	# Adds a panel.
	# path: The scene path (tscn or gd)
	# data: The dictionary for panel_dock_data
	# direction: "vertical" or "horizontal" (Applied if splitting an existing panel)
	# parent_idx: The index of the panel to split. -1 uses the most recently added panel.
	func add_panel(path: String, dock_data: Dictionary = {}, direction:=Direction.HORIZONTAL, parent_idx: int = -1):
		var new_panel_node = _create_panel_dict(path, dock_data)
		
		if _root.is_empty(): # Case 1: First element (Root)
			_root = new_panel_node.duplicate()  # We must duplicate to avoid reference issues if we modify it later
			_panel_refs.append(_root) # We store a reference to the root (which is currently a panel)
			return
		
		# Case 2: Splitting an existing panel
		var target_idx = parent_idx
		if target_idx == -1:
			target_idx = _panel_refs.size() - 1
			
		if target_idx < 0 or target_idx >= _panel_refs.size():
			push_error("LayoutBuilder: Invalid parent index ", target_idx)
			return

		# Get the dictionary of the panel we are about to split
		var target_node_ref = _panel_refs[target_idx]
		
		# We perform an "In-Place" replacement.
		# Because 'target_node_ref' is a reference to a dictionary inside '_root',
		# modifying it modifies the tree directly without needing parent pointers.
		
		# save the current data of the target (it's about to be pushed down a level)
		var old_content_node = target_node_ref.duplicate()
		
		# convert the target node into a Split container
		target_node_ref.clear() # Wipe the dict
		target_node_ref[Keys.TYPE] = Keys.TYPE_SPLIT
		var dir_string = Keys.DIR_HORIZONTAL
		if direction != Direction.HORIZONTAL:
			dir_string = Keys.DIR_VERTICAL
		target_node_ref[Keys.DIRECTION] = dir_string
		target_node_ref[Keys.OFFSET] = 0
		
		target_node_ref[Keys.CHILDREN] = [old_content_node, new_panel_node] # add children: [Old Content, New Content]
		
		# Update References
		# The dictionary at _panel_refs[target_idx] is now a SPLIT, not a PANEL.
		# We need to update that slot to point to the 'old_content_node' (which is now a child)
		# so that if the user references index 0 again, they split the panel, not the container.
		_panel_refs[target_idx] = old_content_node
		_panel_refs.append(new_panel_node) # add the new panel to list of references
	
	func _create_panel_dict(path: String, dock_data: Dictionary) -> Dictionary:
		return {
			Keys.TYPE: Keys.TYPE_PANEL,
			Keys.CONTENT_PATH: path,
			Keys.CONTENT_UID: UFile.path_to_uid(path),
			Keys.DOCK_DATA: dock_data
		}


class Keys:
	const DROP_DATA_TYPE = "plugin_panel_control"
	
	const METHOD_GET_DOCK_DATA = "get_dock_data"
	const METHOD_SET_DOCK_DATA = "set_dock_data"
	
	const PANEL_DOCK_DATA = "panel_dock_data"
	
	const TYPE = "type"
	const CHILDREN = "children"
	const DIRECTION = "direction"
	const DIR_VERTICAL = "vertical"
	const DIR_HORIZONTAL = "horizontal"
	const OFFSET = "offset"
	const CONTENT_PATH = "content_path"
	const CONTENT_UID = "content_uid"
	const DOCK_DATA = "panel_dock_data"

	const TYPE_SPLIT = "split"
	const TYPE_PANEL = "panel"
