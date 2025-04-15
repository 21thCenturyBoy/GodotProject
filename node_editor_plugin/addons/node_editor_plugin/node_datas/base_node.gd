# addons/toolsai/test/nodes/base_node.gd
@tool
class_name DataBaseNode
extends Node

@export var node_name: String
@export var children: Array
@export var wait_for_result: bool = false  # 是否等待结果
@export var timeout: float = 5.0  # 等待超时时间（秒）

func _init():
	children = []

func serialize() -> Dictionary:
	var data = {
		"node_type": get_node_type(),
		"node_name": node_name,
		"wait_for_result": wait_for_result,
		"timeout": timeout
	}
	#print("children", children)
	data["children"] = []
	for child in children:
		data["children"].append(child.serialize())
	return _serialize_extra(data)
	
func validate_prerequisites(data: Dictionary)-> bool:
	return true

func deserialize(data: Dictionary) -> void:
	node_name = data.get("node_name", "")
	children = []
	for child_data in data.get("children", []):
		#print("child_data", child_data);
		var child = create_node(child_data.get("node_type", ""))
		if child:
			child.deserialize(child_data)
			children.append(child)
	wait_for_result = data.get("wait_for_result", false)
	timeout = data.get("timeout", 5.0)
	_deserialize_extra(data)

func get_node_type() -> String:
	return "base"

func _serialize_extra(data: Dictionary) -> Dictionary:
	return data

func _deserialize_extra(data: Dictionary) -> void:
	pass

# 执行节点
func execute(context: Dictionary) -> Dictionary:
	var result = {
		"success": true,
		"message": "",
		"data": {},
		"start_time": Time.get_unix_time_from_system(),
		"end_time": 0,
		"duration": 0
	}
	
	# 执行节点特定的逻辑
	var node_result = _execute_node(context)
	result.merge(node_result)
	
	# 更新执行时间
	result.end_time = Time.get_unix_time_from_system()
	result.duration = result.end_time - result.start_time
	
	# 如果节点执行成功且需要等待结果，则等待
	if result.success and wait_for_result:
		var wait_result = _wait_for_result(context, result)
		result.merge(wait_result)
	
	# 如果节点执行成功，则执行子节点
	if result.success:
		for child in children:
			var child_result = child.execute(context)
			result.success = result.success and child_result.success
			if not child_result.success:
				result.message += "Child node '%s' failed: %s\n" % [child.node_name, child_result.message]
	
	return result

# 执行节点特定的逻辑（由子类实现）
func _execute_node(context: Dictionary) -> Dictionary:
	print("执行节点")
	return {
		"success": true,
		"message": "Base node executed",
		"data": {}
	}
func get_next_node(data:Dictionary) ->  Array:
	print("children.size()", children.size())
	var conform_list = []
	for children_node in children:
		if children_node.validate_prerequisites(data):
			conform_list.append(children_node)
	return conform_list
# 等待结果（由子类实现）
func _wait_for_result(context: Dictionary, result: Dictionary) -> Dictionary:
	return {
		"success": true,
		"message": "No waiting required",
		"data": {}
	}

static func create_node(type: String) -> DataBaseNode:
	match type:
		"base_node":  return DataBaseNode.new()
		"functioncalling_failed":  return DataBaseNode.new()
		"functioncalling_success":  return DataBaseNode.new()
		"return_message":  return DataBaseNode.new()
		"user_input":  return UserInputNode.new()
		_: return null

# 节点的输入框	
func message_input_text(text):
	pass

# 获取输入框的文本
func get_input_text() -> String:
	return ""

# 是否显示输入框
func has_message_input_text() -> bool:
	return false
	
func print_data() -> void:
	# 调用父类的打印方法
	print("Node Name: ", node_name)
	# 递归打印所有子节点的信息
	if children.size() > 0:
		print("Children:")
		for child in children:
			child.print_data()  # 递归调用子节点的 print_data 方法
