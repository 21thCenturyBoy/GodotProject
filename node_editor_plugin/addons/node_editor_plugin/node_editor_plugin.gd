@tool
extends EditorPlugin

# 编辑器视图实例
var editor_view: Control

func _enter_tree() -> void:
	# 创建编辑器视图
	editor_view = preload("res://addons/node_editor_plugin/node_editor_view.tscn").instantiate()
	
	# 添加到编辑器左侧面板
	add_control_to_dock(DOCK_SLOT_LEFT_UL, editor_view)
	
	# 添加自定义菜单
	add_tool_menu_item("Node Editor", _show_node_editor)

func _exit_tree() -> void:
	# 移除编辑器视图
	remove_control_from_docks(editor_view)
	editor_view.queue_free()
	
	# 移除自定义菜单
	remove_tool_menu_item("Node Editor")

func _show_node_editor() -> void:
	# 显示编辑器视图
	editor_view.show()

func _has_main_screen() -> bool:
	return false

func _make_visible(visible: bool) -> void:
	if editor_view:
		editor_view.visible = visible

func _get_plugin_name() -> String:
	return "Node Editor"

func _get_plugin_icon() -> Texture2D:
	# 返回插件图标
	return null
