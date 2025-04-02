@tool
extends SyntaxHighlighter

# 简单的JSON语法高亮器
class_name JsonSyntaxHighlighter

# 颜色定义
var string_color = Color(0.8, 0.5, 0.2)       # 字符串颜色
var number_color = Color(0.3, 0.7, 0.9)       # 数字颜色
var keyword_color = Color(0.9, 0.3, 0.3)      # 关键字颜色（true/false/null）
var symbol_color = Color(0.8, 0.8, 0.8)       # 符号颜色
var property_color = Color(0.5, 0.8, 0.5)     # 属性名颜色

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var highlighting = {}
	var text = get_text_edit().get_line(line)
	
	# 处理字符串
	var in_string = false
	var string_start = -1
	
	for i in range(text.length()):
		var c = text[i]
		
		# 处理字符串
		if c == '"' and (i == 0 or text[i-1] != '\\'):
			if in_string:
				# 字符串结束
				highlighting[string_start] = {
					"color": string_color,
					"end_column": i + 1
				}
				in_string = false
			else:
				# 字符串开始
				string_start = i
				in_string = true
		
		# 如果在字符串内部，跳过其他处理
		if in_string:
			continue
			
		# 处理属性名（键）
		if c == '"':
			var colon_pos = text.find(":", i)
			if colon_pos != -1 and text.substr(i, colon_pos - i).strip_edges().begins_with('"'):
				highlighting[i] = {
					"color": property_color,
					"end_column": colon_pos
				}
				
		# 处理数字
		elif c.is_valid_int() or c == '-' or c == '.':
			var j = i
			# 向前查看是否为数字的一部分
			if j > 0 and (text[j-1].is_valid_int() or text[j-1] == '.'):
				continue
				
			# 向后查找完整数字
			while j < text.length() and (text[j].is_valid_int() or text[j] == '.' or text[j] == 'e' or text[j] == 'E' or text[j] == '-' or text[j] == '+'):
				j += 1
				
			if j > i:
				highlighting[i] = {
					"color": number_color,
					"end_column": j
				}
				
		# 处理关键字
		elif c == 't' and text.substr(i, 4) == "true":
			highlighting[i] = {
				"color": keyword_color,
				"end_column": i + 4
			}
		elif c == 'f' and text.substr(i, 5) == "false":
			highlighting[i] = {
				"color": keyword_color,
				"end_column": i + 5
			}
		elif c == 'n' and text.substr(i, 4) == "null":
			highlighting[i] = {
				"color": keyword_color,
				"end_column": i + 4
			}
		
		# 处理符号
		elif c in ['{', '}', '[', ']', ':', ',']:
			highlighting[i] = {
				"color": symbol_color,
				"end_column": i + 1
			}
	
	return highlighting 
