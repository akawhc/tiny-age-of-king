# file: castle.gd
# author: ponywu
# date: 2024-03-24
# description: 城堡建筑脚本

extends Node2D

# 建筑状态
enum BuildingState {
	PREVIEW,        # 预览状态
	CONSTRUCTING,   # 建造中
	COMPLETED,      # 建造完成
	DESTROYED       # 被摧毁
}

# 建筑配置
const CASTLE_CONFIG = {
	"health": {
		"max": 1000,
		"construction": 200
	},
	"construction": {
		"time": 5.0,  # 建造时间
		"worker_distance": 50.0,  # 工人建造距离
		"worker_speed_bonus": 0.2  # 每个额外工人提供的建造速度加成（20%）
	},
	"visual": {
		"construction_opacity": 0.7,
		"completed_opacity": 1.0
	}
}

# 状态变量
var current_state: BuildingState = BuildingState.PREVIEW
var current_health: float = 0
var construction_progress: float = 0.0
var builders: Array[Node2D] = []

# 节点引用
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	# 初始化建筑
	add_to_group("buildings")

	if current_state == BuildingState.PREVIEW:
		# 预览状态下禁用碰撞和进度条
		collision_shape.disabled = true
		progress_bar.visible = false
	else:
		# 正常状态下的初始化
		current_health = CASTLE_CONFIG.health.construction
		_update_visuals()

func _process(delta: float) -> void:
	if current_state == BuildingState.CONSTRUCTING:
		_update_construction(delta)

func start_construction(workers: Array[Node2D]) -> void:
	if workers.is_empty():
		return

	builders = workers
	current_state = BuildingState.CONSTRUCTING
	collision_shape.disabled = false
	progress_bar.visible = true
	progress_bar.value = 0

	# 设置初始外观
	sprite.modulate.a = CASTLE_CONFIG.visual.construction_opacity
	sprite.play("construction")

	# 设置所有工人的建造状态
	for worker in builders:
		if worker.has_method("start_building"):
			worker.start_building(self)

func _update_construction(delta: float) -> void:
	# 计算有效的建造者数量
	var active_builders = 0
	for builder in builders:
		if not is_instance_valid(builder):
			continue

		# 检查工人是否在建造范围内
		var distance = global_position.distance_to(builder.global_position)
		if distance <= CASTLE_CONFIG.construction.worker_distance:
			active_builders += 1

	if active_builders == 0:
		return

	# 计算建造速度加成
	var speed_multiplier = 1.0 + (active_builders - 1) * CASTLE_CONFIG.construction.worker_speed_bonus

	# 更新建造进度
	construction_progress += (delta / CASTLE_CONFIG.construction.time) * speed_multiplier
	progress_bar.value = construction_progress * 100

	if construction_progress >= 1.0:
		_complete_construction()

func _complete_construction() -> void:
	current_state = BuildingState.COMPLETED
	current_health = CASTLE_CONFIG.health.max
	progress_bar.visible = false

	# 更新外观
	sprite.modulate.a = CASTLE_CONFIG.visual.completed_opacity
	sprite.play("default")

	# 通知所有工人建造完成
	for builder in builders:
		if is_instance_valid(builder) and builder.has_method("finish_building"):
			builder.finish_building()

	# 清空建造者列表
	builders.clear()

func _update_visuals() -> void:
	# 根据状态更新视觉效果
	match current_state:
		BuildingState.PREVIEW:
			sprite.modulate.a = 0.5
		BuildingState.CONSTRUCTING:
			sprite.modulate.a = CASTLE_CONFIG.visual.construction_opacity
		BuildingState.COMPLETED:
			sprite.modulate.a = CASTLE_CONFIG.visual.completed_opacity
		BuildingState.DESTROYED:
			sprite.modulate.a = 0.3

func take_damage(damage: float) -> void:
	if current_state != BuildingState.COMPLETED:
		return

	current_health -= damage
	if current_health <= 0:
		_destroy()

func _destroy() -> void:
	current_state = BuildingState.DESTROYED
	sprite.play("destroyed")
	collision_shape.disabled = true
