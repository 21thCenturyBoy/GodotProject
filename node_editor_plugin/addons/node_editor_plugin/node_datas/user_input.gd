# addons/toolsai/test/nodes/user_input_node.gd
@tool
class_name UserInputNode
extends DataBaseNode

@export var input_text: String

func get_node_type() -> String:
	return "user_input"

func validate_prerequisites(data: Dictionary)-> bool:
	return true

func _serialize_extra(data: Dictionary) -> Dictionary:
	data["input_text"] = input_text
	return data

func _deserialize_extra(data: Dictionary) -> void:
	input_text = data.get("input_text", "")

# 执行节点特定的逻辑
func _execute_node(context: Dictionary) -> Dictionary:
	print(input_text)
	return {
			"success": true,
			"message": "发送成功",
	}

# 等待结果
func _wait_for_result(context: Dictionary, result: Dictionary) -> Dictionary:
	# 用户输入节点通常不需要等待结果
	return {
		"success": true,
		"message": "No waiting required for user input",
		"data": {}
	}
func message_input_text(text):
	input_text = text

func get_input_text() -> String:
	return input_text

func has_message_input_text() -> bool:
	return true
