# @file scripts/building/wood_house.gd
# @brief 木屋类，哥布林的巢穴，继承自Building类
# @author ponywu
# @date 2025-04-21

extends Building

# 哥布林巢穴配置
const WOOD_HOUSE_CONFIG = {
	"health": 200,         # 生命值
	"spawn_interval": 10.0, # 生成哥布林的间隔（秒）
	"max_goblins": 6,       # 最大生成哥布林数量
}

# 生成计时器
var spawn_timer: Timer
var active_goblins: int = 0
var goblin_types = ["torch", "barrel", "tnt"] # 可生成的哥布林类型

func _ready() -> void:
	building_type = "WoodHouse"
	max_health = WOOD_HOUSE_CONFIG.health
	current_health = max_health

	# 先调用父类的_ready，这会将此对象添加到buildings组
	super._ready()

	# 从buildings组移除，只保留在goblin_buildings组中
	remove_from_group("buildings")

	# 添加到哥布林建筑组
	add_to_group("goblin_buildings")

	# 设置生成计时器
	setup_spawn_timer()

# 重写摧毁纹理路径获取方法
func get_destroy_texture_path() -> String:
	return "res://sprites/Tiny Swords/Factions/Goblins/Buildings/Wood_House/Goblin_House_Destroyed.png"

# 设置生成计时器
func setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = WOOD_HOUSE_CONFIG.spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

# 计时器超时，生成哥布林
func _on_spawn_timer_timeout() -> void:
	# 如果已经摧毁，停止生成
	if is_destroyed:
		spawn_timer.stop()
		return

	# 如果达到最大数量，不再生成
	if active_goblins >= WOOD_HOUSE_CONFIG.max_goblins:
		return

	# 生成哥布林
	spawn_goblin()

# 生成哥布林
func spawn_goblin() -> void:
	# 随机选择哥布林类型
	var goblin_type = goblin_types[randi() % goblin_types.size()]

	# 根据类型加载对应场景
	var goblin_scene_path = "res://scenes/goblin/" + goblin_type + ".tscn"

	# 检查场景是否存在
	if not ResourceLoader.exists(goblin_scene_path):
		print("错误：找不到哥布林场景：", goblin_scene_path)
		return

	# 加载场景
	var goblin_scene = load(goblin_scene_path)
	var goblin_instance = goblin_scene.instantiate()

	# 设置生成位置（在房屋周围随机位置）
	var spawn_radius = 100.0
	var random_angle = randf() * 2.0 * PI
	var spawn_position = global_position + Vector2(
		cos(random_angle) * spawn_radius,
		sin(random_angle) * spawn_radius
	)

	goblin_instance.global_position = spawn_position

	# 添加到场景
	get_tree().get_root().add_child(goblin_instance)

	# 增加计数
	active_goblins += 1

	# 连接哥布林的销毁信号
	if goblin_instance.has_signal("goblin_destroyed"):
		goblin_instance.goblin_destroyed.connect(_on_goblin_destroyed)

	print("哥布林木屋生成了一个 ", goblin_type, " 哥布林")

# 哥布林被摧毁的回调
func _on_goblin_destroyed() -> void:
	active_goblins = max(0, active_goblins - 1)
	print("current active goblins: ", active_goblins)

# 重写摧毁方法，确保停止生成
func destroy() -> void:
	super.destroy()

	# 停止生成计时器
	if spawn_timer:
		spawn_timer.stop()

	print("哥布林木屋被摧毁")

# 重写take_damage方法，兼容骑士的攻击逻辑
func take_damage(damage_amount: int, _knockback_vector = null, _knockback_time = null) -> void:
	# 否则调用父类方法正常受伤
	super.take_damage(damage_amount)
