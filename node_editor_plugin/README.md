# Godot Node Editor Plugin

这是一个用于Godot编辑器的节点蓝图编辑器插件，允许用户以可视化方式创建和编辑节点蓝图系统。

## 功能特性

- 树状节点蓝图编辑器
- 节点连接和断开
- JSON格式的蓝图导入/导出
- 自定义节点类型支持
- 节点属性编辑
- 实时预览

## 项目结构

```
addons/node_editor_plugin/
├── plugin.cfg                 # 插件配置文件
├── node_editor_plugin.gd      # 主插件脚本
├── node_editor_view.tscn      # 编辑器视图场景
├── node_editor_view.gd        # 编辑器视图脚本
├── nodes/                     # 节点类型定义
│   ├── base_node.gd          # 基础节点类
│   └── custom_nodes/         # 自定义节点类型
├── utils/                     # 工具类
│   ├── json_serializer.gd    # JSON序列化工具
│   └── node_factory.gd       # 节点工厂类
└── ui/                        # UI组件
    ├── node_slot.gd          # 节点连接槽
    └── property_editor.gd    # 属性编辑器
```

## 使用方法

1. 安装插件：
   - 将插件文件夹复制到项目的 `addons` 目录
   - 在Godot编辑器中启用插件

2. 创建新蓝图：
   - 在编辑器左侧找到"Node Editor"面板
   - 点击"New Blueprint"按钮创建新蓝图

3. 编辑节点：
   - 从节点面板拖拽节点到编辑区域
   - 通过连接节点创建逻辑流程
   - 编辑节点属性

4. 导入/导出：
   - 使用"Import"按钮导入JSON格式的蓝图
   - 使用"Export"按钮导出当前蓝图

## 开发计划

- [x] 基础编辑器框架
- [x] 节点连接系统
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