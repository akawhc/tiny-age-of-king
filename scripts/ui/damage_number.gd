extends Node2D

# 伤害数字UI组件
# 用于显示飘动的伤害数字

# 配置
const CONFIG = {
	"duration": 1.0,        # 显示持续时间
	"float_height": 50,     # 上浮高度
	"start_scale": 0.5,     # 初始缩放
	"mid_scale": 1.5,       # 中间缩放
	"end_scale": 1.0,       # 结束缩放
	"font_size": 22,        # 字体大小
}

# 属性
var damage: int = 0          # 伤害值
var label: Label             # 标签组件
var tween: Tween             # 动画组件
var elapsed_time: float = 0  # 已经过时间

func _ready():
	# 创建标签
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 设置字体
	label.add_theme_font_size_override("font_size", CONFIG.font_size)
	label.add_theme_color_override("font_color", Color(1, 0, 0, 1))  # 红色
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))  # 黑色描边
	label.add_theme_constant_override("outline_size", 2)  # 描边大小

	# 设置文本
	label.text = str(damage)

	# 设置位置
	label.position = Vector2(-50, -50)  # 偏移到右上角

	# 添加到场景
	add_child(label)

	# 初始化动画
	_start_animation()

# 初始化
func initialize(damage_amount: int):
	damage = damage_amount
	if label:
		label.text = str(damage)

# 开始动画
func _start_animation():
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 设置初始状态
	scale = Vector2(CONFIG.start_scale, CONFIG.start_scale)
	modulate.a = 0.0

	# 阶段1：出现并放大
	tween.tween_property(self, "modulate:a", 1.0, CONFIG.duration * 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(CONFIG.mid_scale, CONFIG.mid_scale), CONFIG.duration * 0.3)

	# 阶段2：上浮并缩小
	tween.tween_property(self, "position:y", position.y - CONFIG.float_height, CONFIG.duration * 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(CONFIG.end_scale, CONFIG.end_scale), CONFIG.duration * 0.5)

	# 阶段3：淡出
	tween.tween_property(self, "modulate:a", 0.0, CONFIG.duration * 0.3)

	# 结束后销毁
	tween.tween_callback(self.queue_free)

# 更新处理
func _process(delta):
	elapsed_time += delta

	# 超时自动销毁
	if elapsed_time > CONFIG.duration * 1.5:
		queue_free()