class_name Goods
extends Resource

const WOOD_MAX : Array[int] = [3, 4, 5, 6]
const IRON_MAX : Array[int] = [2, 3, 4, 5]
const RUBY_MAX : Array[int] = [1, 2, 3, 4]

var WOOD_TIER_MAX : Array[int] = _generate_max_size(WOOD_MAX)
var IRON_TIER_MAX : Array[int] = _generate_max_size(IRON_MAX)
var RUBY_TIER_MAX : Array[int] = _generate_max_size(RUBY_MAX)


func _generate_max_size(goods_max : Array[int]) -> Array[int]:
	var result : Array[int] = [goods_max[0]]

	for element_idx in range(1, goods_max.size()):
		result.append(result[-1] + goods_max[element_idx])

	return result


@export var wood : int = 0
@export var iron : int = 0
@export var ruby : int = 0

@export var unlocked_tier_wood : int = 0
@export var unlocked_tier_iron : int = 0
@export var unlocked_tier_ruby : int = 0

# helper variables
var tier_wood : int = 0
var tier_iron : int = 0
var tier_ruby : int = 0

enum SizeDifference {
	BIGGER,
	EQUAL,
	SMALLER,
}

#region INIT

func _init(new_wood: int = 0, new_iron : int = 0, new_ruby : int = 0) -> void:
	wood = new_wood
	iron = new_iron
	ruby = new_ruby


static func from_array(array : Array) -> Goods:
	var wood_ : int = (array[0] if 0 in range(array.size()) else 0)
	var iron_ : int  = (array[1] if 1 in range(array.size()) else 0)
	var ruby_ : int  = (array[2] if 2 in range(array.size()) else 0)
	return Goods.new(wood_, iron_, ruby_)

#endregion INIT


func has_enough(needed : Goods) -> bool:
	return  wood >= needed.wood and \
			iron >= needed.iron and \
			ruby >= needed.ruby


func subtract(cost : Goods) -> void:
	wood -= cost.wood
	iron -= cost.iron
	ruby -= cost.ruby

	# NO NEGATIVE VALUES
	assert(wood >= 0)
	assert(iron >= 0)
	assert(ruby >= 0)

	tier_wood = 0
	tier_iron = 0
	tier_ruby = 0
	for cap_idx in range(WOOD_TIER_MAX.size()):
		if WOOD_TIER_MAX[cap_idx] < wood:
			tier_wood = cap_idx
		if IRON_TIER_MAX[cap_idx] < iron:
			tier_iron = cap_idx
		if RUBY_TIER_MAX[cap_idx] < ruby:
			tier_ruby = cap_idx





func add(resource : Goods) -> void:
	wood += resource.wood
	iron += resource.iron
	ruby += resource.ruby

	# Limiter
	wood = min(wood, WOOD_TIER_MAX[unlocked_tier_wood])
	iron = min(iron, WOOD_TIER_MAX[unlocked_tier_iron])
	ruby = min(ruby, WOOD_TIER_MAX[unlocked_tier_ruby])

	# setting current tier to match hold goods amount
	tier_wood = 0
	tier_iron = 0
	tier_ruby = 0
	for cap_idx in range(WOOD_TIER_MAX.size()):
		if WOOD_TIER_MAX[cap_idx] < wood:
			tier_wood = cap_idx
		if IRON_TIER_MAX[cap_idx] < iron:
			tier_iron = cap_idx
		if RUBY_TIER_MAX[cap_idx] < ruby:
			tier_ruby = cap_idx


func clear() -> void:
	wood = 0
	iron = 0
	ruby = 0


func other_goods_size_in_comparasion(resource : Goods,
	wood_value : int = 1, iron_value : int = 2, ruby_value : int = 3) -> SizeDifference:
	if ruby == resource.ruby and iron == resource.iron and wood == resource.wood:
		return SizeDifference.EQUAL

	if wood * wood_value + iron * iron_value + ruby * ruby_value <= \
	 resource.wood * wood_value + resource.iron * iron_value + resource.ruby * ruby_value:
		return SizeDifference.BIGGER
	else:
		return SizeDifference.SMALLER


#region Display

func to_string_short(empty: String = "") -> String:
	if wood == 0 and iron == 0 and ruby == 0:
		return empty
	var result = ""
	if wood != 0:
		result += "%d 🪓" % wood
	if iron != 0:
		if result != "":
			result += " | "
		result += "%d ⛏️" % iron
	if ruby != 0:
		if result != "":
			result += " | "
		result += "%d 💎" % ruby
	return result

func _to_string() -> String:
	return "%d 🪓| %d ⛏️| %d 💎" % to_array()

func main_player_goods_display() -> String:
	const roman_numbers = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return "[%s] %d/%d 🪓| [%s] %d/%d ⛏️| [%s] %d/%d 💎" % \
	[roman_numbers[unlocked_tier_wood + 1], wood, WOOD_MAX[tier_wood],
	roman_numbers[unlocked_tier_iron + 1], iron, IRON_MAX[tier_iron],
	roman_numbers[unlocked_tier_ruby + 1], ruby, RUBY_MAX[tier_ruby]]


func to_array() -> Array[int]:
	return [wood, iron, ruby]

#endregion Display
