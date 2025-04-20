# @file: arrow.gd
# @brief: 箭矢脚本，处理飞行、碰撞和伤害
# @author: ponywu

extends Area2D

# 箭矢配置
const ARROW_CONFIG = {
	"lifetime": 5.0,  # 箭矢存在的最大时间(秒)
	"hit_effect_time": 0.1,  # 命中闪烁时间
}

# 箭矢属性
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: int = 10
var source = null  # 箭矢发射者

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
	rotation = direction.angle()

	# 播放飞行动画
	if animated_sprite:
		animated_sprite.play("fly")

	# 创建自动销毁定时器
	var timer = get_tree().create_timer(ARROW_CONFIG.lifetime)
	timer.timeout.connect(_on_lifetime_timeout)

func _process(delta: float) -> void:
	# 更新生命周期
	lifetime += delta

	# 如果超过最大生命周期，销毁箭矢
	if lifetime >= ARROW_CONFIG.lifetime:
		queue_free()
		return

func _physics_process(delta: float) -> void:
	# 移动箭矢
	global_position += direction * speed * delta

# 初始化箭矢
func initialize(dir: Vector2, dmg: int, spd: float, src = null) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	source = src

	# 设置初始旋转
	rotation = direction.angle()

# 当箭矢击中物体
func _on_body_entered(body: Node2D) -> void:
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
