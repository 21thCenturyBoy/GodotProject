# Plugin Launcher

这是一个Godot编辑器插件，提供了一个停靠面板（Dock），可以通过按钮启动其他插件，并与它们交互。

## 功能特性

- 在编辑器右上角创建一个停靠面板
- 提供按钮启动Node Editor插件
- 支持向Node Editor插件传递JSON格式的自定义数据
- 支持接收Node Editor插件导出的自定义数据
- 可以从文件中加载JSON数据

## 安装方法

1. 将`plugin_launcher`文件夹复制到你的Godot项目的`addons`目录中
2. 在Godot编辑器中，转到`项目 > 项目设置 > 插件`
3. 找到"Plugin Launcher"插件并启用它

## 使用方法

### 基本功能

1. 启用插件后，在编辑器右上角会出现一个名为"Plugin Launcher"的面板
2. 点击"Launch Node Editor"按钮来启动Node Editor插件

### 传递JSON数据

1. 在文本框中输入有效的JSON数据
2. 点击"加载JSON数据"按钮将数据传递给节点编辑器
3. 或者点击"从文件加载JSON"按钮选择一个JSON文件

### 接收导出的数据

当在Node Editor插件中选择"导出自定义数据"选项时，导出的JSON数据会自动显示在Plugin Launcher的文本框中。这使你可以：

1. 查看导出的数据内容
2. 复制数据用于其他用途
3. 修改后再次加载回节点编辑器

## 通过代码调用

如果你需要从其他插件或脚本中调用Plugin Launcher的功能，可以使用以下代码：

```gdscript
# 获取Plugin Launcher实例
var plugin_launcher = get_editor_interface().get_base_control().find_children("*", "Control", true, false).filter(func(n): return n.name == "Plugin Launcher")[0]

# 传入JSON数据
plugin_launcher.set_json_data('{"your":"json_data"}')
```

## 依赖关系

此插件依赖于Node Editor插件 (`node_editor_plugin`)。确保该插件已安装在你的项目中。

## 自定义

如果你想添加更多按钮来启动其他插件，可以：

1. 在`launcher_dock.tscn`中添加更多按钮
2. 在`launcher_dock.gd`中添加相应的信号和回调函数
3. 在`plugin_launcher.gd`中添加处理这些新信号的逻辑

## 许可证

MIT License 