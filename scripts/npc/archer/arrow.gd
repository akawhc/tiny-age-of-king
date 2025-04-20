# @file: arrow.gd
# @brief: 箭矢脚本，处理飞行、碰撞和伤害
# @author: ponywu

extends Area2D

# 箭矢配置
const ARROW_CONFIG = {
	"lifetime": 5.0,  # 箭矢存在的最大时间(秒)
	"hit_effect_time": 0.1,  # 命中闪烁时间
	"rotation_speed": 0.15,  # 每秒旋转速度（弧度）
	"rotation_delay": 0.6,  # 开始旋转前的延迟（秒）
	"max_rotation": 10.0,  # 最大旋转角度（度），达到时视为落地
}

# 箭矢属性
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: int = 10
var source = null  # 箭矢发射者
var initial_rotation: float = 0.0
var total_rotation: float = 0.0  # 单位：度
var has_landed: bool = false
var rotation_direction: int = 1  # 旋转方向： 1 = 顺时针, -1 = 逆时针

# 生命周期计时器
var lifetime: float = 0.0

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 添加到箭矢组
	add_to_group("projectiles")

	# 连接信号
	body_entered.connect(_on_body_entered)

	# 设置初始旋转，使箭头方向与移动方向一致
	initial_rotation = direction.angle()
	rotation = initial_rotation

	# 确定旋转方向，使箭头始终向下旋转
	_determine_rotation_direction()

	# 播放飞行动画
	if animated_sprite:
		animated_sprite.play("fly")

	# 创建自动销毁定时器
	var timer = get_tree().create_timer(ARROW_CONFIG.lifetime)
	timer.timeout.connect(_on_lifetime_timeout)

# 确定箭的旋转方向，使其始终向下旋转
func _determine_rotation_direction() -> void:
	# 计算箭头的朝向角度，归一化到 -PI 到 PI 之间
	var angle = direction.angle()

	# 向右发射的箭（0度左右）：顺时针旋转（向下）
	# 向左发射的箭（PI或-PI附近）：逆时针旋转（向下）
	# 向上发射的箭（-PI/2附近）：顺时针旋转（向右下）
	# 向下发射的箭（PI/2附近）：逆时针旋转（向左下）

	# 使用余弦判断方向，确保箭始终向下旋转
	var cos_angle = cos(angle)

	if cos_angle > 0:  # 大致向右的箭
		rotation_direction = 1  # 顺时针
	else:  # 大致向左的箭
		rotation_direction = -1  # 逆时针

	# 特殊情况：几乎垂直向上或向下的箭
	if abs(cos_angle) < 0.2:  # 接近垂直方向
		if sin(angle) < 0:  # 向上
			rotation_direction = 1  # 顺时针
		else:  # 向下
			rotation_direction = -1  # 逆时针

	print("箭矢方向: ", rad_to_deg(angle), "度, 旋转方向: ", "顺时针" if rotation_direction > 0 else "逆时针")

func _process(delta: float) -> void:
	# 如果已经落地，不再处理
	if has_landed:
		return

	# 更新生命周期
	lifetime += delta

	# 如果超过最大生命周期，销毁箭矢
	if lifetime >= ARROW_CONFIG.lifetime:
		queue_free()
		return

	# 更新箭矢旋转，模拟下坠效果
	update_rotation(delta)

	# 检查是否达到最大旋转（落地）
	if total_rotation >= ARROW_CONFIG.max_rotation:
		land_arrow()

func _physics_process(delta: float) -> void:
	# 如果已经落地，不再移动
	if has_landed:
		return

	# 移动箭矢
	global_position += direction * speed * delta

# 更新箭矢旋转
func update_rotation(delta: float) -> void:
	# 延迟一段时间后开始旋转
	if lifetime > ARROW_CONFIG.rotation_delay:
		# 箭矢随时间旋转，模拟下坠效果
		var rotation_amount_rad = ARROW_CONFIG.rotation_speed * delta

		# 为了保持物理感，旋转速度随时间增加
		var time_factor = 1.0 + (lifetime - ARROW_CONFIG.rotation_delay) * 0.5
		rotation_amount_rad *= time_factor

		# 应用旋转方向
		rotation_amount_rad *= rotation_direction

		# 将弧度转为角度
		var rotation_amount_deg = abs(rotation_amount_rad) * 180 / PI

		# 计算总旋转角度（度）
		total_rotation += rotation_amount_deg

		# 限制旋转幅度
		if total_rotation > ARROW_CONFIG.max_rotation:
			rotation_amount_rad = rotation_direction * ((ARROW_CONFIG.max_rotation - (total_rotation - rotation_amount_deg)) * PI / 180)
			total_rotation = ARROW_CONFIG.max_rotation

		# 应用旋转
		rotation += rotation_amount_rad

# 箭矢落地
func land_arrow() -> void:
	has_landed = true
	speed = 0

	# 播放落地动画或效果
	if animated_sprite:
		animated_sprite.play("shoot")  # 使用命中动画作为落地动画

	# 延迟后消失
	var land_timer = get_tree().create_timer(0.5)
	land_timer.timeout.connect(func(): queue_free())

	print("箭矢落地")

# 初始化箭矢
func initialize(dir: Vector2, dmg: int, spd: float, src = null) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	source = src

	# 设置初始旋转
	initial_rotation = direction.angle()
	rotation = initial_rotation

# 当箭矢击中物体
func _on_body_entered(body: Node2D) -> void:
	# 如果已经落地，不再处理碰撞
	if has_landed:
		return

	# 忽略发射者和其他箭矢
	if body == source or body.is_in_group("projectiles"):
		return

	# 检查是否可以造成伤害
	if body.has_method("take_damage"):
		# 造成伤害
		body.take_damage(damage)
		print("箭矢命中 ", body.name, " 造成 ", damage, " 点伤害")

		# 播放命中效果
		_play_hit_effect()

	# 箭矢命中后销毁
	queue_free()

# 生命周期结束
func _on_lifetime_timeout() -> void:
	queue_free()

# 播放命中效果
func _play_hit_effect() -> void:
	# 切换到命中动画
	if animated_sprite:
		animated_sprite.play("shoot")

	# 闪烁效果
	var hit_tween = create_tween()
	hit_tween.tween_property(self, "modulate", Color(1, 0, 0, 0.8), ARROW_CONFIG.hit_effect_time)
	hit_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), ARROW_CONFIG.hit_effect_time)
