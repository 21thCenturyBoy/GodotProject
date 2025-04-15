@tool
extends Node

class_name NodeTemplateManager

# 模板目录路径
const TEMPLATES_PATH = "res://addons/node_editor_plugin/nodes/templates"

# 存储加载的模板
var templates: Dictionary = {}


# 初始化时加载所有模板
func _init():
	_load_templates()

# 加载所有模板
func _load_templates() -> void:
	var dir = DirAccess.open(TEMPLATES_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var template = _load_template_file(file_name)
				if template and template.has("id"):
					templates[template.id] = template
			file_name = dir.get_next()
	else:
		push_error("无法打开模板目录：" + TEMPLATES_PATH)

# 加载单个模板文件
func _load_template_file(file_name: String) -> Dictionary:
	var file_path = TEMPLATES_PATH.path_join(file_name)
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.parse_string(json_text)
		if json:
			return json
	
	push_error("无法加载模板文件：" + file_path)
	return {}

# 获取所有模板
func get_all_templates() -> Dictionary:
	return templates

# 根据ID获取模板
func get_template(template_id: String) -> Dictionary:
	if templates.has(template_id):
		return templates[template_id]
	return {}

# 获取模板ID列表
func get_template_ids() -> Array:
	return templates.keys()

# 获取模板名称列表 (用于显示在UI中)
func get_template_names() -> Array:
	var names = []
	for key in templates:
		var name = templates[key].get("name", key)
		names.push_back(name)
	return names

# 根据索引获取模板ID
func get_template_id_by_index(index: int) -> String:
	var keys = templates.keys()
	if index >= 0 and index < keys.size():
		return keys[index]
	return ""

# 获取模板数量
func get_template_count() -> int:
	return templates.size() 
