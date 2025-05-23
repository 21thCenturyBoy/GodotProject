@tool
extends Control

class_name NodeEditorView # 添加类名以便引用静态方法

# 调试标志
var debug_mode: bool = true # 临时启用调试模式

# 节点容器
var node_container: Control
var nodes: Dictionary = {} # Node节点字典
var node_render_queue: Array = [] # 节点渲染队列，决定绘制顺序
var connections: Array = []
var selected_node: Control = null
var dragging_node: bool = false
var drag_started: bool = false # 添加一个标志，表示拖拽是否真正开始
var drag_start_pos: Vector2
var drag_offset: Vector2 # 拖拽偏移
var drag_preview_rect: Rect2 # 拖拽预览矩形
var connection_start_slot: Control = null

# 连接线编辑状态
var creating_connection: bool = false # 是否正在创建连接线
var connection_start_node: Control = null # 起始节点
var connection_start_slot_idx: int = -1 # 起始槽索引
var connection_start_is_output: bool = true # 起始槽是否为输出槽
var connection_end_pos: Vector2 = Vector2.ZERO # 连接线终点位置

# 连接线编辑参数
var click_line_tolerance: float = 15.0 # 点击线容差度

# 画布拖拽相关变量
var canvas_offset = Vector2.ZERO # 画布偏移量
var dragging_canvas = false # 是否正在拖拽画布
var canvas_drag_start_pos = Vector2.ZERO # 拖拽开始位置
var canvas_name = "未命名" # 画布名称

# 预加载节点场景和脚本
const BaseNodeScene = preload("res://addons/node_editor_plugin/nodes/base_node.tscn")
const BaseNodeScript = preload("res://addons/node_editor_plugin/nodes/base_node.gd")
const NodeTemplateManagerScript = preload("res://addons/node_editor_plugin/nodes/node_templates_manager.gd")
const UserInputNodeScript = preload("res://addons/node_editor_plugin/nodes/user_input.gd")

# 信号
signal editor_view_destroyed
signal export_custom_data(data)

class CustomData extends Node:
	var module_name: String = ""
	var tool_name: String = ""
	var case_name: String = ""
	var root_node: DataBaseNode = null
	pass

# 自定义数据
var custom_data: CustomData = null
var module_name: String = ""
var tool_name: String = ""
var case_name: String = ""

# 显示tips队列
var show_tips_queue = []

# 连接线绘制器
var connection_drawer: ConnectionDrawer

# 预览矩形
var preview_control: Control

# 节点模板管理器
var template_manager: NodeTemplateManager

func _ready():
	if debug_mode:
		print("编辑器视图准备就绪")
	
	# 初始化模板管理器
	template_manager = NodeTemplateManager.new()
	
	# 获取UI元素引用
	node_container = $NodeContainer
	
	# 确保所有控件都是可见的
	visible = true
	if node_container:
		node_container.visible = true
		# 确保NodeContainer控件有正确的尺寸
		node_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# 让节点容器接收输入事件但也传递给子节点
		node_container.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# 创建连接线绘制器
		connection_drawer = ConnectionDrawer.new(self)
		connection_drawer.name = "ConnectionDrawer"
		connection_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		connection_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE # 忽略鼠标事件
		connection_drawer.connections = connections
		connection_drawer.nodes = nodes
		connection_drawer.editor_view = self # 确保引用到编辑器视图
		node_container.add_child(connection_drawer)
		
		# 创建预览控件，确保它在最顶层
		preview_control = PreviewRect.new()
		preview_control.name = "PreviewRect"
		preview_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_control.mouse_filter = Control.MOUSE_FILTER_IGNORE # 忽略鼠标事件
		preview_control.visible = false
		add_child(preview_control)
		
		if debug_mode:
			print("NodeContainer、ConnectionDrawer和PreviewRect已设置")
	else:
		push_error("NodeContainer未找到!")
	
	# 设置该视图接收所有输入事件
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 连接按钮信号
	_connect_buttons()

	if debug_mode:
		print("界面初始化完成")

func _exit_tree():
	emit_signal("editor_view_destroyed")
	if debug_mode:
		print("节点编辑器视图已被销毁，信号已触发。")

func _connect_buttons():
	# 直接连接按钮事件，不使用信号机制
	var add_btn = $ToolBar/AddNodeButton
	if add_btn:
		if add_btn.is_connected("pressed", _on_add_node_pressed):
			add_btn.disconnect("pressed", _on_add_node_pressed)
		add_btn.pressed.connect(_on_add_node_pressed)
		if debug_mode:
			print("添加节点按钮已连接")
	
	var delete_btn = $ToolBar/DeleteNodeButton
	if delete_btn:
		if delete_btn.is_connected("pressed", _on_delete_node_pressed):
			delete_btn.disconnect("pressed", _on_delete_node_pressed)
		delete_btn.pressed.connect(_on_delete_node_pressed)
		if debug_mode:
			print("删除节点按钮已连接")
		
	# 添加自动排列按钮连接
	var arrange_btn = $ToolBar/ArrangeButton
	if arrange_btn:
		if arrange_btn.is_connected("pressed", _on_auto_arrange_pressed):
			arrange_btn.disconnect("pressed", _on_auto_arrange_pressed)
		arrange_btn.pressed.connect(_on_auto_arrange_pressed)
		if debug_mode:
			print("自动排列按钮已连接")
		
	var save_btn = $ToolBar/SaveButton
	if save_btn:
		if save_btn.is_connected("pressed", _on_save_pressed):
			save_btn.disconnect("pressed", _on_save_pressed)
		save_btn.pressed.connect(_on_save_pressed)
		if debug_mode:
			print("保存按钮已连接")

# 导入自定义数据
func _import_custom_data(test_case: CustomData) -> void:
	if debug_mode:
		print("开始导入自定义数据")
	
	# 设置模块名称
	module_name = test_case.module_name
	# 设置工具名称
	tool_name = test_case.tool_name
	# 设置用例名称
	case_name = test_case.case_name

	# 提取蓝图名称
	update_canvas_name(test_case.module_name + "/" + test_case.tool_name + "/" + test_case.case_name)

	# 清除现有节点和连接
	for node in nodes.values():
		node.queue_free()
	nodes.clear()
	node_render_queue.clear() # 清空渲染队列
	connections.clear()
	
	# 更新连接线绘制器的引用
	if connection_drawer:
		connection_drawer.connections = connections
		connection_drawer.nodes = nodes
	
	# 获取节点容器的大小
	var container_size = node_container.size
	# 计算中心点偏移
	var center_offset = Vector2(container_size.x / 2, container_size.y / 2)
	
	# 导入根节点及其子节点
	var root_data = test_case.root_node
	_create_node_hierarchy(root_data, null, center_offset, 0)
	
	# 确保所有节点都重绘
	for node in nodes.values():
		node.queue_redraw()
	
	# 重绘连接线
	if connection_drawer:
		connection_drawer.queue_redraw()
	
	# 自动排列节点以获得更好的布局
	_auto_arrange_nodes()
	
	custom_data = test_case
	
	if debug_mode:
		print("自定义数据导入完成，已加载 " + str(nodes.size()) + " 个节点和 " + str(connections.size()) + " 个连接")
	

# 根据模版id创建节点
func _create_node_from_template_id(template_id: String) -> Node:
	var template = template_manager.get_template(template_id)
	if template.is_empty():
		print("模板不存在: " + template_id)
		return null
	
	# 创点实例
	var node = BaseNodeScene.instantiate()
	if template.get("type", 0) == BaseNodeScript.NodeType.USER_INPUT:
		node.set_script(UserInputNodeScript)
	else:
		# 确保节点接收输入事件
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node

# 导出自定义数据
func _on_save_pressed() -> void:
	if debug_mode:
		print("开始导出自定义数据")
	
	# 查找根节点（没有输入槽或无连接的输入槽的节点）
	var root_nodes = _find_root_nodes()
	
	if root_nodes.is_empty():
		_show_message("导出失败：找不到根节点。")
		return
		
	if root_nodes.size() > 1:
		_show_message("导出失败：找到多个根节点，自定义数据格式只支持单根节点。")
		return
	
	var root_node = root_nodes[0]
	
	# 保存自定义数据格式
	var root_custom_node = _node_to_custom_data(root_node)

	show_tips("保存成功",Color.GREEN,Color.BLACK)
	# 触发信号，传递数据
	emit_signal("export_custom_data", root_custom_node, canvas_name)

# 将节点转换为自定义数据格式，并根据图的连线创建子的树形关系，并返回自定义数据
func _node_to_custom_data(node: Control) -> DataBaseNode:
	var node_id = node.get("node_id") if node.get("node_id") else node.name
	
	if debug_mode:
		print("处理节点: ", node_id)
	
	# 获取节点的 TestBaseNode
	var test_base_node = node.get("cur_test_base_node")
	if not test_base_node:
		if debug_mode:
			print("错误：节点没有关联的 TestBaseNode: ", node_id)
		return null
	
	# 处理特殊节点类型（如 UserInputNode）
	if node.get_script() == UserInputNodeScript:
		# 获取 UserInputNode 的 text_edit 控件
		var text_edit = node.get_node("MessageEditor")
		if text_edit and text_edit is TextEdit:
			var input_text = text_edit.text # 获取文本数据
			test_base_node.message_input_text(input_text) # 设置文本到 TestBaseNode
	
	# 检查输出槽数量
	var outputs_count = 0
	if "outputs" in node:
		var outputs = node.outputs
		if outputs is Array:
			outputs_count = outputs.size()
	
	if outputs_count != 1 and outputs_count != 0:
		if debug_mode:
			print("警告：节点输出槽数量异常，节点ID: ", node_id, " 输出槽数量: ", outputs_count)
	
	# 清空现有的子节点列表，以便重新构建
	test_base_node.children.clear()
	
	# 如果有输出槽，处理连接
	if outputs_count > 0:
		# 获取第一个输出槽的所有连接
		var output_slot_idx = 0 # 使用第一个输出槽
		var children_connections = []
		
		# 收集所有使用第一个输出槽的连接
		for connection in connections:
			if connection["from_node"] == node_id and connection["from_slot"] == output_slot_idx:
				children_connections.append(connection)
		
		# 打印所有连接
		for connection in connections:
			print("connection: ", connection)
		print("connections个数: ", connections.size())

		# 打印所有连接
		for connection in children_connections:
			print("connection: ", connection)
		print("children_connections个数: ", children_connections.size())
		
		# 按连接顺序处理所有子节点
		for connection in children_connections:
			var child_id = connection["to_node"]
			if nodes.has(child_id):
				var child_node = nodes[child_id]
				
				# 递归处理子节点的连接
				var child_test_base_node = _node_to_custom_data(child_node)
				if child_test_base_node:
					# 添加到子节点列表
					test_base_node.children.append(child_test_base_node)
					
					if debug_mode:
						print("添加子节点: ", node_id, " -> ", child_id, " 位置: ", test_base_node.children.size() - 1)

	return test_base_node

# 显示tips
func show_tips(tips:String,text_color:Color = Color.WHITE,background_color:Color = Color.BLACK) -> void:

	var tool_bar = $ToolBar
	
	# 在ToolBar下方 显示tips
	var tips_label = Label.new()
	tips_label.text = tips
	tips_label.add_theme_color_override("font_color", text_color)
	tips_label.add_theme_color_override("background_color", background_color)

	# 获取视图右侧位置
	var view_right = tool_bar.size.x

	# 加入一个显示队列
	show_tips_queue.append(tips_label)

	tips_label.position = Vector2(tool_bar.size.x - 100, tool_bar.size.y + show_tips_queue.size() * 20)
	tips_label.size = Vector2(tool_bar.size.x, 20)
	tips_label.visible = true

	tool_bar.get_parent().add_child(tips_label)

	# 添加一个动画效果3秒后消失
	var tween = create_tween()
	tween.tween_property(tips_label, "modulate", Color(1, 1, 1, 0), 3)
	tween.tween_callback(
		# 从显示队列中移除，更改位置
		func(): 
			if show_tips_queue.size() > 0:
				show_tips_queue.erase(tips_label)
				tips_label.queue_free()
				tips_label = null
			for i in range(show_tips_queue.size()):
				show_tips_queue[i].position = Vector2(tool_bar.size.x - 100, tool_bar.size.y + i * 20)
	)  # Align this closing parenthesis correctly

# 添加节点按钮
func _on_add_node_pressed() -> void:
	if debug_mode:
		print("添加节点按钮被点击")
	
	# 显示选择节点模板的对话框
	_show_template_selection_dialog()

# 显示选择节点模板的对话框
func _show_template_selection_dialog() -> void:
	# 创建对话框
	var dialog = ConfirmationDialog.new()
	dialog.title = "选择节点模板"
	dialog.ok_button_text = "确定"
	dialog.cancel_button_text = "取消"
	dialog.size = Vector2(800, 600)
	dialog.exclusive = true
	
	# 创建布局
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	
	# 添加说明标签
	var label = Label.new()
	label.text = "请选择要添加的节点类型:"
	vbox.add_child(label)
	
	# 创建模板列表
	var template_list = ItemList.new()
	template_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	template_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	template_list.select_mode = ItemList.SELECT_SINGLE
	
	# 填充模板列表
	var templates = template_manager.get_all_templates()
	for id in templates:
		var template = templates[id]
		var template_name = template.get("name", id)
		var description = template.get("description", "")
		template_list.add_item(template_name)
		if description:
			var last_idx = template_list.get_item_count() - 1
			template_list.set_item_tooltip(last_idx, description)
	
	# 如果没有模板，显示提示
	if template_list.get_item_count() == 0:
		template_list.add_item("默认节点")
	
	# 默认选择第一项
	if template_list.get_item_count() > 0:
		template_list.select(0)
	
	vbox.add_child(template_list)
	
	# 添加描述区域
	var description_label = Label.new()
	description_label.text = "描述: "
	vbox.add_child(description_label)
	
	# 添加描述文本
	var description_text = RichTextLabel.new()
	description_text.fit_content = true
	description_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_text.scroll_active = true
	description_text.bbcode_enabled = true
	
	# 设置初始描述
	if template_list.get_item_count() > 0:
		var idx = 0
		var template_id = template_manager.get_template_id_by_index(idx)
		if template_id:
			var template = template_manager.get_template(template_id)
			description_text.text = template.get("description", "无描述")
		else:
			description_text.text = "创建一个默认节点"
	
	vbox.add_child(description_text)
	
	# 当选择改变时更新描述
	template_list.item_selected.connect(func(idx):
		var template_id = template_manager.get_template_id_by_index(idx)
		if template_id:
			var template = template_manager.get_template(template_id)
			description_text.text = template.get("description", "无描述")
		else:
			description_text.text = "创建一个默认节点"
	)
	
	# 添加布局到对话框
	dialog.add_child(vbox)
	
	# 设置对话框边距
	dialog.get_ok_button().size_flags_horizontal = Button.SIZE_SHRINK_END
	dialog.get_cancel_button().size_flags_horizontal = Button.SIZE_SHRINK_END
	
	# 添加到场景树
	add_child(dialog)
	
	# 连接确认信号
	dialog.confirmed.connect(func():
		var selected_idx = template_list.get_selected_items()
		if selected_idx.size() > 0:
			var idx = selected_idx[0]
			var template_id = template_manager.get_template_id_by_index(idx)
			if template_id:
				_create_node_from_template(template_id, true)
			else:
				printerr("没有找到模板: ", template_id)
	)
	
	# 显示对话框
	dialog.popup_centered()

# 从模板创建节点
func _create_node_from_template(template_id: String, redraw: bool) -> Control:
	if debug_mode:
		print("从模板创建节点: " + template_id)
	
	var template = template_manager.get_template(template_id)
	if template.is_empty():
		print("模板不存在: " + template_id)
		return
	
	# 设置属性
	var properties = {}
	if template.has("properties"):
		properties = template.get("properties", {})

	# 创建基本节点
	var node = _create_node_from_template_id(template_id)

	var node_data = DataBaseNode.create_node(template_id)

	var node_id = create_node_id()
	set_node_base_property(node_id, node, node_data, template, template_id, properties)
	
	# 强制更新消息节点显示
	if node.has_method("update_message_display"):
		node.call("update_message_display")
	
	# 获取节点容器的大小
	var container_size = node_container.size
	
	# 获取模板中的尺寸或使用默认值
	var node_size = Vector2(200, 150)
	if template.has("size"):
		var size_data = template.get("size", {})
		node_size.x = float(size_data.get("x", 200))
		node_size.y = float(size_data.get("y", 150))
	
	# 计算中心位置，考虑节点大小的偏移和画布偏移
	var center_pos = Vector2(
		(container_size.x - node_size.x) / 2,
		(container_size.y - node_size.y) / 2
	)
	node.position = center_pos
	node.custom_minimum_size = node_size
	
	# 添加到场景和字典
	node_container.add_child(node)
	nodes[node_id] = node
	
	# 添加到渲染队列的最前面
	node_render_queue.push_front(node)
	
	if debug_mode:
		print("从模板创建节点完成: " + node_id + " 位置: " + str(node.position))
	
	# 触发重绘
	if redraw:
		queue_redraw()
	return node


# 生成唯一节点ID
func create_node_id() -> String:
	var node_id
	var autoId = 0
	for i in range(1000): # 防止无限循环,默认最大1000个节点
		node_id = "Node_" + str(i)
		if nodes.has(node_id): continue
		else:
			autoId = i
			break
	return node_id

# 设置节点基础属性
func set_node_base_property(node_id: String, node: Node, node_data: DataBaseNode,config:Dictionary, template_id:String, properties:Dictionary) -> void:
	node.name= node_id

	node.set("node_id", node_id)
	node.set("node_name", config.get("name", ""))
	node.set("cur_test_base_node", node_data)
	node.set("template_id", template_id)

	var inputs = config.get("inputs", [])
	node.set("inputs", inputs)

	var outputs = config.get("outputs", [])
	node.set("outputs", outputs)

	var type_value = config.get("type", 0)
	node.set("node_type", type_value)

	node.set("properties", properties)

	# 设置颜色（如果模板中有定义）
	if config.has("color"):
		var color_str = config.get("color", "")
		if color_str:
			var color_components = color_str.split(",")
			if color_components.size() >= 3:
				var r = float(color_components[0])
				var g = float(color_components[1])
				var b = float(color_components[2])
				var a = 1.0
				if color_components.size() > 3:
					a = float(color_components[3])
				
				# 创建颜色对象
				var custom_color = Color(r, g, b, a)
				node.set("custom_color", custom_color)


# 创建节点层次结构
func _create_node_hierarchy(node_data: DataBaseNode, parent_node, center_position: Vector2, level: int) -> Control:
	if debug_mode:
		print("创建节点层次结构，层级: ", level)
	
	# 创建当前节点
	var node_type = node_data.get_node_type()
	
	var template = template_manager.get_template(node_type)

	# 解析属性字典
	var properties = {}
	if node_data.has_message_input_text():
		var input_text = node_data.get_input_text()
		properties = {
			"message": {
				"type": "string",
				"value": input_text
			}
		}
	
	# 创点实例
	var node = _create_node_from_template_id(node_type)

	# 设置节点基础属性
	var node_id = create_node_id()
	set_node_base_property(node_id, node, node_data, template, node_type, properties)

	# 强制更新消息节点显示
	if node.has_method("update_message_display"):
		node.call("update_message_display")

	
	# 设置节点位置
	var horizontal_offset = 300 # 水平间距
	var vertical_offset = 100 # 垂直间距
	var x_pos = center_position.x + level * horizontal_offset
	var y_pos = center_position.y
	
	# 调整位置以避免重叠
	if level > 0:
		y_pos += (nodes.size() % 3) * vertical_offset
	
	node.position = Vector2(x_pos, y_pos)
	node.custom_minimum_size = Vector2(200, 150) # 默认大小
	
	# 添加到场景和字典
	node_container.add_child(node)
	nodes[node_id] = node
	node_render_queue.append(node)
	
		# 确保有子节点信息
	var children = node_data.children
	# 递归创建子节点
	if children.size() > 0:
		for i in range(children.size()):
			var child_data = children[i]
			
			# 计算子节点的位置偏移
			var child_center = Vector2(
				center_position.x,
				center_position.y + (i - children.size() / 2.0) * vertical_offset
			)
			
			# 递归创建子节点
			var child_node = _create_node_hierarchy(child_data, node, child_center, level + 1)
			
			# 创建从父节点到子节点的连接 - 始终使用父节点的第一个输出槽(索引0)
			if child_node != null:
				var connection = {
					"from_node": node_id,
					"to_node": child_node.get("node_id"),
					"from_slot": 0, # 始终使用第一个输出槽(0)
					"to_slot": 0 # 子节点的第一个输入槽
				}
				connections.append(connection)
				
				if debug_mode:
					print("创建连接: ", node_id, "[0] -> ",
						  child_node.get("node_id"), "[0]")
	
	if debug_mode:
		print("节点创建完成: " + node_id + " 位置: " + str(node.position))
	
	return node
# 查找根节点（没有输入槽或无连接的输入槽的节点）
func _find_root_nodes() -> Array:
	var root_candidates = []
	
	if debug_mode:
		print("开始查找根节点，总节点数: ", nodes.size())
		for node_id in nodes:
			var node_name = nodes[node_id].node_name if "node_name" in nodes[node_id] else nodes[node_id].name
			print("节点: ", node_id, " 名称: ", node_name)
	
	# 遍历所有节点
	for node_id in nodes:
		var node = nodes[node_id]
		
		# 获取节点输入槽数量
		var inputs_count = 0
		if "inputs" in node:
			var inputs = node.inputs
			if inputs is Array:
				inputs_count = inputs.size()
		
		if debug_mode:
			print("检查节点: ", node_id, " 输入槽数量: ", inputs_count)
		
		# 如果没有输入槽，则为根节点候选
		if inputs_count == 0:
			if debug_mode:
				print("找到没有输入槽的根节点候选: ", node_id)
			root_candidates.append(node)
			continue
		
		# 检查输入槽是否有连接
		var has_incoming_connection = false
		for connection in connections:
			if connection["to_node"] == node_id:
				has_incoming_connection = true
				if debug_mode:
					print("节点 ", node_id, " 有输入连接")
				break
		
		# 如果有输入槽但没有连接，也是根节点候选
		if not has_incoming_connection:
			if debug_mode:
				print("找到没有输入连接的根节点候选: ", node_id)
			root_candidates.append(node)
	
	if debug_mode:
		print("找到的根节点候选数量: ", root_candidates.size())
	
	return root_candidates

# 将节点转换为自定义数据格式（递归）
func _node_to_custom_data_dict(node) -> Dictionary:
	var node_id = node.get_meta("node_id") if node.has_meta("node_id") else node.name
	
	if debug_mode:
		print("处理节点: ", node_id)
	
	# 基本节点数据
	var node_data = {
		"children": [],
		"input_text": "",
		"node_name": "",
		"node_type": "user_input" # 因为我们已验证所有节点都是消息节点
	}
	
	# 获取节点名称
	if node.has_meta("node_name"):
		node_data["node_name"] = node.get_meta("node_name")
	else:
		# 尝试从脚本获取
		node_data["node_name"] = node.node_name if "node_name" in node else node.name
	
	# 获取消息文本
	if "properties" in node:
		var properties = node.properties
		if properties is Dictionary and properties.has("message") and properties["message"].has("value"):
			node_data["input_text"] = properties["message"]["value"]
			
			if debug_mode:
				print("获取到消息文本: ", node_data["input_text"])
	
	# 查找所有以该节点为起点的连接
	var children_connections = []
	for connection in connections:
		if connection["from_node"] == node_id:
			children_connections.append(connection)
	
	# 处理所有子节点
	for connection in children_connections:
		var child_id = connection["to_node"]
		if nodes.has(child_id):
			var child_node = nodes[child_id]
			# 递归处理子节点
			var child_data = _node_to_custom_data_dict(child_node)
			node_data["children"].append(child_data)
	
	return node_data


# 重写_gui_input函数
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 检查是否在拖动画布
				if not dragging_node and not creating_connection:
					dragging_canvas = true
					canvas_drag_start_pos = get_global_mouse_position()
				
				# 点击空白区域则取消选中节点
				if debug_mode:
					print("点击空白区域")
				select_node(null)
				
				# 确保拖拽状态被重置
				dragging_node = false
				drag_started = false
				preview_control.visible = false
				drag_preview_rect = Rect2()
				
			elif dragging_node:
				# 如果在空白区域释放鼠标
				if drag_started and selected_node:
					# 只有真正开始拖拽时才结束拖拽
					_end_drag(selected_node)
				else:
					# 否则只是重置状态
					dragging_node = false
					drag_started = false
					preview_control.visible = false
					drag_preview_rect = Rect2()
					select_node(null)
			
			# 结束画布拖拽
			if dragging_canvas and !event.pressed:
				dragging_canvas = false
		
		# 右键检测连接线并显示删除菜单
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mouse_pos = get_global_mouse_position() - node_container.get_global_position()
			var connection_idx = _get_connection_at_position(mouse_pos)
			
			if connection_idx != -1:
				_show_connection_context_menu(connection_idx, get_global_mouse_position())
	
	elif event is InputEventMouseMotion:
		# 处理画布拖拽
		if dragging_canvas:
			var delta = get_global_mouse_position() - canvas_drag_start_pos
			canvas_drag_start_pos = get_global_mouse_position()
			_move_canvas(delta)
			
		elif dragging_node and selected_node:
			# 确认拖拽已开始 - 只有当鼠标移动超过5像素时才开始拖拽
			if not drag_started:
				var current_pos = get_global_mouse_position()
				var distance = current_pos.distance_to(drag_start_pos)
				if distance > 5: # 5像素的移动阈值
					_start_drag(selected_node) # 这里会设置预览矩形为可见
					if debug_mode:
						print("鼠标移动距离: ", distance, " 像素，开始拖拽")
			
			# 只在真正拖拽时更新预览位置
			if drag_started:
				_update_preview_position(get_global_mouse_position())
				queue_redraw() # 触发重绘

# 选中节点，将其移到渲染队列前面
func select_node(node: Control) -> void:
	# 否发生改变
	var lastSelected = selected_node
	var isSelectchanged = selected_node == node
	
	# 取消旧节点选中
	deselect_node()
		
	# 设置新的选中节点
	selected_node = node
	
	if selected_node == null: return
	
	if selected_node.has_method("set") or selected_node.has_property("selected"):
		selected_node.set("selected", true)
	
	# 调整渲染顺序
	if node_render_queue.has(node):
		node_render_queue.erase(node)
		node_render_queue.push_front(node) # 移到队列前面
	
	if debug_mode:
		print("选中节点: " + node.name)
	
	# 触发重绘
	queue_redraw()
	if connection_drawer:
		connection_drawer.queue_redraw()
		
	if isSelectchanged:
		# TODO 发生改变 lastSelected and selected_node
		return

# 取消节点选中
func deselect_node() -> void:
	if selected_node:
		if selected_node.has_method("set") or selected_node.has_property("selected"):
			selected_node.set("selected", false)
			selected_node.queue_redraw() # 确保节点重绘更新高亮状态
		selected_node = null
		
		if debug_mode:
			print("取消节点选中")
		
		# 触发重绘
		queue_redraw()
		if connection_drawer:
			connection_drawer.queue_redraw()

# 获取鼠标位置下的节点 - 改进版，但我们不再使用此函数，直接在_gui_input中处理
func _get_node_at_position(global_pos: Vector2) -> Control:
	if debug_mode:
		print("检查位置: ", global_pos)
		
	# 按照渲染队列顺序检查节点（从前到后）
	for node in node_render_queue:
		# 确保节点有效
		if not is_instance_valid(node):
			continue
			
		# 计算节点在全局坐标系中的矩形
		var node_global_pos = node.get_global_position()
		var node_rect = Rect2(node_global_pos, node.size)
		
		if debug_mode:
			print("节点: ", node.name, " 位置: ", node_global_pos, " 大小: ", node.size)
			
		if node_rect.has_point(global_pos):
			if debug_mode:
				print("找到节点: ", node.name)
			return node
	
	if debug_mode:
		print("未找到节点")
	return null

# 更新画布名称
func update_canvas_name(name: String) -> void:
	canvas_name = name
	var canvasNameLabel = $DebugContainer/CanvasNameLabel
	canvasNameLabel.text = canvas_name

# 重写绘制函数，绘制画布信息
func _draw() -> void:
	# 绘制背景网格
	var grid_size = 50 # 网格大小
	var grid_color = Color(0.8, 0.8, 0.8, 0.5) # 网格颜色，带有透明度

	# 获取当前视图的大小
	var size = get_size()

	# 计算中心位置
	var center_x = size.x / 2
	var center_y = size.y / 2

	# 绘制水平网格线
	for y in range(0, size.y, grid_size):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color)

	# 绘制垂直网格线
	for x in range(0, size.x, grid_size):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color)

		# 获取节点容器的大小
	var container_size = size
	
	# 计算中心位置
	var center_pos = Vector2(center_x, center_y)
	
	draw_circle(center_pos, 10, Color(1, 0, 0, 1))

	debug_mode = $DebugContainer/DebugToggle.button_pressed

	# 更新画布信息
	var canvasInfoLabel = $DebugContainer/CanvasInfoLabel

	if debug_mode:
		var stringInfo = "";
		stringInfo += "偏移: (" + str(int(canvas_offset.x)) + ", " + str(int(canvas_offset.y)) + ")" + " \n"
		stringInfo += "NodeContainerPos: (" + str(int(node_container.get_global_position().x)) + ", " + str(int(node_container.get_global_position().y)) + ")"
		canvasInfoLabel.text = stringInfo
	else:
		canvasInfoLabel.text = ""
	
# 修改连接线绘制器类
class ConnectionDrawer extends Control:
	var connections: Array
	var nodes: Dictionary
	var debug_mode: bool = true
	var editor_view = null # 引用到编辑器视图
	var _real_time_update: bool = false # 是否进行实时更新
	
	func _init(view = null):
		editor_view = view
	
	func _draw() -> void:
		# 绘制已存在的连接
		if connections.size() > 0:
			for connection in connections:
				if connection is Dictionary:
					var from_node_id = connection.get("from_node", "")
					var to_node_id = connection.get("to_node", "")
					
					if not nodes.has(from_node_id) or not nodes.has(to_node_id):
						continue
						
					var from_node = nodes[from_node_id]
					var to_node = nodes[to_node_id]
					
					if from_node and to_node:
						var from_slot_idx = connection.get("from_slot", 0)
						var to_slot_idx = connection.get("to_slot", 0)
						
						if from_node.outputs.size() <= from_slot_idx or to_node.inputs.size() <= to_slot_idx:
							continue
						
						# 获取槽位置
						var from_pos
						var to_pos
						
						if editor_view:
							# 使用编辑器视图获取槽位置
							from_pos = editor_view._get_slot_position(from_node, true, from_slot_idx)
							to_pos = editor_view._get_slot_position(to_node, false, to_slot_idx)
							
							# 如果正在拖拽某个节点，调整连接线位置
							if _real_time_update and editor_view.dragging_node and editor_view.drag_started:
								# 如果起始节点是被拖拽的节点，调整起始位置
								if from_node == editor_view.selected_node:
									# 使用预览矩形的位置来计算新的起始位置
									var offset = editor_view.drag_preview_rect.position - from_node.position
									from_pos += offset
								
								# 如果终点节点是被拖拽的节点，调整终点位置
								if to_node == editor_view.selected_node:
									# 使用预览矩形的位置来计算新的终点位置
									var offset = editor_view.drag_preview_rect.position - to_node.position
									to_pos += offset
						else:
							# 直接计算槽位置（不应该走这个分支，仅作为后备）
							var slot_height = 25
							var y_offset = 40
							from_pos = from_node.position + Vector2(from_node.size.x, y_offset + from_slot_idx * slot_height + slot_height / 2)
							to_pos = to_node.position + Vector2(0, y_offset + to_slot_idx * slot_height + slot_height / 2)
						
						# 绘制连接线
						_draw_bezier_connection(from_pos, to_pos, Color(0.2, 0.6, 1.0))
		
		# 绘制正在创建的连接线
		if editor_view and editor_view.creating_connection:
			var start_node = editor_view.connection_start_node
			var start_slot_idx = editor_view.connection_start_slot_idx
			var is_output = editor_view.connection_start_is_output
			
			if start_node:
				var start_pos = editor_view._get_slot_position(start_node, is_output, start_slot_idx)
				var end_pos = editor_view.connection_end_pos
				
				# 检查是否有附近的槽点
				var highlight_slot = editor_view._get_highlighted_slot()
				
				# 如果有附近槽点，则调整终点位置为槽点位置
				if !highlight_slot.is_empty():
					var target_node = highlight_slot.node
					var target_is_output = highlight_slot.is_output
					var target_slot_idx = highlight_slot.index
					
					# 获取槽点位置
					var slot_pos = editor_view._get_slot_position(target_node, target_is_output, target_slot_idx)
					
					# 绘制高亮槽点
					draw_circle(slot_pos, 8, Color(1.0, 0.8, 0.2, 0.7)) # 黄色高亮圆圈
					draw_circle(slot_pos, 6, Color(1.0, 1.0, 0.0, 0.9)) # 亮黄色内圈
					
					# 绘制临时连接线到槽点
					_draw_bezier_connection(start_pos, slot_pos, Color(1.0, 0.8, 0.2, 0.8), true)
				else:
					# 没有附近槽点，正常绘制临时连接线
					_draw_bezier_connection(start_pos, end_pos, Color(1.0, 0.8, 0.2, 0.8), true)
	
	# 绘制贝塞尔曲线连接线
	func _draw_bezier_connection(from_pos: Vector2, to_pos: Vector2, color: Color, is_preview = false) -> void:
		# 计算控制点
		var distance = from_pos.distance_to(to_pos)
		var control_point_offset = min(distance * 0.5, 200.0)
		var from_control = from_pos + Vector2(control_point_offset, 0)
		var to_control = to_pos - Vector2(control_point_offset, 0)
		
		# 生成贝塞尔曲线点
		var points = []
		var steps = 20
		for i in range(steps + 1):
			var t = float(i) / steps
			var point = NodeEditorView.cubic_bezier(from_pos, from_control, to_control, to_pos, t)
			points.append(point)
		
		# 为预览线条设置特殊效果
		if is_preview:
			# 首先绘制更宽的背景线，增强可见性
			for i in range(points.size() - 1):
				# 阴影线条
				draw_line(points[i] + Vector2(2, 2), points[i + 1] + Vector2(2, 2), Color(0, 0, 0, 0.5), 5.0)
				
			# 然后绘制虚线效果
			for i in range(points.size() - 1):
				if i % 2 == 0: # 仅绘制偶数段，创建虚线效果
					draw_line(points[i], points[i + 1], color, 3.0)
		else:
			# 常规连接线
			for i in range(points.size() - 1):
				# 阴影线条
				draw_line(points[i] + Vector2(2, 2), points[i + 1] + Vector2(2, 2), Color(0, 0, 0, 0.3), 3.0)
				# 主线条
				draw_line(points[i], points[i + 1], color, 2.0)
		
		# 绘制端点
		var endpoint_color = Color(0.2, 0.8, 0.2) if !is_preview else Color(1.0, 0.8, 0.2)
		draw_circle(from_pos, 4, endpoint_color)
		draw_circle(to_pos, 4, endpoint_color)

# 添加静态贝塞尔曲线计算函数
static func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	var q2 = p2.lerp(p3, t)
	
	var r0 = q0.lerp(q1, t)
	var r1 = q1.lerp(q2, t)
	
	return r0.lerp(r1, t)

# 处理来自节点的输入事件
func _on_node_gui_input(event: InputEvent, source_node: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if debug_mode:
					print("节点 " + source_node.name + " 被点击")
				
				# 单击只选中节点
				select_node(source_node)
				
				# 记录鼠标按下位置，为可能的拖拽做准备，但不立即开始拖拽
				drag_start_pos = get_global_mouse_position()
				dragging_node = true
				drag_started = false
				
				# 确保预览控件不可见
				preview_control.visible = false
				
			elif dragging_node and selected_node == source_node:
				# 只有在真正开始拖拽时才结束拖拽
				if drag_started:
					_end_drag(source_node)
				else:
					# 如果只是单击，那么只是重置拖拽状态
					dragging_node = false
					drag_started = false
	
	elif event is InputEventMouseMotion:
		if dragging_node and source_node == selected_node:
			# 只有当鼠标移动超过阈值时才开始真正的拖拽
			if not drag_started:
				var current_pos = get_global_mouse_position()
				var distance = current_pos.distance_to(drag_start_pos)
				if distance > 5: # 5像素的移动阈值
					_start_drag(source_node) # 开始真正的拖拽
					if debug_mode:
						print("鼠标移动距离: ", distance, " 像素，开始拖拽")
			
			# 只在真正拖拽时更新预览位置
			if drag_started:
				_update_preview_position(get_global_mouse_position())
				queue_redraw() # 触发重绘

# 开始拖拽，创建预览矩形
func _start_drag(node: Control) -> void:
	if debug_mode:
		print("开始拖动节点: " + node.name)
	
	# 标记拖拽已开始
	drag_started = true
	
	# 设置拖拽参数
	drag_offset = get_global_mouse_position() - node.get_global_position()
	drag_preview_rect = Rect2(node.position, node.size)
	
	# 使预览矩形可见
	preview_control.visible = true
	preview_control.size = node.size
	preview_control.position = node.position
	preview_control.node_ref = node # 添加对正在拖拽节点的引用
	preview_control.queue_redraw() # 确保绘制预览矩形
	
	# 通知连接线绘制器需要实时更新连接线
	if connection_drawer:
		connection_drawer._real_time_update = true
		connection_drawer.queue_redraw()
	
	if debug_mode:
		print("拖拽矩形已创建 - 位置:", drag_preview_rect.position, " 大小:", drag_preview_rect.size)

# 更新预览矩形位置
func _update_preview_position(global_mouse_pos: Vector2) -> void:
	if selected_node and drag_started:
		# 计算新位置，考虑鼠标位置和节点偏移
		var local_mouse_pos = global_mouse_pos - node_container.get_global_position()
		# 减去拖动偏移来获得节点的新位置
		var new_pos = local_mouse_pos - drag_offset
		
		# 更新预览矩形属性
		drag_preview_rect = Rect2(new_pos, selected_node.size)
		
		# 更新预览控件位置
		preview_control.position = new_pos
		preview_control.size = selected_node.size
		preview_control.queue_redraw()
		
		# 通知连接线绘制器需要重绘，虽然节点实际尚未移动
		if connection_drawer:
			connection_drawer.queue_redraw()
	else:
		if debug_mode:
			print("无法更新预览位置 - 拖拽未开始或无选中节点")

# 结束拖拽
func _end_drag(node: Control) -> void:
	if debug_mode:
		print("结束拖动节点: " + node.name)
		print("将节点移至: " + str(drag_preview_rect.position))
	
	# 移动节点到预览矩形位置
	node.position = drag_preview_rect.position
	
	# 隐藏预览矩形
	preview_control.visible = false
	
	# 重置拖拽状态
	dragging_node = false
	drag_started = false
	drag_preview_rect = Rect2()
	
	# 结束状态重新选择（保险）
	select_node(node)
	
	# 确保连接线绘制器知道节点已经移动
	if connection_drawer:
		# 强制更新连接线绘制器的节点引用
		connection_drawer.nodes = nodes
		# 关闭实时更新模式
		connection_drawer._real_time_update = false
		connection_drawer.queue_redraw()
	
	# 重绘整个视图
	queue_redraw()

# 预览矩形控件类
class PreviewRect extends Control:
	var node_ref: Control = null
	
	func _draw():
		if not visible or not node_ref:
			return
			
		var rect = Rect2(Vector2.ZERO, size)
		
		# 绘制半透明填充
		draw_rect(rect, Color(0.5, 0.5, 0.5, 0.3), true)
		
		# 绘制实线边框
		draw_rect(rect, Color(0.7, 0.7, 0.7, 0.7), false, 2.0)
		
		# 绘制虚线边框 - 增加对比度
		_draw_dashed_rect(rect, Color(1, 1, 1, 0.9), 1.5, 4)
		_draw_dashed_rect(rect.grow(-2), Color(0, 0, 0, 0.7), 1.5, 4) # 添加内部黑色虚线增加对比度
	
	# 绘制虚线矩形 - 更高效的实现
	func _draw_dashed_rect(rect: Rect2, color: Color, width: float, dash_length: int):
		# 顶部边
		_draw_dashed_line(
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			color, width, dash_length
		)
		# 右侧边
		_draw_dashed_line(
			rect.position + Vector2(rect.size.x, 0),
			rect.position + rect.size,
			color, width, dash_length
		)
		# 底部边
		_draw_dashed_line(
			rect.position + rect.size,
			rect.position + Vector2(0, rect.size.y),
			color, width, dash_length
		)
		# 左侧边
		_draw_dashed_line(
			rect.position + Vector2(0, rect.size.y),
			rect.position,
			color, width, dash_length
		)
	
	# 绘制虚线 - 优化实现，减少计算量
	func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: int):
		var length = from.distance_to(to)
		var normal = (to - from).normalized()
		var count = int(length / (dash_length * 2))
		
		for i in range(count):
			var start = from + normal * (2 * i * dash_length)
			var end = start + normal * dash_length
			draw_line(start, end, color, width)
		
		# 处理剩余部分，确保线段末尾也有虚线
		var remainder = length - (count * dash_length * 2)
		if remainder > dash_length:
			var start = from + normal * (count * dash_length * 2)
			var end = start + normal * dash_length
			draw_line(start, end, color, width)

# 删除节点按钮事件处理
func _on_delete_node_pressed() -> void:
	if debug_mode:
		print("删除节点按钮被点击")
	
	# 如果没有选中节点，显示提示框
	if selected_node == null:
		var dialog = AcceptDialog.new()
		dialog.title = "提示"
		dialog.dialog_text = "请先选择要删除的节点"
		dialog.ok_button_text = "确定"
		add_child(dialog)
		dialog.popup_centered()
		return
	
	# 获取选中节点的ID
	var node_id = selected_node.get("node_id")
	
	if debug_mode:
		print("准备删除节点: " + node_id)
	
	# 找到与该节点相关的所有连接
	var incoming_connections = [] # 指向该节点的连接
	var outgoing_connections = [] # 从该节点出发的连接
	var connections_to_remove = [] # 需要删除的连接
	
	for connection in connections:
		if connection["from_node"] == node_id:
			outgoing_connections.append(connection)
			connections_to_remove.append(connection)
		elif connection["to_node"] == node_id:
			incoming_connections.append(connection)
			connections_to_remove.append(connection)
	
	# 获取当前节点的 TestBaseNode
	var current_test_node = selected_node.get("cur_test_base_node")
	
	# 如果是中间节点（既有输入又有输出）
	if !incoming_connections.is_empty() and !outgoing_connections.is_empty():
		# 对于每个父节点
		for incoming in incoming_connections:
			var parent_node = nodes[incoming["from_node"]]
			var parent_test_node = parent_node.get("cur_test_base_node")
			var parent_slot_idx = incoming["from_slot"]
			
			# 对于每个子节点
			for outgoing in outgoing_connections:
				var child_node = nodes[outgoing["to_node"]]
				var child_test_node = child_node.get("cur_test_base_node")
				
				# 创建从父节点到子节点的新连接
				var new_connection = {
					"from_node": incoming["from_node"],
					"to_node": outgoing["to_node"],
					"from_slot": incoming["from_slot"],
					"to_slot": outgoing["to_slot"]
				}
				
				# 更新父节点的 children 数组
				if parent_test_node and parent_slot_idx < parent_test_node.children.size():
					parent_test_node.children[parent_slot_idx] = child_test_node
				
				connections.append(new_connection)
	
	# 如果是最后一个节点（只有输入，没有输出）
	elif !incoming_connections.is_empty() and outgoing_connections.is_empty():
		for incoming in incoming_connections:
			var parent_node = nodes[incoming["from_node"]]
			var parent_test_node = parent_node.get("cur_test_base_node")
			var parent_slot_idx = incoming["from_slot"]
			
			# 更新父节点的 children 数组，将对应位置设为 null
			if parent_test_node and parent_slot_idx < parent_test_node.children.size():
				parent_test_node.children.remove_at(parent_slot_idx)
	
	# 删除所有需要移除的连接
	for connection in connections_to_remove:
		connections.erase(connection)
	
	if debug_mode:
		print("已删除 " + str(connections_to_remove.size()) + " 个相关连接")
	
	# 从渲染队列中移除
	if node_render_queue.has(selected_node):
		node_render_queue.erase(selected_node)
	
	# 从节点字典中移除
	nodes.erase(node_id)
	
	# 保存对当前选中节点的引用，然后取消选中
	var node_to_delete = selected_node
	deselect_node()
	
	# 从场景树中移除并释放节点
	node_to_delete.queue_free()
	
	# 更新连接线绘制器
	if connection_drawer:
		connection_drawer.connections = connections
		connection_drawer.queue_redraw()
	
	if debug_mode:
		print("节点已删除: " + node_id)
	
	# 触发重绘
	queue_redraw()

# 处理节点槽点击事件
func _on_node_slot_pressed(node: Control, is_output: bool, slot_idx: int) -> void:
	if debug_mode:
		print("节点槽被点击: ", node.name, " ", "输出槽" if is_output else "输入槽", " 索引:", slot_idx)
	
	# 如果正在创建连接，先取消
	if creating_connection:
		_cancel_connection_creation()
	
	# 开始创建新连接
	creating_connection = true
	connection_start_node = node
	connection_start_slot_idx = slot_idx
	connection_start_is_output = is_output
	
	# 获取起始点位置
	var start_pos = _get_slot_position(node, is_output, slot_idx)
	
	# 初始化终点为当前鼠标位置
	connection_end_pos = get_global_mouse_position() - node_container.get_global_position() - canvas_offset
	
	if debug_mode:
		print("开始创建连接线 - 起点:", start_pos, "初始终点:", connection_end_pos)
	
	# 确保立即重绘
	if connection_drawer:
		connection_drawer.queue_redraw()
	
	# 更新视图状态
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN) # 可选：隐藏鼠标指针
	get_viewport().set_input_as_handled() # 标记事件已处理

# 处理全局的鼠标移动以更新连接线预览
func _input(event: InputEvent) -> void:
	# 使用_input而不是_unhandled_input以确保能捕获所有事件
	if creating_connection:
		if event is InputEventMouseMotion:
			# 更新连接终点位置 - 转换为相对于NodeContainer的位置
			connection_end_pos = get_global_mouse_position() - node_container.get_global_position()
			
			if debug_mode and Engine.get_frames_drawn() % 60 == 0:
				print("全局更新连接线终点:", connection_end_pos)
			
			# 确保连接线绘制器重绘
			if connection_drawer:
				connection_drawer.queue_redraw()
			
			# 接受事件，防止进一步处理
			get_viewport().set_input_as_handled()
		
		# 处理在空白区域点击取消连接创建或完成连接
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
				# 尝试连接到最近的槽点
				if _try_connect_to_nearest_slot():
					# 成功创建连接，结束创建状态
					_end_connection_creation()
				else:
					# 没有找到附近槽点，取消连接
					if debug_mode:
						print("未找到附近槽点，取消连接")
					_cancel_connection_creation()
				
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_cancel_connection_creation()
				get_viewport().set_input_as_handled()

# 移动画布（所有节点）
func _move_canvas(delta: Vector2) -> void:
	canvas_offset += delta
	
	# 更新所有节点的位置
	for node in nodes.values():
		node.position += delta
	
	# 如果正在创建连接线，也要更新连接线的终点位置
	if creating_connection:
		connection_end_pos += delta
	
	# 重绘连接线
	if connection_drawer:
		connection_drawer.queue_redraw()
	
	# 触发重绘整个视图
	queue_redraw()

# 处理节点槽释放事件
func _on_node_slot_released(node: Control, is_output: bool, slot_idx: int) -> void:
	if debug_mode:
		print("节点槽被释放: ", node.name, " ", "输出槽" if is_output else "输入槽", " 索引:", slot_idx)
	
	# 如果正在创建连接
	if creating_connection:
		# 检查连接的有效性 - 不同类型的槽且不是同一节点
		var valid_connection = (connection_start_is_output != is_output) and (connection_start_node != node)
		
		if valid_connection:
			# 确保始终是从输出到输入的连接
			var from_node = connection_start_node if connection_start_is_output else node
			var to_node = node if !is_output else connection_start_node
			var from_slot = connection_start_slot_idx if connection_start_is_output else slot_idx
			var to_slot = slot_idx if !is_output else connection_start_slot_idx
			
			# 创建连接并立即结束连接创建状态
			_create_connection(from_node, from_slot, to_node, to_slot)
			_end_connection_creation()
		else:
			# 无效连接，取消并显示提示
			_cancel_connection_creation()
			
			if connection_start_node == node:
				_show_message("不能连接到同一个节点")
			else:
				_show_message("只能从输出连接到输入")

# 处理鼠标释放时的连接尝试
func _try_connect_to_nearest_slot() -> bool:
	# 如果不是在创建连接，直接返回
	if not creating_connection:
		return false
	
	# 检查附近是否有合适的槽点
	var target_slot = {}
	
	# 根据起始槽类型查找合适的目标槽
	if connection_start_is_output:
		target_slot = _find_slot_near_position(connection_end_pos, true, false) # 只查找输入槽
	else:
		target_slot = _find_slot_near_position(connection_end_pos, false, true) # 只查找输出槽
	
	# 有附近的槽点且可以建立连接
	if !target_slot.is_empty():
		if debug_mode:
			print("释放鼠标时找到附近槽点: ", target_slot.node.name,
				  " ", "输出槽" if target_slot.is_output else "输入槽",
				  " 索引:", target_slot.index)
		
		# 确保连接类型正确(从输出到输入)
		var from_node = connection_start_node if connection_start_is_output else target_slot.node
		var to_node = target_slot.node if !target_slot.is_output else connection_start_node
		var from_slot = connection_start_slot_idx if connection_start_is_output else target_slot.index
		var to_slot = target_slot.index if !target_slot.is_output else connection_start_slot_idx
		
		# 创建连接
		_create_connection(from_node, from_slot, to_node, to_slot)
		return true
	
	return false

# 创建一个新的连接
func _create_connection(from_node: Control, from_slot: int, to_node: Control, to_slot: int) -> void:
	if debug_mode:
		print("创建连接: ", from_node.name, ":", from_slot, " -> ", to_node.name, ":", to_slot)
	
	# 检查是否已存在相同的连接
	for conn in connections:
		if conn.from_node == from_node.get("node_id") and conn.to_node == to_node.get("node_id") and \
		   conn.from_slot == from_slot and conn.to_slot == to_slot:
			if debug_mode:
				print("连接已存在")
			return
	
	# 创建新连接
	var connection = {
		"from_node": from_node.get("node_id"),
		"to_node": to_node.get("node_id"),
		"from_slot": from_slot,
		"to_slot": to_slot
	}
	
	# 处理父子级关系
	# 获取父节点和子节点
	var parent_node = from_node
	var child_node = to_node
	
	var parent_test_node = parent_node.get("cur_test_base_node")
	var child_test_node = child_node.get("cur_test_base_node")
	if parent_test_node == null:
		printerr("父数据没有设置")
		return
	if child_test_node == null:
		printerr("子数据没有设置")
		return
	
	# 根据输出槽索引确定在children列表中的位置
	var insert_index = from_slot
	
	# 确保children列表足够长
	while parent_test_node.children.size() <= insert_index:
		parent_test_node.children.append(null)
	
	# 在指定位置插入子节点
	parent_test_node.children[insert_index] = child_node.get("cur_test_base_node")
	
	if debug_mode:
		print("建立父子关系: ", parent_node.get("node_id"), " -> ", child_node.get("node_id"), " 位置: ", insert_index)
	
	connections.append(connection)
	
	# 更新连接线绘制器
	if connection_drawer:
		connection_drawer.queue_redraw()
	
	if debug_mode:
		print("连接创建成功")

# 取消连接创建
func _cancel_connection_creation() -> void:
	if debug_mode and creating_connection:
		print("取消创建连接")
	
	_end_connection_creation()

# 结束连接创建状态
func _end_connection_creation() -> void:
	if !creating_connection:
		return
		
	creating_connection = false
	connection_start_node = null
	connection_start_slot_idx = -1
	
	# 恢复鼠标显示
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 确保连接线绘制器重绘
	if connection_drawer:
		connection_drawer.queue_redraw()
	
	if debug_mode:
		print("结束连接线创建")

# 显示消息对话框
func _show_message(text: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "提示"
	dialog.dialog_text = text
	dialog.ok_button_text = "确定"
	add_child(dialog)
	dialog.popup_centered()

# 显示连接线的右键菜单
func _show_connection_context_menu(connection_idx: int, global_pos: Vector2) -> void:
	var popup = PopupMenu.new()
	popup.add_item("删除连接", 0)
	
	add_child(popup)
	popup.connect("id_pressed", Callable(self, "_on_connection_menu_item_selected").bind(connection_idx))
	popup.position = global_pos
	popup.popup()

# 处理连接线菜单选择
func _on_connection_menu_item_selected(id: int, connection_idx: int) -> void:
	if id == 0: # 删除连接
		_delete_connection(connection_idx)

# 删除指定索引的连接
func _delete_connection(connection_idx: int) -> void:
	if connection_idx >= 0 and connection_idx < connections.size():
		var connection = connections[connection_idx]
		
		if debug_mode:
			print("删除连接:", connection)
			
		connections.remove_at(connection_idx)
		
		# 更新连接线绘制器
		if connection_drawer:
			connection_drawer.queue_redraw()
			
		if debug_mode:
			print("连接已删除")

# 当正在创建连接时，获取当前鼠标附近的有效槽点
func _get_highlighted_slot() -> Dictionary:
	if !creating_connection:
		return {}
		
	# 如果起始是输出槽，则寻找附近的输入槽
	if connection_start_is_output:
		return _find_slot_near_position(connection_end_pos, true, false)
	# 如果起始是输入槽，则寻找附近的输出槽
	else:
		return _find_slot_near_position(connection_end_pos, false, true)

# 获取节点槽的全局位置
func _get_slot_position(node: Control, is_output: bool, slot_idx: int) -> Vector2:
	var slot_height = 25
	var y_offset = 40
	var slot_y = y_offset + slot_idx * slot_height + slot_height / 2
	
	# 注意：我们不在这里加上画布偏移量，因为节点的位置已经包含了这个偏移
	if is_output:
		# 输出槽在节点右侧
		return node.position + Vector2(node.size.x, slot_y)
	else:
		# 输入槽在节点左侧
		return node.position + Vector2(0, slot_y)

# 在指定位置查找最近的节点槽
func _find_slot_near_position(pos: Vector2, find_inputs: bool, find_outputs: bool) -> Dictionary:
	# 设置最大识别距离
	var max_distance = 30.0
	# 调整位置（pos已经是相对于NodeContainer的位置，不需要减去画布偏移）
	var adjusted_pos = pos
	
	if debug_mode:
		print("查找位置附近的槽点：", adjusted_pos, "查找输入：", find_inputs, "查找输出：", find_outputs)
	
	var closest_slot = {}
	var closest_distance = max_distance
	
	# 遍历所有节点
	for node in nodes.values():
		# 检查输入槽
		if find_inputs:
			for i in range(node.inputs.size()):
				var slot_pos = _get_slot_position(node, false, i)
				var distance = slot_pos.distance_to(adjusted_pos)
				
				if distance < closest_distance:
					closest_distance = distance
					closest_slot = {
						"node": node,
						"is_output": false,
						"index": i,
						"distance": distance
					}
		
		# 检查输出槽
		if find_outputs:
			for i in range(node.outputs.size()):
				var slot_pos = _get_slot_position(node, true, i)
				var distance = slot_pos.distance_to(adjusted_pos)
				
				if distance < closest_distance:
					closest_distance = distance
					closest_slot = {
						"node": node,
						"is_output": true,
						"index": i,
						"distance": distance
					}
	
	if debug_mode and !closest_slot.is_empty():
		print("找到最近的槽点：", closest_slot.node.name,
			  " ", "输出槽" if closest_slot.is_output else "输入槽",
			  " 索引:", closest_slot.index, " 距离:", closest_slot.distance)
	
	return closest_slot

# 获取指定位置的连接线索引
func _get_connection_at_position(pos: Vector2) -> int:
	# 这里pos已经是相对于NodeContainer的位置
	var adjusted_pos = pos
	
	if debug_mode:
		print("检查位置是否有连接线：", adjusted_pos)
	
	# 遍历所有连接
	for i in range(connections.size()):
		var connection = connections[i]
		
		# 获取连接的节点
		var from_node_id = connection.get("from_node", "")
		var to_node_id = connection.get("to_node", "")
		
		if not nodes.has(from_node_id) or not nodes.has(to_node_id):
			continue
		
		var from_node = nodes[from_node_id]
		var to_node = nodes[to_node_id]
		
		if from_node and to_node:
			var from_slot_idx = connection.get("from_slot", 0)
			var to_slot_idx = connection.get("to_slot", 0)
			
			# 获取连接线端点
			var from_pos = _get_slot_position(from_node, true, from_slot_idx)
			var to_pos = _get_slot_position(to_node, false, to_slot_idx)
			
			# 检查鼠标点击位置是否在连接线上
			if _is_point_on_connection(adjusted_pos, from_pos, to_pos, click_line_tolerance):
				if debug_mode:
					print("找到连接线：", i)
				return i
	
	return -1

# 辅助函数：判断点是否在连接线上
func _is_point_on_connection(point: Vector2, from: Vector2, to: Vector2, tolerance: float) -> bool:
	# 简单实现：判断点到线段的距离是否小于容差值
	# 计算线段向量
	var segment = to - from
	var length = segment.length()
	
	if length < 0.0001: # 防止线段长度为0导致的除零错误
		return point.distance_to(from) < tolerance
	
	# 线段向量的单位向量
	var direction = segment / length
	
	# 计算点到线段起点的向量
	var point_vector = point - from
	
	# 计算点在线段方向上的投影长度
	var projection = point_vector.dot(direction)
	
	# 如果投影在线段范围外，则计算到端点的距离
	if projection < 0:
		return point.distance_to(from) < tolerance
	elif projection > length:
		return point.distance_to(to) < tolerance
	
	# 计算点到线段的垂直距离
	var perp_dist = (point_vector - direction * projection).length()
	
	# 贝塞尔曲线连接线的更宽松的容差判断
	return perp_dist < tolerance

# 添加自动排列按钮事件处理
func _on_auto_arrange_pressed() -> void:
	if debug_mode:
		print("自动排列按钮被点击")
	
	# 执行自动排列
	_auto_arrange_nodes()

# 自动排列节点函数 - 横向布局
func _auto_arrange_nodes() -> void:
	if nodes.size() <= 1:
		return
	
	if debug_mode:
		print("开始自动排列节点")
	
	# 计算每个节点的最小高度
	var node_min_heights = {}
	for node_id in nodes:
		var node = nodes[node_id]
		node_min_heights[node_id] = node.calculate_min_height()
		# 修复每个节点的最小高度
		if node_min_heights[node_id] > node.size.y:
			node.set_node_size(Vector2(node.size.x, node_min_heights[node_id]))


	# 第一步：分析节点间的连接关系，构建有向图
	var graph = {} # 存储节点的连接关系
	var in_degree = {} # 存储每个节点的入度（指向该节点的连接数量）
	
	# 初始化图数据结构
	for node_id in nodes:
		graph[node_id] = []
		in_degree[node_id] = 0
	
	# 填充图
	for connection in connections:
		var from_node = connection.get("from_node", "")
		var to_node = connection.get("to_node", "")
		
		if graph.has(from_node) and graph.has(to_node):
			graph[from_node].append(to_node)
			in_degree[to_node] += 1
	
	# 第二步：使用拓扑排序确定节点的层级（列）
	var layers = [] # 每一层的节点
	var current_layer = [] # 当前层的节点
	
	# 找出入度为0的节点作为第一层
	for node_id in in_degree:
		if in_degree[node_id] == 0:
			current_layer.append(node_id)
	
	# 如果没有入度为0的节点，选择任意节点作为起点
	if current_layer.is_empty() and !nodes.is_empty():
		var start_node = nodes.keys()[0]
		current_layer.append(start_node)
	
	# 进行拓扑排序
	while !current_layer.is_empty():
		layers.append(current_layer.duplicate())
		var next_layer = []
		
		for node_id in current_layer:
			# 遍历当前节点的所有后继节点
			for next_node in graph[node_id]:
				in_degree[next_node] -= 1
				# 如果后继节点入度为0，添加到下一层
				if in_degree[next_node] == 0:
					next_layer.append(next_node)
		
		current_layer = next_layer
	
	# 确保所有节点都被分配到某一层
	var placed_nodes = {}
	for layer in layers:
		for node_id in layer:
			placed_nodes[node_id] = true
	
	# 找出未分配的节点
	var unplaced_nodes = []
	for node_id in nodes:
		if !placed_nodes.has(node_id):
			unplaced_nodes.append(node_id)
	
	# 将未分配的节点添加到适当的层（简单添加到最后一层）
	if !unplaced_nodes.is_empty():
		layers.append(unplaced_nodes)
	
	if debug_mode:
		print("节点分层完成，共 ", layers.size(), " 层")
		for i in range(layers.size()):
			print("第 ", i + 1, " 层节点: ", layers[i])
	
	# 第三步：计算每一层节点的位置
	var node_positions = {} # 存储每个节点的新位置
	var layer_x_positions = [] # 每层的x位置
	var horizontal_spacing = 300 # 层间水平间距
	
	# 计算每层的x位置
	var current_x = 100 # 起始x位置
	for i in range(layers.size()):
		layer_x_positions.append(current_x)
		
		# 计算此层中最宽节点的宽度
		var max_width = 0
		for node_id in layers[i]:
			if nodes.has(node_id):
				var node = nodes[node_id]
				max_width = max(max_width, node.size.x)
		
		current_x += max_width + horizontal_spacing
	
	# 第四步：优化每层内节点的垂直位置，减少交叉线
	var vertical_spacing = 100 # 节点垂直间距
	
	for i in range(layers.size()):
		var layer = layers[i]
		var layer_x = layer_x_positions[i]
		var current_y = 100 # 每层起始y位置
		
		# 简单排序：如果是第一层，直接排列；否则基于连接关系排序
		if i > 0:
			# 按上一层连接的平均位置排序节点
			var node_scores = {}
			for node_id in layer:
				node_scores[node_id] = 0
				var connected_count = 0
				
				# 查找与上一层节点的连接
				for connection in connections:
					var from_node = connection.get("from_node", "")
					var to_node = connection.get("to_node", "")
					
					# 如果当前节点是接收端
					if to_node == node_id and layers[i - 1].has(from_node):
						if node_positions.has(from_node):
							node_scores[node_id] += node_positions[from_node].y
							connected_count += 1
					# 如果当前节点是发送端
					elif from_node == node_id and layers[i - 1].has(to_node):
						if node_positions.has(to_node):
							node_scores[node_id] += node_positions[to_node].y
							connected_count += 1
				
				# 计算平均位置分数
				if connected_count > 0:
					node_scores[node_id] /= connected_count
				else:
					node_scores[node_id] = current_y # 默认位置
			
			# 根据得分排序节点
			layer.sort_custom(func(a, b): return node_scores[a] < node_scores[b])
		
		# 为当前层的每个节点分配位置
		for node_id in layer:
			if nodes.has(node_id):
				var node = nodes[node_id]
				node_positions[node_id] = Vector2(layer_x, current_y)
				current_y += node.size.y + vertical_spacing
	
	# 第五步：应用新位置到所有节点
	for node_id in node_positions:
		if nodes.has(node_id):
			var node = nodes[node_id]
			node.position = node_positions[node_id]
	
	# 重绘连接线
	if connection_drawer:
		connection_drawer.queue_redraw()
	
	if debug_mode:
		print("节点自动排列完成")
	
	# 触发重绘
	queue_redraw()
