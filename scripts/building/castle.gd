# @file scripts/building/castle.gd
# @brief 城堡类，继承自Building类
# @author ponywu
# @date 2025-04-21

extends Building

func _ready() -> void:
	building_type = "Castle"
	max_health = 1000  # 城堡有更高的生命值
	current_health = max_health
	super._ready()  # 调用父类的_ready方法

	# 可以在这里添加城堡特有的属性和行为

# 重写摧毁纹理路径获取方法，如果有特定的城堡摧毁纹理
func get_destroy_texture_path() -> String:
	return "res://sprites/Tiny Swords/Factions/Knights/Buildings/Castle/Castle_Destroyed.png"
