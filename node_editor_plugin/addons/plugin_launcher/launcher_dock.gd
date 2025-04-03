@tool
extends Control

# 定义信号
signal launch_node_editor
signal load_json_data(json_string)

# 当启动节点编辑器按钮被点击时
func _on_launch_node_editor_btn_pressed() -> void:
	emit_signal("launch_node_editor")

# 当加载JSON按钮被点击时
func _on_load_json_btn_pressed() -> void:
	var json_text = $VBoxContainer/JsonTextEdit.text.strip_edges()
	if json_text.is_empty():
		print("错误：JSON数据为空")
		return
	
	emit_signal("load_json_data", json_text)

# 当选择JSON文件按钮被点击时
func _on_load_json_file_btn_pressed() -> void:
	$FileDialog.popup_centered()

# 当文件被选择时
func _on_file_dialog_file_selected(path: String) -> void:
	if not FileAccess.file_exists(path):
		print("错误：文件不存在")
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	$VBoxContainer/JsonTextEdit.text = json_string
	emit_signal("load_json_data", json_string)

# 提供给外部脚本调用的方法
func set_json_data(json_string: String) -> void:
	$VBoxContainer/JsonTextEdit.text = json_string
	emit_signal("load_json_data", json_string)

# 更新JSON文本框的内容（用于接收节点编辑器导出的自定义数据）
func update_json_text(json_string: String) -> void:
	$VBoxContainer/JsonTextEdit.text = json_string
	print("JSON文本框已更新，显示节点编辑器导出的数据") 
