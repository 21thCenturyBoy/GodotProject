# Godot Node Editor Plugin

这是一个用于Godot编辑器的节点蓝图编辑器插件，允许用户以可视化方式创建和编辑节点蓝图系统。

## 功能特性

- 树状节点蓝图编辑器
- 节点连接和断开
- JSON格式的蓝图导入/导出
- 自定义节点类型支持
- 节点属性编辑
- 实时预览
- 插件启动器面板 (新增!)

## 项目结构

```
addons/
├── node_editor_plugin/        # 节点编辑器插件
│   ├── plugin.cfg             # 插件配置文件
│   ├── node_editor_plugin.gd  # 主插件脚本
│   ├── node_editor_view.tscn  # 编辑器视图场景
│   ├── node_editor_view.gd    # 编辑器视图脚本
│   ├── nodes/                 # 节点类型定义
│   │   ├── base_node.gd      # 基础节点类
│   │   └── custom_nodes/     # 自定义节点类型
│   └── ...
│
└── plugin_launcher/           # 插件启动器插件 (新增!)
    ├── plugin.cfg             # 插件配置文件
    ├── plugin_launcher.gd     # 主插件脚本
    ├── launcher_dock.tscn     # 启动器面板场景
    ├── launcher_dock.gd       # 启动器面板脚本
    └── README.md              # 启动器插件说明文档
```

## 使用方法

1. 安装插件：
   - 将插件文件夹复制到项目的 `addons` 目录
   - 在Godot编辑器中启用插件

2. 使用插件启动器：
   - 在编辑器右上角找到"Plugin Launcher"面板
   - 点击"Launch Node Editor"按钮启动节点编辑器插件

3. 创建新蓝图：
   - 在节点编辑器面板中点击"New Blueprint"按钮创建新蓝图

4. 编辑节点：
   - 从节点面板拖拽节点到编辑区域
   - 通过连接节点创建逻辑流程
   - 编辑节点属性

5. 导入/导出：
   - 使用"Import"按钮导入JSON格式的蓝图
   - 使用"Export"按钮导出当前蓝图

## 开发计划

- [x] 基础编辑器框架
- [x] 节点连接系统
- [x] 插件启动器面板
- [ ] JSON序列化
- [ ] 自定义节点支持
- [ ] 属性编辑器
- [ ] 实时预览
- [ ] 撤销/重做系统
- [ ] 节点搜索和过滤
- [ ] 蓝图模板系统

## 贡献指南

欢迎提交Issue和Pull Request来帮助改进这个插件。

## 许可证

MIT License 