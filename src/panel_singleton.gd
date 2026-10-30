#! namespace EditorPanels class Singleton
class_name EditorPanelSingleton
extends "res://addons/_lib/singleton/src/singleton_base.gd" #! ext Singletons.Base

const PluginSplitPanel = preload("res://addons/_lib/editor_panels/src/plugin_split_panel.gd")
const PluginTabContainer = preload("res://addons/_lib/editor_panels/src/plugin_tab_container.gd")

const UObject = preload("uid://3ris0kamdyic") #! resolve UtilR.Objects.UObject

# Use 'PE_STRIP_CAST_SCRIPT' to auto strip type casts with plugin exporter, if the class is not a global name
const PE_STRIP_CAST_SCRIPT = preload("res://addons/_lib/editor_panels/src/panel_singleton.gd")
static func get_singleton_name() -> String:
	return "EditorPanel"

static func get_instance() -> EditorPanelSingleton:
	return _get_instance(PE_STRIP_CAST_SCRIPT)

static func instance_valid() -> bool:
	return _instance_valid(PE_STRIP_CAST_SCRIPT)

static func call_on_ready(callable, print_err:bool=true):
	_call_on_ready(PE_STRIP_CAST_SCRIPT, callable, print_err)

static func register_panel(_name:String, path:String, params:Dictionary={}) -> void:
	register_panel_data(create_registry_data(_name, path, params))

static func create_registry_data(_name:String, path:String, params:Dictionary={}) -> Dictionary:
	return {
		"name": _name,
		"path": path,
		"params": params
	}

static func register_panel_data(data:Dictionary) -> void:
	var instance = get_instance()
	var _name = data.get("name")
	if instance._panel_data.has(_name):
		print("Path already registered in EditorPanelSingleton Panels: %s" % _name)
		return
	instance._panel_data[_name] = data

static func unregister_panel(_name:String):
	var instance = get_instance()
	if instance._panel_data.has(_name):
		instance._panel_data.erase(_name)
		return
	print("Path not registered in EditorPanelSingleton Panels: %s" % _name)

static func get_registered_panels(show_hidden:=false):
	var instance = get_instance()
	var current_control_instances = instance.get_instanced_panels_and_tabs()
	var data = instance._panel_data
	var formatted_data = {}
	for panel_name in data.keys():
		var panel_data = data.get(panel_name)
		var _name = panel_data.get("name")
		var path = panel_data.get("path")
		var params = panel_data.get("params", {})
		if not show_hidden:
			var unique = params.get(Params.UNIQUE, false)
			if unique and path in current_control_instances:
				continue
		_name = _get_unique_name(_name, formatted_data.keys())
		formatted_data[_name] = {
			"path":path
		}
	
	return formatted_data

static func register_tab(_name:String, path:String, params:Dictionary={}) -> void:
	register_tab_data(create_registry_data(_name, path, params))

static func register_tab_data(data:Dictionary) -> void:
	var instance = get_instance()
	var _name = data.get("name")
	if instance._tab_data.has(_name):
		print("Path already registered in EditorPanelSingleton Tabs: %s" % _name)
		return
	instance._tab_data[_name] = data

static func unregister_tab(_name:String):
	var instance = get_instance()
	if instance._tab_data.has(_name):
		instance._tab_data.erase(_name)
		return
	print("Path not registered in EditorPanelSingleton Tabs: %s" % _name)

static func get_registered_tabs(show_hidden:=false):
	var instance = get_instance()
	var current_control_instances = instance.get_instanced_panels_and_tabs()
	var data = instance._tab_data
	var formatted_data = {}
	for panel_name in data.keys():
		var panel_data = data.get(panel_name)
		var _name = panel_data.get("name")
		var path = panel_data.get("path")
		var params = panel_data.get("params", {})
		if not show_hidden:
			var unique = params.get(Params.UNIQUE, false)
			if unique and path in current_control_instances:
				continue
		_name = _get_unique_name(_name, formatted_data.keys())
		formatted_data[_name] = {
			"path":path
		}
	
	return formatted_data

static func register_layout(_name:String, layout, icon=null) -> void:
	var instance = get_instance()
	if instance._layout_data.has(_name):
		print("Name already registered in EditorPanelSingleton Layouts: %s" % _name)
		return
	instance._layout_data[_name] = {
		"layout": layout,
		"icon":icon
	}

static func unregister_layout(_name:String):
	var instance = get_instance()
	if instance._layout_data.has(_name):
		instance._layout_data.erase(_name)
		return
	print("Name not registered in EditorPanelSingleton Layouts: %s" % _name)

static func get_registered_layouts():
	var instance = get_instance()
	return instance._layout_data

static func get_layout(_name:String):
	var instance = get_instance()
	if instance._layout_data.has(_name):
		return instance._layout_data.get(_name)
	else:
		print("Name not registered in EditorPanelSingleton Layouts: %s" % _name)

static func _get_unique_name(_name:String, current_names:Array):
	var count = 1
	var _new_name = _name
	while _new_name in current_names:
		_new_name = _name + "(%s)" % count
		count += 1
	return _new_name

static func register_split_panel_instance(split_panel):
	var instance = get_instance()
	instance._split_panel_instances.append(split_panel)

static func unregister_split_panel_instance(split_panel):
	var instance = get_instance()
	instance.clean_split_panel_instances()
	instance._split_panel_instances.erase(split_panel)

static func get_split_panel_instances():
	var instance = get_instance()
	instance.clean_split_panel_instances()
	return instance._split_panel_instances

static func get_split_panel_ancestor(node:Node):
	var panel_instances = get_split_panel_instances()
	for inst:Node in panel_instances:
		if inst.is_ancestor_of(node):
			return inst

func clean_split_panel_instances():
	var valid = []
	for ins in _split_panel_instances:
		if is_instance_valid(ins):
			valid.append(ins)
	_split_panel_instances = valid

func get_instanced_panels_and_tabs():
	var instances = []
	for inst:PluginSplitPanel in _split_panel_instances:
		for panel:PluginSplitPanel.MoveablePanel in inst.get_panels():
			var content = panel.get_control()
			instances.append(UObject.get_object_file_path(content))
			if content is PluginTabContainer:
				for tab in content.get_all_tab_controls():
					instances.append(UObject.get_object_file_path(tab))
	return instances


@warning_ignore_start("unused_private_class_variable")
var _layout_data:= {}
var _panel_data:= {}
var _tab_data:= {}
@warning_ignore_restore("unused_private_class_variable")
var _split_panel_instances:= []


func _ready() -> void:
	_register_panels.call_deferred()

func _register_panels():
	register_panel("Plugin Tabs", PluginTabContainer.get_scene_path())

func _get_ready_bool() -> bool:
	return is_node_ready()


class Params:
	const UNIQUE = &"UNIQUE"
