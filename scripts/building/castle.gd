# @file scripts/building/castle.gd
# @brief 城堡类，继承自Building类
# @author ponywu
# @date 2025-04-21

extends Building

func _ready() -> void:
	building_type = "Castle"
	max_health = 1000
	current_health = max_health

	super._ready()

# 重写摧毁纹理路径获取方法，如果有特定的城堡摧毁纹理
func get_destroy_texture_path() -> String:
	return "res://sprites/Tiny Swords/Factions/Knights/Buildings/Castle/Castle_Destroyed.png"
