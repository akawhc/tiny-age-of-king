# @file: meat.gd
# @brief: 肉类资源
# @author: ponywu
# @date: 2025-04-19

extends CollectibleResource

# 肉类相关常量
const MEAT_CONFIG = {
	"resource_name": "meat",
	"drop_animation": {
		"height": 15,
		"up_time": 0.25,
		"down_time": 0.15
	},
	"collect_animation": {
		"fade_time": 0.2,
		"scale_target": Vector2(0.5, 0.5)
	},
	"decay": {
		"enabled": true,
		"time": 60.0,  # 肉类在60秒后会腐烂
		"color_change": Color(0.7, 0.6, 0.6, 1.0)  # 腐烂后颜色变化
	}
}

# 肉类状态
var is_fresh: bool = true
var decay_timer: float = 0.0

# 重写准备配置方法
func _prepare_config() -> void:
	config = MEAT_CONFIG

# 扩展_ready方法初始化腐烂计时器
func _ready() -> void:
	# 设置资源类型和数量
	resource_type = "meat"
	amount = 4  # 每个肉类资源提供4单位

	super._ready()  # 调用父类的_ready方法
	add_to_group("resources")  # 将肉类资源添加到resources组
	is_fresh = true
	decay_timer = 0.0

# 添加_process方法处理腐烂逻辑
func _process(delta: float) -> void:
	if is_fresh and config.decay.enabled:
		decay_timer += delta
		if decay_timer >= config.decay.time:
			is_fresh = false
			_apply_decay_visual()
			print("肉类已经腐烂！")

# 应用腐烂的视觉效果
func _apply_decay_visual() -> void:
	modulate = config.decay.color_change

# 重写收集方法，考虑到腐烂状态
func collected_by_worker() -> void:
	# 这里可以添加根据腐烂状态的不同处理逻辑
	# 例如对工人造成减益效果或者只给一半的资源等
	if not is_fresh:
		print("收集了腐烂的肉类！")

	queue_free()  # 删除肉类实例

# 添加设置新鲜度状态的方法
func set_freshness(fresh: bool) -> void:
	if fresh:
		modulate = Color(1, 1, 1)  # 新鲜状态为正常颜色
	else:
		modulate = Color(0.7, 0.6, 0.6, 1.0)  # 腐烂状态为灰暗色调
		print("这块肉已经腐烂了！")
