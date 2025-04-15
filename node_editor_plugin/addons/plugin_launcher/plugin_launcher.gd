@tool
extends EditorPlugin

# 插件启动器面板
var launcher_dock: Control
# 节点编辑器插件实例
var node_editor_plugin_instance = null
# 节点编辑器视图实例
var editor_view = null

const CustomData = preload("res://addons/node_editor_plugin/node_editor_view.gd").CustomData

func _enter_tree() -> void:
	# 创建启动器面板
	launcher_dock = preload("res://addons/plugin_launcher/launcher_dock.tscn").instantiate()
	
	# 添加到编辑器右侧面板
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, launcher_dock)
	
	# 连接信号
	launcher_dock.connect("launch_node_editor", _on_launch_node_editor)
	launcher_dock.connect("load_json_data", _on_load_json_data)

func _exit_tree() -> void:
	# 断开与节点编辑器视图的信号连接
	_disconnect_from_editor_view()
	
	# 移除启动器面板
	remove_control_from_docks(launcher_dock)
	launcher_dock.queue_free()
	
	# 释放节点编辑器插件引用
	node_editor_plugin_instance = null
	editor_view = null

# 启动节点编辑器插件
func _on_launch_node_editor() -> void:
	print("正在启动节点编辑器...")
	
	# 加载并初始化节点编辑器插件
	var plugin_script = load("res://addons/node_editor_plugin/node_editor_plugin.gd")
	if plugin_script:
		node_editor_plugin_instance = plugin_script.new()
		node_editor_plugin_instance._enter_tree()
		
		# 获取编辑器视图并连接信号
		editor_view = _find_editor_view()
		if editor_view:
			_connect_to_editor_view()
			
		# 测试模拟传入
		# 获取编辑器视图并传递JSON数据
		var root_node = DataBaseNode.create_node("user_input")
		root_node.node_name = "Root"
		root_node.input_text = "测试输入"
		root_node.children = []

		var child_node = DataBaseNode.create_node("user_input")
		child_node.node_name = "Child 1"
		child_node.input_text = "测试输入1"
		child_node.children = []
		root_node.children.append(child_node)

		var child_node2 = DataBaseNode.create_node("user_input")
		child_node2.node_name = "Child 2"
		child_node2.input_text = "测试输入2"
		child_node2.children = []
		root_node.children.append(child_node2)

		var data = CustomData.new()
		data.module_name = "test_module_name"
		data.tool_name = "test_tool_name"
		data.case_name = "test_case_name"
		data.root_node = root_node

		
		if editor_view and editor_view.has_method("_import_custom_data"):
			# 传入解析后的字典数据，而不是原始字符串
			editor_view._import_custom_data(data)
			print("成功：JSON数据已加载到节点编辑器")
		else:
			print("错误：无法找到节点编辑器视图或导入方法")
		print("成功：节点编辑器已启动")
		return
	
	print("错误：无法启动节点编辑器插件")
# -----------------模拟传入符串...-----------------


# 将JSON数据传递给节点编辑器
func _on_load_json_data(json_string: String) -> void:
	print("正在加载JSON数据到节点编辑器...")
	
	# 确保节点编辑器已启动
	if not node_editor_plugin_instance:
		_on_launch_node_editor()
		await get_tree().process_frame
	
	# 再次检查节点编辑器是否已启动
	if not node_editor_plugin_instance:
		print("错误：无法启动节点编辑器插件")
		return
	
	# 确保有编辑器视图
	if not editor_view:
		editor_view = _find_editor_view()
		if editor_view:
			_connect_to_editor_view()
	
	# 解析JSON字符串为字典
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("错误：JSON解析失败 - ", json.get_error_message(), " 在行 ", json.get_error_line())
		return
		
	var json_data = json.get_data()
	if typeof(json_data) != TYPE_DICTIONARY:
		print("错误：JSON数据不是有效的字典格式")
		return
	


# 查找节点编辑器视图
func _find_editor_view() -> Control:
	# 从插件实例获取编辑器视图
	if node_editor_plugin_instance and "editor_view" in node_editor_plugin_instance:
		return node_editor_plugin_instance.editor_view
	return null

# 连接到节点编辑器视图的信号
func _connect_to_editor_view() -> void:
	if not editor_view:
		return
	

# 断开与节点编辑器视图的信号连接
func _disconnect_from_editor_view() -> void:
	if not editor_view:
		return

