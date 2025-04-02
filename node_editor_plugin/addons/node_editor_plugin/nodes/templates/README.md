# 节点模板

本目录包含节点编辑器的节点模板定义文件。模板采用JSON格式，用于定义不同类型的节点及其属性。

## 模板格式说明

节点模板文件采用JSON格式，应包含以下字段：

```json
{
  "id": "模板ID",
  "name": "节点名称",
  "description": "节点描述",
  "type": 节点类型(整数),
  "color": "R,G,B[,A]",
  "inputs": ["输入槽1", "输入槽2", ...],
  "outputs": ["输出槽1", "输出槽2", ...],
  "size": {
	"x": 宽度,
	"y": 高度
  },
  "properties": {
	"属性名1": {
	  "type": "类型",
	  "default": "默认值"
	},
	"属性名2": {
	  "type": "类型",
	  "default": "默认值"
	},
	...
  }
}
```

### 字段说明

- **id**: 模板的唯一标识符
- **name**: 节点在UI中显示的名称
- **description**: 节点的功能描述，会在模板选择对话框中显示
- **type**: 节点类型，对应于`BaseNode.NodeType`枚举值
  - 0: INPUT - 输入节点
  - 1: OUTPUT - 输出节点
  - 2: PROCESS - 处理节点
  - 3: CONDITION - 条件节点
  - 4: CUSTOM - 自定义节点
- **color**: 节点背景颜色，格式为"R,G,B"或"R,G,B,A"，值的范围为0~1
- **inputs**: 输入槽名称数组
- **outputs**: 输出槽名称数组
- **size**: 节点的初始大小
- **properties**: 节点属性定义，每个属性包含类型和默认值

## 示例模板

### 输入节点
```json
{
  "id": "input_node",
  "name": "输入节点",
  "description": "用于接收外部输入的节点",
  "type": 0,
  "color": "0.2,0.4,0.6",
  "inputs": [],
  "outputs": ["输出1", "输出2"],
  "size": {
	"x": 180,
	"y": 120
  },
  "properties": {
	"input_value": {
	  "type": "string",
	  "default": ""
	}
  }
}
```

### 处理节点
```json
{
  "id": "process_node",
  "name": "处理节点",
  "description": "用于处理数据的节点",
  "type": 2,
  "color": "0.3,0.3,0.5",
  "inputs": ["输入1", "输入2"],
  "outputs": ["输出1", "输出2"],
  "size": {
	"x": 200,
	"y": 150
  },
  "properties": {
	"operation": {
	  "type": "string",
	  "default": "处理"
	}
  }
}
```

## 如何添加新模板

1. 在本目录中创建新的JSON文件，命名可以是`<模板ID>.json`
2. 按照上述格式定义节点模板
3. 保存文件后，重新加载节点编辑器，新模板将自动显示在添加节点对话框中

## 注意事项

- 确保每个模板的`id`字段是唯一的
- 确保JSON格式正确，否则模板可能无法加载
- 颜色值应在0到1之间，例如"0.5,0.1,0.9"表示RGB值为(0.5,0.1,0.9) 
