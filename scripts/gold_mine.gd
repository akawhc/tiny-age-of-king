extends Sprite2D

signal mine_depleted(position)

# 金矿相关常量
const MINE_CONFIG = {
	"detection_radius": 64,  # 检测范围
	"damage_cooldown": 0.2,  # 挖掘冷却时间
	"gold_spawn": {
		"min_count": 1,  # 最小金矿生成数量
		"max_count": 3,  # 最大金矿生成数量
		"spread_range": 20  # 金矿散布范围
	},
	"mining": {
		"worker_damage": 5,  # 工人单次挖矿伤害
		"mining_rate": 1.0,  # 工人挖矿速率（秒/次）
		"efficiency_multiplier": 1.0  # 效率倍率
	}
}

# 金矿状态纹理路径
const MINE_TEXTURES = {
	"ACTIVE": "res://sprites/Tiny Swords/Resources/Gold Mine/GoldMine_Active.png",  # 活跃状态纹理路径
	"DESTROYED": "res://sprites/Tiny Swords/Resources/Gold Mine/GoldMine_Destroyed.png"  # 被挖空状态纹理路径
}

# 预加载纹理
var texture_active: Texture2D
var texture_destroyed: Texture2D

@export var max_health: int = 1000
var current_health: int = max_health
var is_being_mined: bool = false
var mine_cooldown: bool = false
var is_depleted: bool = false  # 是否已经被挖空
var miners = []  # 存储正在挖矿的工人

# 节点引用
@onready var detection_area: Area2D = $DetectionArea
@onready var collision_body: StaticBody2D = $CollisionBody
# 预加载金币资源场景
@onready var gold_scene = preload("res://scenes/gold.tscn")

func _ready() -> void:
	add_to_group("mines")
	current_health = max_health

	# 加载纹理
	texture_active = load(MINE_TEXTURES.ACTIVE)
	texture_destroyed = load(MINE_TEXTURES.DESTROYED)

	# 设置初始纹理
	texture = texture_active

	# 连接信号
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

	print("金矿初始化完成，储量：", current_health, "/", max_health)

# 当工人进入检测范围
func _on_body_entered(body: Node2D) -> void:
	if is_depleted:
		print("工人进入了已挖空的金矿范围")
		return

	if body.is_in_group("workers"):
		# 通知工人附近有金矿
		body.set_nearest_mine(self)
		print("工人进入金矿范围，按空格键挖矿")

# 当工人离开检测范围
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("workers"):
		# 通知工人离开金矿范围
		if body.nearest_mine == self:
			body.set_nearest_mine(null)
			print("工人离开金矿范围")

# 处理挖矿造成的伤害
func take_damage(damage: int) -> void:
	if is_depleted:
		print("金矿已经被挖空，无法继续挖掘")
		return

	current_health -= damage
	print("金矿受到挖掘，伤害: ", damage, " 剩余储量: ", current_health, "/", max_health)

	# 检查是否已经挖空
	if current_health <= 0:
		deplete_mine()

# 金矿被挖空
func deplete_mine() -> void:
	if is_depleted:
		return

	is_depleted = true
	current_health = 0

	# 更改纹理为挖空状态
	texture = texture_destroyed

	# 发出信号通知金矿已被挖空
	emit_signal("mine_depleted", global_position)

	print("金矿已被完全挖空！")
