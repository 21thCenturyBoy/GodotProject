@tool
extends Control

class_name NodeEditorView  # 添加类名以便引用静态方法

# 调试标志
var debug_mode: bool = true  # 临时启用调试模式

# 节点容器
var node_container: Control
var nodes: Dictionary = {}
var node_render_queue: Array = []  # 节点渲染队列，决定绘制顺序
var connections: Array = []
var selected_node: Control = null
var dragging_node: bool = false
var drag_started: bool = false  # 添加一个标志，表示拖拽是否真正开始
var drag_start_pos: Vector2
var drag_offset: Vector2  # 拖拽偏移
var drag_preview_rect: Rect2  # 拖拽预览矩形
var connection_start_slot: Control = null

# 预加载节点场景和脚本
const BaseNodeScene = preload("res://addons/node_editor_plugin/nodes/base_node.tscn")
const BaseNodeScript = preload("res://addons/node_editor_plugin/nodes/base_node.gd")

# 连接线绘制器
var connection_drawer: ConnectionDrawer

# 预览矩形
var preview_control: Control

func _ready():
	if debug_mode:
		print("编辑器视图准备就绪")
	
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
		connection_drawer = ConnectionDrawer.new()
		connection_drawer.name = "ConnectionDrawer"
		connection_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		connection_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 忽略鼠标事件
		connection_drawer.connections = connections
		connection_drawer.nodes = nodes
		node_container.add_child(connection_drawer)
		
		# 创建预览控件，确保它在最顶层
		preview_control = PreviewRect.new()
		preview_control.name = "PreviewRect"
		preview_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_control.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 忽略鼠标事件
		preview_control.visible = false
		add_child(preview_control)
		
		print("NodeContainer、ConnectionDrawer和PreviewRect已设置")
	else:
		push_error("NodeContainer未找到!")
	
	# 设置该视图接收所有输入事件
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 连接按钮信号
	_connect_buttons()
	
	# 创建测试节点
	#_create_test_node()
	var relative_path = "res://addons/node_editor_plugin/test/example_test.json"
	_on_import_file_selected(relative_path)
	# 导入测试节点
	
	
	if debug_mode:
		print("界面初始化完成")

func _connect_buttons():
	# 直接连接按钮事件，不使用信号机制
	var add_btn = $ToolBar/AddNodeButton
	if add_btn:
		if add_btn.is_connected("pressed", _on_add_node_pressed):
			add_btn.disconnect("pressed", _on_add_node_pressed)
		add_btn.pressed.connect(_on_add_node_pressed)
		print("添加节点按钮已连接")
	
	var delete_btn = $ToolBar/DeleteNodeButton
	if delete_btn:
		if delete_btn.is_connected("pressed", _on_delete_node_pressed):
			delete_btn.disconnect("pressed", _on_delete_node_pressed)
		delete_btn.pressed.connect(_on_delete_node_pressed)
		print("删除节点按钮已连接")
	
	var import_btn = $ToolBar/ImportButton
	if import_btn:
		if import_btn.is_connected("pressed", _on_import_pressed):
			import_btn.disconnect("pressed", _on_import_pressed)
		import_btn.pressed.connect(_on_import_pressed)
		print("导入按钮已连接")
	
	var export_btn = $ToolBar/ExportButton
	if export_btn:
		if export_btn.is_connected("pressed", _on_export_pressed):
			export_btn.disconnect("pressed", _on_export_pressed)
		export_btn.pressed.connect(_on_export_pressed)
		print("导出按钮已连接")

func _on_add_node_pressed() -> void:
	if debug_mode:
		print("添加节点按钮被点击")
	
	# 创建基本节点
	var autoId = 0
	var node_id = "Node_0"
	for i in range(1000):
		node_id = "Node_" + str(i)
		if nodes.has(node_id) : continue
		else :
			autoId = i 
			break
	
	var node = create_base_node()	
	node.name = node_id
	node.set("node_id", node_id)
	node.set("node_name", "新节点")
	node.set("inputs", ["输入1"])
	node.set("outputs", ["输出1"])

	
	# 获取节点容器的大小而不是视口大小
	var container_size = node_container.size
	# 计算节点的默认大小
	var node_size = Vector2(200, 150)  # 假设的节点默认大小
	# 计算中心位置，考虑节点大小的偏移
	var center_pos = Vector2(
		(container_size.x - node_size.x) / 2,
		(container_size.y - node_size.y) / 2
	)
	node.position = center_pos
	
	# 添加到场景和字典
	node_container.add_child(node)
	nodes[node_id] = node
	
	# 添加到渲染队列的最前面
	node_render_queue.push_front(node)
	
	if debug_mode:
		print("节点已添加: " + node_id + " 位置: " + str(node.position))
	
	# 触发重绘
	queue_redraw()

# 创建基本节点的帮助方法
func create_base_node() -> Control:
	var node = BaseNodeScene.instantiate()
	# 确保节点接收输入事件
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node

func _on_import_pressed() -> void:
	print("导入按钮被点击")
	
	# 创建新的文件对话框，使用具体的类型
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "选择JSON文件"
	dialog.add_filter("*.json", "JSON文件")
	
	# 直接连接信号
	dialog.connect("file_selected", Callable(self, "_on_import_file_selected"))
	
	# 添加到场景树并显示
	add_child(dialog)
	dialog.popup_centered(Vector2(800, 600))
	
	print("导入文件对话框已显示")

func _on_import_file_selected(path):
	print("文件已选择: " + path)
	
	# 尝试读取文件
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("无法打开文件: " + path)
		return
		
	var json_text = file.get_as_text()
	file.close()
	print("文件内容已读取")
	
	# 解析JSON
	var json = JSON.parse_string(json_text)
	if not json:
		push_error("JSON解析失败")
		return
	
	print("JSON解析成功")
	_load_blueprint(json)

func _on_export_pressed() -> void:
	print("导出按钮被点击")
	
	# 创建新的文件对话框，使用具体的类型
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "保存为JSON文件"
	dialog.add_filter("*.json", "JSON文件")
	
	# 直接连接信号
	dialog.connect("file_selected", Callable(self, "_on_export_file_selected"))
	
	# 添加到场景树并显示
	add_child(dialog)
	dialog.popup_centered(Vector2(800, 600))
	
	print("导出文件对话框已显示")

func _on_export_file_selected(path):
	print("导出路径已选择: " + path)
	
	# 生成蓝图数据
	var json = _save_blueprint()
	
	# 保存到文件
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("无法创建文件: " + path)
		return
		
	file.store_string(JSON.stringify(json, "  "))
	file.close()
	print("蓝图已导出到: " + path)

func _load_blueprint(data: Dictionary) -> void:
	if debug_mode:
		print("开始加载蓝图数据")
	
	# 清除现有节点和连接
	for node in nodes.values():
		node.queue_free()
	nodes.clear()
	node_render_queue.clear()  # 清空渲染队列
	connections.clear()
	
	# 更新连接线绘制器的引用
	if connection_drawer:
		connection_drawer.connections = connections
		connection_drawer.nodes = nodes
	
	# 获取节点容器的大小
	var container_size = node_container.size
	# 计算中心点偏移
	var center_offset = Vector2(container_size.x / 2, container_size.y / 2)
	
	# 计算所有节点的边界框
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var nodes_data = data.get("nodes", [])
	
	for node_data in nodes_data:
		var pos = node_data.get("position", {})
		var pos_x = float(pos.get("x", 0))
		var pos_y = float(pos.get("y", 0))
		min_pos.x = min(min_pos.x, pos_x)
		min_pos.y = min(min_pos.y, pos_y)
		max_pos.x = max(max_pos.x, pos_x)
		max_pos.y = max(max_pos.y, pos_y)
	
	# 计算节点组的中心点
	var nodes_center = (min_pos + max_pos) / 2 if nodes_data.size() > 0 else Vector2.ZERO
	
	# 创建蓝图节点的父节点
	var blueprint = Control.new()
	blueprint.name = "Blueprint"
	blueprint.position = Vector2.ZERO
	node_container.add_child(blueprint)
	
	# 加载节点
	if data.has("nodes"):
		if debug_mode:
			print("发现节点数据: " + str(nodes_data.size()) + " 个节点")
		
		for node_data in nodes_data:
			var node_id = node_data.get("id", "")
			
			if debug_mode:
				print("创建节点: " + node_id)
			
			var node = create_base_node()  # 使用帮助方法
			node.name = node_id
			
			# 计算节点位置，使整体居中
			var pos = node_data.get("position", {})
			var pos_x = float(pos.get("x", 0))
			var pos_y = float(pos.get("y", 0))
			var relative_pos = Vector2(pos_x, pos_y) - nodes_center
			node.position = center_offset + relative_pos
			
			var size_data = node_data.get("size", {})
			var size_x = float(size_data.get("x", 200))
			var size_y = float(size_data.get("y", 100))
			node.custom_minimum_size = Vector2(size_x, size_y)
			
			# 设置节点属性
			node.set("node_id", node_id)
			node.set("node_name", node_data.get("name", "Unknown"))
			node.set("node_type", int(node_data.get("type", 0)))
			node.set("inputs", node_data.get("inputs", []))
			node.set("outputs", node_data.get("outputs", []))
			node.set("properties", node_data.get("properties", {}))
			
			blueprint.add_child(node)
			nodes[node_id] = node
			node_render_queue.append(node)  # 添加到渲染队列
			
			if debug_mode:
				print("节点添加完成: " + node_id + ", 位置: " + str(node.position))
	
	# 加载连接
	if data.has("connections"):
		if debug_mode:
			print("发现连接数据: " + str(data.get("connections").size()) + " 个连接")
		connections = data.get("connections", [])
		# 更新连接线绘制器的连接数据
		if connection_drawer:
			connection_drawer.connections = connections
	
	# 确保所有节点都重绘
	for node in nodes.values():
		node.queue_redraw()
	
	# 重绘连接线
	if connection_drawer:
		connection_drawer.queue_redraw()
	
	if debug_mode:
		print("蓝图加载完成，已加载 " + str(nodes.size()) + " 个节点和 " + str(connections.size()) + " 个连接")

func _save_blueprint() -> Dictionary:
	var data = {
		"nodes": [],
		"connections": connections
	}
	
	for node in nodes.values():
		if node.has_method("get_node_data"):
			data.nodes.append(node.get_node_data())
	
	return data

# 只在需要重绘的时候调用queue_redraw，不需要每帧都调用
# 移除_process函数

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 点击空白区域则取消选中节点
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
	
	elif event is InputEventMouseMotion:
		if dragging_node and selected_node:
			# 确认拖拽已开始 - 只有当鼠标移动超过5像素时才开始拖拽
			if not drag_started:
				var current_pos = get_global_mouse_position()
				var distance = current_pos.distance_to(drag_start_pos)
				if distance > 5:  # 5像素的移动阈值
					_start_drag(selected_node)  # 这里会设置预览矩形为可见
					if debug_mode:
						print("鼠标移动距离: ", distance, " 像素，开始拖拽")
				
			# 只在真正拖拽时更新预览位置
			if drag_started:
				_update_preview_position(get_global_mouse_position())
				queue_redraw()  # 触发重绘

# 选中节点，将其移到渲染队列前面
func select_node(node: Control) -> void:
	
	# 否发生改变
	var lastSelected = selected_node
	var isSelectchanged = selected_node == node
	
	# 取消旧节点选中
	deselect_node()
		
	# 设置新的选中节点
	selected_node = node
	
	if selected_node == null : return
	
	if selected_node.has_method("set") or selected_node.has_property("selected"):
		selected_node.set("selected", true)
	
	# 调整渲染顺序
	if node_render_queue.has(node):
		node_render_queue.erase(node)
		node_render_queue.push_front(node)  # 移到队列前面
	
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
			selected_node.queue_redraw()  # 确保节点重绘更新高亮状态
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

# 重写绘制函数，处理选中状态和拖拽预览
func _draw() -> void:
	# 空实现，预览矩形由PreviewRect控件绘制
	pass

# 修改_create_test_node函数，添加到渲染队列
func _create_test_node():
	if debug_mode:
		print("创建测试节点")
	
	# 创建第一个节点
	var node1 = create_base_node()
	node1.name = "TestNode1"
	node1.position = Vector2(200, 200)  # 左侧节点
	node1.set("node_id", "TestNode1")
	node1.set("node_name", "测试节点1")
	node1.set("inputs", ["输入1"])
	node1.set("outputs", ["输出1"])
	node_container.add_child(node1)
	nodes["TestNode1"] = node1
	node_render_queue.append(node1)  # 添加到渲染队列
	
	# 创建第二个节点
	var node2 = create_base_node()
	node2.name = "TestNode2"
	node2.position = Vector2(500, 200)  # 右侧节点
	node2.set("node_id", "TestNode2")
	node2.set("node_name", "测试节点2")
	node2.set("inputs", ["输入1"])
	node2.set("outputs", ["输出1"])
	node_container.add_child(node2)
	nodes["TestNode2"] = node2
	node_render_queue.append(node2)  # 添加到渲染队列
	
	# 创建测试连接
	_create_test_connection()
	
	if debug_mode:
		print("测试节点和连接已创建")

# 修改_create_test_connection函数，添加对connection_drawer的更新
func _create_test_connection():
	if nodes.size() >= 2:
		var node_ids = nodes.keys()
		var connection = {
			"from_node": node_ids[0],
			"to_node": node_ids[1],
			"from_slot": 0,
			"to_slot": 0
		}
		connections.append(connection)
		if connection_drawer:
			connection_drawer.queue_redraw()  # 通知连接线绘制器重绘
		if debug_mode:
			print("创建测试连接: ", connection)

# 修改连接线绘制器类
class ConnectionDrawer extends Control:
	var connections: Array
	var nodes: Dictionary
	var debug_mode: bool = true
	
	func _draw() -> void:
		if connections.size() == 0:
			return
			
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
					
					# 计算连接线的起点和终点（考虑节点的全局位置）
					var from_pos = from_node.position + Vector2(from_node.size.x, 40 + from_slot_idx * 25 + 25/2)
					var to_pos = to_node.position + Vector2(0, 40 + to_slot_idx * 25 + 25/2)
					
					# 计算控制点
					var distance = from_pos.distance_to(to_pos)
					var control_point_offset = min(distance * 0.5, 200.0)
					var from_control = from_pos + Vector2(control_point_offset, 0)
					var to_control = to_pos - Vector2(control_point_offset, 0)
					
					# 绘制贝塞尔曲线
					var points = []
					var steps = 20
					for i in range(steps + 1):
						var t = float(i) / steps
						var point = NodeEditorView.cubic_bezier(from_pos, from_control, to_control, to_pos, t)
						points.append(point)
					
					# 绘制曲线阴影效果
					for i in range(points.size() - 1):
						# 绘制阴影
						draw_line(points[i] + Vector2(2, 2), points[i + 1] + Vector2(2, 2), Color(0, 0, 0, 0.3), 3.0)
						# 绘制主线
						draw_line(points[i], points[i + 1], Color(0.2, 0.6, 1.0), 2.0)
					
					# 绘制端点
					var endpoint_color = Color(0.2, 0.8, 0.2)
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
				if distance > 5:  # 5像素的移动阈值
					_start_drag(source_node)  # 开始真正的拖拽
					if debug_mode:
						print("鼠标移动距离: ", distance, " 像素，开始拖拽")
			
			# 只在真正拖拽时更新预览位置
			if drag_started:
				_update_preview_position(get_global_mouse_position())
				queue_redraw()  # 触发重绘

# 开始拖拽，创建预览矩形
func _start_drag(node: Control) -> void:
	if debug_mode:
		print("开始真正的拖拽: " + node.name)
		
	drag_started = true
	
	# 设置预览控件大小和引用
	var preview_size = node.size
	preview_control.size = preview_size
	preview_control.node_ref = node
	
	# 获取全局鼠标位置并更新预览位置
	var mouse_global_pos = get_global_mouse_position()
	_update_preview_position(mouse_global_pos)
	
	# 确保预览控件可见
	preview_control.visible = true
	
	if debug_mode:
		print("开始拖动节点预览: " + node.name)
		print("节点位置: " + str(node.position))

# 更新预览矩形位置
func _update_preview_position(global_mouse_pos: Vector2) -> void:
	if not drag_started or not selected_node:
		return
		
	# 计算鼠标在节点容器中的位置
	var container_global_pos = node_container.get_global_position()
	var mouse_in_container = global_mouse_pos - container_global_pos
	
	# 计算预览矩形的位置，使其中心点在鼠标位置
	var rect_size = selected_node.size
	var new_pos = mouse_in_container - rect_size / 2
	
	# 限制在容器范围内
	var container_rect = node_container.get_rect()
	new_pos.x = clamp(new_pos.x, 0, container_rect.size.x - rect_size.x)
	new_pos.y = clamp(new_pos.y, 0, container_rect.size.y - rect_size.y)
	
	# 保存预览矩形位置用于后续处理
	drag_preview_rect = Rect2(new_pos, rect_size)
	
	# 更新预览控件位置和大小
	preview_control.size = rect_size  # 确保大小也被更新
	preview_control.position = get_global_transform().inverse() * (container_global_pos + new_pos)
	preview_control.queue_redraw()  # 强制重绘预览矩形
	
	if debug_mode:
		print("拖拽预览矩形位置: " + str(new_pos))

# 结束拖拽，移动节点到最终位置
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
	
	# 更新连接线
	if connection_drawer:
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
		_draw_dashed_rect(rect.grow(-2), Color(0, 0, 0, 0.7), 1.5, 4)  # 添加内部黑色虚线增加对比度
	
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
	
	# 找到并删除与该节点相关的所有连接
	var connections_to_remove = []
	for connection in connections:
		if connection["from_node"] == node_id or connection["to_node"] == node_id:
			connections_to_remove.append(connection)
	
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
