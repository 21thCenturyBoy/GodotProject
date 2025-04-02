@tool
extends Control

# 节点类型枚举
enum NodeType {
	INPUT,
	OUTPUT,
	PROCESS,
	CONDITION,
	CUSTOM
}

# 节点属性
var node_id: String = ""
var node_type: int = NodeType.PROCESS  # 改为int类型以便兼容JSON
var node_name: String = "未命名"
var node_pos: Vector2 = Vector2.ZERO  # 改名为node_pos
var node_size: Vector2 = Vector2(200, 100)  # 改名为node_size
var inputs: Array = []  # 移除严格类型以兼容JSON导入
var outputs: Array = [] # 移除严格类型以兼容JSON导入
var properties: Dictionary = {}
var selected: bool = false  # 添加选中状态属性

# 调试标志
var debug_mode: bool = false

# 信号
signal connection_started(from_slot: Control, to_slot: Control)
signal connection_ended(from_slot: Control, to_slot: Control)
signal property_changed(property_name: String, value: Variant)

# 颜色定义
var bg_colors = [
	Color(0.2, 0.4, 0.6),  # INPUT
	Color(0.6, 0.4, 0.2),  # OUTPUT
	Color(0.3, 0.3, 0.5),  # PROCESS
	Color(0.5, 0.3, 0.3),  # CONDITION
	Color(0.3, 0.5, 0.3)   # CUSTOM
]

# 初始化函数
func _init():
	if debug_mode:
		print("节点初始化")
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(200, 100)
	# 注意：不要在这里设置size，它会由Control自动处理

# 重写_ready方法
func _ready():
	if debug_mode:
		print("节点准备就绪: " + str(node_id))
	set_process(true)
	
	# 设置自己为可聚焦和接收鼠标事件
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 确保节点可见并有正确的大小
	# 不使用minimum_size_changed，因为它是一个信号
	custom_minimum_size = node_size
	
	# 向父控件指示需要重绘
	queue_redraw()

# 设置节点属性的方法，用于动态设置属性
func _set(property: StringName, value) -> bool:
	if debug_mode:
		print("设置属性: " + str(property) + " = " + str(value))
	match property:
		"node_id":
			node_id = value
			return true
		"node_name":
			node_name = value
			queue_redraw()
			return true
		"node_type":
			node_type = value
			queue_redraw()
			return true
		"node_pos":
			node_pos = value
			position = value  # 同步到Control的position
			return true
		"node_size":
			node_size = value
			custom_minimum_size = value  # 同步到Control的custom_minimum_size
			return true
		"inputs":
			inputs = value
			queue_redraw()
			return true
		"outputs":
			outputs = value
			queue_redraw()
			return true
		"properties":
			properties = value
			return true
		"selected":
			selected = value
			queue_redraw()  # 重绘以显示选中状态
			return true
	return false

# 获取节点属性的方法，用于动态获取属性
func _get(property: StringName):
	match property:
		"node_id":
			return node_id
		"node_name":
			return node_name
		"node_type":
			return node_type
		"node_pos":
			return position  # 返回Control的position
		"node_size":
			return custom_minimum_size  # 返回Control的custom_minimum_size
		"inputs":
			return inputs
		"outputs":
			return outputs
		"properties":
			return properties
		"selected":
			return selected
	return null

# 获取属性列表，用于编辑器和脚本交互
func _get_property_list() -> Array:
	var props = [
		{
			"name": "node_id",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "node_name",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "node_type",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "node_pos",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "node_size",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "inputs",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "outputs",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "properties",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			"name": "selected",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE
		}
	]
	return props

# 添加输入槽
func add_input_slot(name: String, type: int) -> void:
	inputs.append({
		"name": name,
		"type": type,
		"connections": []
	})
	queue_redraw()

# 添加输出槽
func add_output_slot(name: String, type: int) -> void:
	outputs.append({
		"name": name,
		"type": type,
		"connections": []
	})
	queue_redraw()

# 添加属性
func add_property(name: String, value: Variant, type: int) -> void:
	properties[name] = {
		"value": value,
		"type": type
	}

# 获取节点数据
func get_node_data() -> Dictionary:
	return {
		"id": node_id,
		"type": node_type,
		"name": node_name,
		"position": {"x": position.x, "y": position.y},
		"size": {"x": custom_minimum_size.x, "y": custom_minimum_size.y},
		"inputs": inputs,
		"outputs": outputs,
		"properties": properties
	}

# 跟踪尺寸变化
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if debug_mode:
			print("节点大小变化: " + str(size))
		queue_redraw()

# 绘制节点
func _draw() -> void:
	if debug_mode:
		print("绘制节点: " + node_name + ", ID: " + node_id)
	
	# 选择背景颜色
	var bg_color = bg_colors[node_type] if node_type < bg_colors.size() else Color(0.3, 0.3, 0.3)
	
	# 绘制带边框的矩形背景
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, bg_color, true)
	
	# 绘制选中状态的高亮边框
	if selected:
		# 使用亮色边框显示选中状态
		draw_rect(rect, Color(1, 0.8, 0.2, 0.8), false, 3.0)  # 黄色高亮边框
		# 添加辉光效果
		var glow_rect = Rect2(Vector2(-3, -3), size + Vector2(6, 6))
		draw_rect(glow_rect, Color(1, 0.8, 0.2, 0.3), false, 2.0)
	else:
		# 普通边框
		draw_rect(rect, Color.WHITE, false, 2.0)
	
	# 绘制标题栏
	var title_rect = Rect2(Vector2.ZERO, Vector2(size.x, 30))
	draw_rect(title_rect, bg_color.darkened(0.2), true)
	draw_rect(title_rect, Color.WHITE, false, 1.0)
	
	# 绘制节点标题
	draw_string(ThemeDB.fallback_font, Vector2(10, 20), node_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	
	# 绘制输入输出槽
	_draw_slots()
	
	if debug_mode:
		print("节点绘制完成")

# 绘制输入和输出槽
func _draw_slots() -> void:
	var slot_height = 25
	var y_offset = 40
	
	# 绘制输入槽
	if debug_mode:
		print("绘制输入槽: " + str(inputs.size()))
	for i in range(inputs.size()):
		var input = inputs[i]
		var slot_y = y_offset + i * slot_height
		var slot_pos = Vector2(0, slot_y)
		
		# 绘制输入槽背景
		var slot_rect = Rect2(slot_pos, Vector2(10, slot_height))
		draw_rect(slot_rect, Color(0.1, 0.5, 0.1), true)
		
		# 绘制输入槽连接点
		draw_circle(Vector2(5, slot_y + slot_height/2), 5, Color(0, 1, 0))
		
		# 绘制输入槽名称
		if input is Dictionary and input.has("name"):
			draw_string(ThemeDB.fallback_font, Vector2(15, slot_y + 16), input.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	# 绘制输出槽
	if debug_mode:
		print("绘制输出槽: " + str(outputs.size()))
	for i in range(outputs.size()):
		var output = outputs[i]
		var slot_y = y_offset + i * slot_height
		var slot_pos = Vector2(size.x - 10, slot_y)
		
		# 绘制输出槽背景
		var slot_rect = Rect2(Vector2(size.x - 10, slot_y), Vector2(10, slot_height))
		draw_rect(slot_rect, Color(0.5, 0.1, 0.1), true)
		
		# 绘制输出槽连接点
		draw_circle(Vector2(size.x - 5, slot_y + slot_height/2), 5, Color(1, 0, 0))
		
		# 绘制输出槽名称
		if output is Dictionary and output.has("name"):
			var text_size = ThemeDB.fallback_font.get_string_size(output.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(ThemeDB.fallback_font, Vector2(size.x - 15 - text_size.x, slot_y + 16), output.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE) 

# 添加输入处理函数，将事件转发给父节点
func _gui_input(event: InputEvent) -> void:
	if debug_mode:
		print(name + ": 接收到输入事件 " + str(event))
		
	# 转发事件给父节点（NodeEditorView）
	var parent = get_parent()
	while parent and not parent is NodeEditorView:
		parent = parent.get_parent()
	
	if parent and parent is NodeEditorView:
		# 确保父节点知道事件是来自哪个节点
		event.set_meta("source_node", self)
		parent._on_node_gui_input(event, self)
	
	# 处理节点特定的交互（如果需要）
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 节点被点击了
				if debug_mode:
					print(name + ": 节点被点击")
	
	# 接受事件，防止它继续传播
	accept_event() 
