@tool
extends EditorPlugin

var editor_view_res = preload("res://addons/node_editor_plugin/node_editor_view.tscn")
# 编辑器视图实例
var editor_view: Control

var init_flag = false
func _enter_tree() -> void:
	if init_flag:
		return
	init_flag = true
	_show_node_editor()
		# 添加自定义菜单
	add_tool_menu_item("Node Editor", _show_node_editor)


func _exit_tree() -> void:
	# 移除编辑器视图
	_hide_node_editor()
	
	# 移除自定义菜单
	remove_tool_menu_item("Node Editor")
	init_flag = false

func _on_editor_view_destroyed() -> void:
	print("节点编辑器视图已销毁")
	editor_view = null

func _show_node_editor() -> void:
	if editor_view == null:
		editor_view = editor_view_res.instantiate()
		editor_view.connect("editor_view_destroyed", _on_editor_view_destroyed)
		# 添加到编辑器左侧面板	
		add_control_to_dock(DOCK_SLOT_LEFT_UL, editor_view)

func _hide_node_editor() -> void:
	if editor_view:
		remove_control_from_docks(editor_view)
		editor_view = null


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
