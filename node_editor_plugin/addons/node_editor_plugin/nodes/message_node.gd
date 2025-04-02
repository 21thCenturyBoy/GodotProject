@tool
extends "res://addons/node_editor_plugin/nodes/base_node.gd"

# 消息编辑器控件
var text_edit: TextEdit = null
var editor_initialized: bool = false
var editor_margin: Vector2 = Vector2(10, 10) # 编辑器边距

# 初始化函数
func _init():
	super._init()
	debug_mode = false
	node_type = NodeType.CUSTOM

# 重写_ready方法
func _ready():
	super._ready()
	# 初始化编辑器控件
	_initialize_text_editor()

# 初始化文本编辑器控件
func _initialize_text_editor():
	if editor_initialized:
		return
		
	# 创建TextEdit控件
	text_edit = TextEdit.new()
	text_edit.name = "MessageEditor"
	
	# 设置控件属性
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	
	# 设置样式
	text_edit.add_theme_color_override("background_color", Color(0.13, 0.13, 0.13, 0.8))
	text_edit.add_theme_color_override("font_color", Color.WHITE)
	
	# 读取初始文本
	var initial_text = ""
	if properties.has("message") and properties["message"].has("value"):
		initial_text = properties["message"]["value"]
	else:
		# 使用默认文本
		initial_text = "在此输入文本消息..."
		# 确保属性存在
		if not properties.has("message"):
			properties["message"] = {
				"type": "string",
				"value": initial_text
			}
		elif not properties["message"].has("value"):
			properties["message"]["value"] = initial_text
	
	text_edit.text = initial_text
	
	# 连接文本变更信号
	text_edit.text_changed.connect(_on_text_changed)
	
	# 添加到节点
	add_child(text_edit)
	
	# 调整位置和大小
	_update_editor_transform()
	
	editor_initialized = true

# 更新编辑器位置和大小
func _update_editor_transform():
	if not text_edit:
		return
		
	var slot_height = 25
	var title_height = 30
	var y_offset = title_height + inputs.size() * slot_height
	
	# 计算可用空间
	var available_width = size.x - editor_margin.x * 2
	var available_height = size.y - y_offset - editor_margin.y - resize_handle_height
	
	# 设置位置和大小
	text_edit.position = Vector2(editor_margin.x, y_offset)
	text_edit.size = Vector2(available_width, available_height)

# 文本变更时更新属性
func _on_text_changed():
	if text_edit:
		var new_text = text_edit.text
		# 更新属性
		if properties.has("message"):
			properties["message"]["value"] = new_text
		else:
			properties["message"] = {
				"type": "string",
				"value": new_text
			}
		# 发射属性变更信号
		emit_signal("property_changed", "message", new_text)

# 重写_draw方法
func _draw():
	super._draw()  # 调用父类的绘制方法
	
	# 初始化编辑器控件
	if not editor_initialized:
		_initialize_text_editor()
	elif text_edit:
		# 确保TextEdit控件的位置和大小正确
		_update_editor_transform()

# 在尺寸变化时重新调整编辑器大小
func _notification(what):
	super._notification(what)
	if what == NOTIFICATION_RESIZED:
		if text_edit:
			_update_editor_transform()

# 重写获取节点数据方法，确保保存消息文本
func get_node_data() -> Dictionary:
	var data = super.get_node_data()
	
	# 确保消息属性被保存
	if text_edit and properties.has("message"):
		properties["message"]["value"] = text_edit.text
	
	return data 