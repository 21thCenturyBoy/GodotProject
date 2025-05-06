@tool
extends EditorPlugin

# ==================================================================
# 文件变更监控插件 (FileChanged)
# 
# 这是一个Godot 4.4插件，用于监控文件变更。
# 它通过调用外部工具file_diff.exe并管理进程的执行来实现文件监控。
# 
# 插件功能:
# - 创建一个Dock面板用于命令输入和显示
# - 支持同步和异步两种方式执行命令
# - 提供进程管理列表，可查看和关闭运行中的进程
# - 实时显示进程输出和状态
# ==================================================================

# ------------------------ 成员变量 ------------------------
var dock_scene: Control              # 插件Dock面板
var process_running: bool = false    # 同步进程运行标志
var async_process_pid: int = -1      # 当前异步进程ID
var process_thread: Thread           # 同步进程线程
var pipe_thread: Thread              # 异步进程监控线程
var pipe_running: bool = false       # 异步进程监控标志
var output_rich_text: RichTextLabel  # 输出显示控件
var process_list_container: VBoxContainer  # 进程列表容器
var running_processes = {}           # 存储运行中的进程信息 {pid: {name, start_time, container}}
var panel_visible: bool = true       # 面板可见性状态

# ------------------------ 生命周期函数 ------------------------

# 插件初始化
func _enter_tree() -> void:
	# 创建并显示Dock面板
	dock_scene = create_dock_panel()
	if dock_scene:
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_scene)

# 插件清理
func _exit_tree() -> void:
	# 停止所有线程
	if process_running:
		process_running = false
	
	if pipe_running:
		pipe_running = false
	
	if process_thread and process_thread.is_started():
		process_thread.wait_to_finish()
	
	if pipe_thread and pipe_thread.is_started():
		pipe_thread.wait_to_finish()
	
	# 关闭所有运行中的进程
	_stop_all_processes()
	
	# 移除UI
	if dock_scene:
		remove_control_from_docks(dock_scene)
		dock_scene.queue_free()  # 使用queue_free代替直接free

# 处理通知事件
func _notification(what: int) -> void:
	# 监控插件自身的通知
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:  # 编辑器关闭请求
			print("FileChanged: 编辑器关闭，正在清理所有进程...")
			_stop_all_processes()
		
		NOTIFICATION_PREDELETE:  # 对象被删除前
			print("FileChanged: 插件被删除，正在清理所有进程...")
			_stop_all_processes()

# 关闭并清理所有进程
func _stop_all_processes() -> void:
	# 停止当前进程
	_stop_current_process()
	
	# 关闭所有异步进程
	for pid in running_processes.keys():
		print("FileChanged: 正在终止进程 PID: ", pid)
		OS.kill(pid)
	running_processes.clear()
	
	# 清空进程列表UI
	if process_list_container:  # 检查容器是否有效
		for child in process_list_container.get_children():
			if is_instance_valid(child):  # 检查子节点是否有效
				child.queue_free()
	
	if output_rich_text:
		output_rich_text.append_text("[color=blue]已清理所有正在运行的进程[/color]\n")

# ------------------------ UI创建函数 ------------------------

# 创建插件主界面
func create_dock_panel() -> Control:
	var panel = Control.new()
	panel.name = "FileChanged"
	panel.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	
	# 添加可见性变化监控
	panel.visibility_changed.connect(_on_panel_visibility_changed)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)
	
	# 标题
	var title_label = Label.new()
	title_label.text = "文件变更监控"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# 命令输入区域
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	var input_field = LineEdit.new()
	input_field.name = "InputField"
	input_field.placeholder_text = "输入file_diff.exe的命令参数"
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(input_field)
	
	var send_button = Button.new()
	send_button.text = "发送"
	send_button.pressed.connect(_on_send_button_pressed.bind(input_field,false))
	hbox.add_child(send_button)

	var send_button_2 = Button.new()
	send_button_2.text = "异步管道"
	send_button_2.pressed.connect(_on_send_button_pressed.bind(input_field,true))
	hbox.add_child(send_button_2)
	
	# 进程管理按钮
	var process_management_hbox = HBoxContainer.new()
	vbox.add_child(process_management_hbox)
	
	var clear_all_button = Button.new()
	clear_all_button.text = "终止所有进程"
	clear_all_button.pressed.connect(_on_clear_all_processes_pressed)
	process_management_hbox.add_child(clear_all_button)
	
	# 进程列表区域
	var process_list_title = Label.new()
	process_list_title.text = "运行中的进程"
	process_list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(process_list_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 100)  # 设置最小高度
	vbox.add_child(scroll)
	
	process_list_container = VBoxContainer.new()
	process_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(process_list_container)
	
	# 输出显示区域
	var output_label = Label.new()
	output_label.text = "输出"
	output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(output_label)
	
	output_rich_text = RichTextLabel.new()
	output_rich_text.name = "OutputText"
	output_rich_text.bbcode_enabled = true
	output_rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_rich_text.scroll_following = true
	vbox.add_child(output_rich_text)
	
	return panel

# ------------------------ 事件响应函数 ------------------------

# 面板可见性变化事件
func _on_panel_visibility_changed() -> void:
	if dock_scene and not dock_scene.visible and panel_visible:
		panel_visible = false
		print("FileChanged: Dock面板被关闭，正在清理所有进程...")
		_stop_all_processes()
	elif dock_scene and dock_scene.visible and not panel_visible:
		panel_visible = true
		print("FileChanged: Dock面板已重新显示")

# 发送按钮点击事件处理
# @param input_field: 输入框控件
# @param is_async: 是否使用异步模式
func _on_send_button_pressed(input_field: LineEdit, is_async: bool) -> void:
	if not input_field or not output_rich_text:  # 检查控件是否有效
		return
		
	var command = input_field.text.strip_edges()
	if command.is_empty():
		return
	
	output_rich_text.append_text("[b]> " + command + "[/b]\n")
	
	# 停止之前的进程 (但不停止所有进程)
	_stop_current_process()
	
	# 启动新进程
	start_process(command, is_async)
	
	# 清空输入框
	input_field.clear()

# 关闭所有进程按钮事件
func _on_clear_all_processes_pressed() -> void:
	if output_rich_text:
		output_rich_text.append_text("[b]正在终止所有进程...[/b]\n")
	_stop_all_processes()

# 关闭进程按钮点击事件
# @param pid: 要终止的进程ID
func _on_kill_process_pressed(pid: int) -> void:
	_kill_specific_process(pid)

# ------------------------ 进程管理函数 ------------------------

# 停止当前正在运行的进程，但不关闭列表中的其他进程
func _stop_current_process() -> void:
	# 停止同步进程
	if process_running:
		process_running = false
	
	if process_thread and process_thread.is_started():
		process_thread.wait_to_finish()
	
	# 停止当前异步管道进程
	if pipe_running:
		pipe_running = false
	
	if pipe_thread and pipe_thread.is_started():
		pipe_thread.wait_to_finish()

# 停止所有运行中的进程和线程
func _stop_running_processes() -> void:
	_stop_current_process()
	
	# 关闭所有异步进程
	for pid in running_processes.keys():
		OS.kill(pid)
	running_processes.clear()
	
	# 清空进程列表UI
	if process_list_container:  # 检查容器是否有效
		for child in process_list_container.get_children():
			if is_instance_valid(child):  # 检查子节点是否有效
				child.queue_free()

# 终止特定进程
# @param pid: 进程ID
func _kill_specific_process(pid: int) -> void:
	if not output_rich_text:  # 检查控件是否有效
		return
		
	if running_processes.has(pid):
		# 获取进程信息
		var process_info = running_processes[pid]
		var container = process_info.container
		
		# 杀死进程
		OS.kill(pid)
		
		# 从进程列表中移除
		running_processes.erase(pid)
		
		# 移除UI元素
		if is_instance_valid(container):
			container.queue_free()
		
		output_rich_text.append_text("[color=red]已终止进程 PID: " + str(pid) + "[/color]\n")
	else:
		output_rich_text.append_text("[color=red]找不到进程 PID: " + str(pid) + "[/color]\n")

# 添加进程到管理列表
# @param pid: 进程ID
# @param command: 执行的命令
func _add_process_to_list(pid: int, command: String) -> void:
	if not process_list_container:  # 检查容器是否有效
		return
		
	# 创建进程项UI
	var process_item = HBoxContainer.new()
	process_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 进程信息标签
	var process_label = Label.new()
	var current_time = Time.get_datetime_dict_from_system()
	var time_string = "%02d:%02d:%02d" % [current_time.hour, current_time.minute, current_time.second]
	process_label.text = "PID: " + str(pid) + " | " + command + " | 开始于: " + time_string
	process_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	process_item.add_child(process_label)
	
	# 关闭按钮
	var kill_button = Button.new()
	kill_button.text = "终止"
	kill_button.pressed.connect(_on_kill_process_pressed.bind(pid))
	process_item.add_child(kill_button)
	
	# 添加到容器
	process_list_container.add_child(process_item)
	
	# 存储进程信息
	running_processes[pid] = {
		"name": command,
		"start_time": time_string,
		"container": process_item
	}

# ------------------------ 进程执行函数 ------------------------

# 启动进程执行命令
# @param command: 命令字符串
# @param is_async: 是否使用异步模式
func start_process(command: String, is_async: bool) -> void:
	if not output_rich_text:  # 检查控件是否有效
		return
		
	# 获取可执行文件的路径 - 使用绝对路径
	var tool_path = _get_tool_absolute_path()
	
	# 检查文件是否存在
	var file = FileAccess.open(tool_path, FileAccess.READ)
	if file == null:
		var error_code = FileAccess.get_open_error()
		output_rich_text.append_text("[color=red]错误: 无法找到或访问file_diff.exe文件 (错误代码: " + str(error_code) + ")\n")
		output_rich_text.append_text("路径: " + tool_path + "[/color]\n")
		return
	file.close()
	
	# 显示执行信息
	output_rich_text.append_text("[color=blue]执行路径: " + tool_path + "[/color]\n")
	
	# 拆分命令参数
	var args = command.split(" ", false)
	
	# 显示正在执行的完整命令
	var full_command = tool_path + " " + " ".join(args)
	output_rich_text.append_text("[color=blue]完整命令: " + full_command + "[/color]\n")
	
	# 根据模式启动进程
	if is_async:
		# --- 异步模式 ---
		output_rich_text.append_text("[color=green]使用异步模式启动进程...[/color]\n")
		
		# 确保之前的线程已经结束
		if pipe_thread and pipe_thread.is_started():
			pipe_running = false
			pipe_thread.wait_to_finish()
		
		# 使用OS.create_process启动进程但不等待完成
		async_process_pid = OS.create_process(tool_path, args, false)
		
		if async_process_pid <= 0:
			output_rich_text.append_text("[color=red]错误: 无法创建异步进程[/color]\n")
			return
		
		output_rich_text.append_text("[color=green]异步进程已启动，PID: " + str(async_process_pid) + "[/color]\n")
		
		# 添加到进程列表
		_add_process_to_list(async_process_pid, full_command)
		
		# 启动监控线程
		pipe_thread = Thread.new()
		pipe_running = true
		pipe_thread.start(Callable(self, "_monitor_async_process"))
	else:
		# --- 同步模式 ---
		output_rich_text.append_text("[color=green]使用同步模式启动进程...[/color]\n")
		process_thread = Thread.new()
		process_running = true
		process_thread.start(Callable(self, "_execute_command").bind(tool_path, args))
	
	output_rich_text.append_text("[color=green]进程正在启动...[/color]\n")

# 监控异步进程状态 (在单独线程中执行)
func _monitor_async_process() -> void:
	if async_process_pid <= 0:
		call_deferred("_update_output_text", "[color=red]错误: 无效的进程ID[/color]\n")
		pipe_running = false
		return
	
	call_deferred("_update_output_text", "[color=blue]开始监控进程状态...[/color]\n")
	
	# 每秒检查进程是否仍在运行
	var pid_to_monitor = async_process_pid  # 保存当前进程ID的副本
	var check_count = 0
	
	while pipe_running and OS.is_process_running(pid_to_monitor):
		OS.delay_msec(1000)  # 每秒检查一次
		check_count += 1
		
		# 每10秒报告一次进程仍在运行
		if check_count % 10 == 0:
			call_deferred("_update_output_text", "[color=gray]进程 PID: " + str(pid_to_monitor) + " 仍在运行，已运行 " + str(check_count) + " 秒...[/color]\n")
			
			# 更新进程列表UI中的运行时间
			call_deferred("_update_process_runtime", pid_to_monitor, check_count)
	
	# 只有当进程自然结束，而不是被终止时，才更新UI
	if not OS.is_process_running(pid_to_monitor) and running_processes.has(pid_to_monitor):
		call_deferred("_process_finished", pid_to_monitor)
	
	call_deferred("_update_output_text", "\n[color=blue]进程监控已完成 PID: " + str(pid_to_monitor) + "[/color]\n")
	pipe_running = false

# 同步执行命令 (在单独线程中执行)
# @param tool_path: 工具路径
# @param args: 命令参数数组
func _execute_command(tool_path: String, args: Array) -> void:
	# 执行命令并获取输出
	var output = []
	var exit_code = -1
	
	# 执行外部进程
	# OS.execute参数：可执行文件路径, 参数数组, 输出数组, 是否读取stderr, 是否显示控制台窗口
	var read_stderr = true
	var show_console = false  # 设置为false隐藏命令行窗口
	
	var err = OS.execute(tool_path, args, output, read_stderr, show_console)
	
	if err != OK:
		var error_message = _get_error_description(err)
		call_deferred("_update_output_text", "[color=red]执行进程失败: " + error_message + " (错误代码: " + str(err) + ")[/color]\n")
		process_running = false
		return
	
	# 处理输出
	if output.size() > 0:
		# 逐行处理输出
		for line in output:
			if !process_running:
				break
			call_deferred("_update_output_text", line + "\n")
			OS.delay_msec(20)  # 短暂延迟以更新UI
	else:
		call_deferred("_update_output_text", "[color=yellow]程序没有输出任何内容[/color]\n")
	
	call_deferred("_process_completed", exit_code)
	process_running = false

# ------------------------ 辅助函数 ------------------------

# 更新进程的运行时间信息
# @param pid: 进程ID
# @param seconds: 已运行秒数
func _update_process_runtime(pid: int, seconds: int) -> void:
	if not running_processes.has(pid):
		return
		
	var process_info = running_processes[pid]
	var container = process_info.container
	
	if not is_instance_valid(container) or container.get_child_count() <= 0:
		return
		
	var label = container.get_child(0)
	if label is Label:
		var minutes = seconds / 60
		var hours = minutes / 60
		var runtime_text = ""
		
		if hours > 0:
			runtime_text = "%dh %dm %ds" % [hours, minutes % 60, seconds % 60]
		elif minutes > 0:
			runtime_text = "%dm %ds" % [minutes, seconds % 60]
		else:
			runtime_text = "%ds" % seconds
			
		label.text = "PID: " + str(pid) + " | " + process_info.name + " | 运行: " + runtime_text

# 进程自然结束时的处理
# @param pid: 结束的进程ID
func _process_finished(pid: int) -> void:
	if not running_processes.has(pid):
		return
		
	var process_info = running_processes[pid]
	var container = process_info.container
	
	# 从UI中移除
	if is_instance_valid(container):
		container.queue_free()
	
	# 从列表中移除
	running_processes.erase(pid)
	
	_update_output_text("[color=green]进程已自行结束 PID: " + str(pid) + "[/color]\n")

# 获取工具的绝对路径
# @return: 转换后的系统绝对路径
func _get_tool_absolute_path() -> String:
	if not output_rich_text:  # 检查控件是否有效
		return ""
		
	# 使用ProjectSettings将res://路径转换为系统路径
	var rel_path = "res://addons/filechanged/tools/file_diff.exe"
	var abs_path = ProjectSettings.globalize_path(rel_path)
	
	# 修复Windows路径的反斜杠问题
	if OS.get_name() == "Windows":
		# 确保路径中使用正确的反斜杠格式
		abs_path = abs_path.replace("\\", "/")
	
	output_rich_text.append_text("[color=gray]原始路径: " + rel_path + "\n")
	output_rich_text.append_text("转换路径: " + abs_path + "[/color]\n")
	
	return abs_path

# 更新输出文本
# @param text: 要添加的文本
func _update_output_text(text: String) -> void:
	if output_rich_text:  # 检查控件是否有效
		output_rich_text.append_text(text)

# 进程完成处理
# @param exit_code: 退出代码
func _process_completed(exit_code: int) -> void:
	if output_rich_text:  # 检查控件是否有效
		output_rich_text.append_text("\n[color=blue]进程已完成，退出代码: " + str(exit_code) + "[/color]\n")

# 获取错误描述文本
# @param error_code: 错误代码
# @return: 错误描述文本
func _get_error_description(error_code: int) -> String:
	match error_code:
		ERR_CANT_OPEN: return "无法打开文件"
		ERR_CANT_CREATE: return "无法创建文件或进程"
		ERR_FILE_NOT_FOUND: return "文件未找到"
		ERR_FILE_NO_PERMISSION: return "没有权限执行"
		ERR_FILE_ALREADY_IN_USE: return "文件正被其他程序使用"
		ERR_INVALID_PARAMETER: return "无效的参数"
		_: return "未知错误"
