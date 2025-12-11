class_name WorldMoveInfo
extends Resource

const TYPE_END_TURN = "end_turn"
const TYPE_TRAVEL = "travel"
const TYPE_RECRUIT_HERO = "recruit_hero"
const TYPE_RECRUIT_UNIT = "recruit_unit"
const TYPE_TRADE = "trade" # make transaction
const TYPE_START_TRADE = "start_trade"
const TYPE_BUILD = "build"
const TYPE_RITUAL = "ritual"

class RecruitHeroInfo extends Resource:
	@export var player_index : int = -1
	@export var data_hero : DataHero


@export var move_type: String = ""
@export var move_source: Vector2i
@export var target_tile_coord: Vector2i
@export var recruit_hero_info : RecruitHeroInfo = null
@export var data : Resource = null

#region make moves

static func make_end_turn() -> WorldMoveInfo:
	var result : WorldMoveInfo = WorldMoveInfo.new()
	result.move_type = TYPE_END_TURN
	return result

#TODO: enter_city_ remove, add other MOVE type for opening city trade
# update: trade state is only UI trait -- only each transaction is a move
static func make_world_travel(src : Vector2i, dst : Vector2i) -> WorldMoveInfo:
	var result : WorldMoveInfo = WorldMoveInfo.new()
	result.move_type = TYPE_TRAVEL
	result.move_source = src
	result.target_tile_coord = dst
	if src == dst:
		push_error("cannot move in place")
	return result


## TODO implement starting of trade or delete it
static func make_start_trade(army_coord : Vector2i, city_coord : Vector2i) \
		-> WorldMoveInfo:
	var result : WorldMoveInfo = WorldMoveInfo.new()
	result.move_type = TYPE_START_TRADE
	result.target_tile_coord = city_coord
	result.move_source = army_coord
	return result


static func make_recruit_hero(player_index : int, data_hero : DataHero, \
		coord : Vector2i) -> WorldMoveInfo:
	var result : WorldMoveInfo = WorldMoveInfo.new()
	result.move_type = TYPE_RECRUIT_HERO
	result.target_tile_coord = coord
	result.recruit_hero_info = RecruitHeroInfo.new()
	result.recruit_hero_info.player_index = player_index
	result.recruit_hero_info.data_hero = data_hero
	return result


static func make_recruit_unit(city_coord : Vector2i, army_coord : Vector2i,
		data_unit : DataUnit) -> WorldMoveInfo:
	var result : WorldMoveInfo = WorldMoveInfo.new()
	result.move_type = TYPE_RECRUIT_UNIT
	result.move_source = city_coord
	result.target_tile_coord = army_coord
	result.data = data_unit
	return result


static func make_build(city_coord : Vector2i, \
		building_data : DataBuilding) -> WorldMoveInfo:
	var result : WorldMoveInfo = WorldMoveInfo.new()
	result.move_type = TYPE_BUILD
	result.target_tile_coord = city_coord
	result.data = building_data
	return result


## TODO implement trades
static func make_trade() -> WorldMoveInfo:
	var result : WorldMoveInfo = WorldMoveInfo.new()
	result.move_type = TYPE_TRADE
	return result


static func make_ritual(
		army_coord : Vector2i,
		target_coord : Vector2i,
		ritual : Ritual
)-> WorldMoveInfo:
	var result : WorldMoveInfo = WorldMoveInfo.new()
	result.move_type = TYPE_RITUAL
	result.move_source = army_coord
	result.target_tile_coord = target_coord
	result.data = ritual
	return result

#endregion make moves


#region Network

static func make_recruit_hero_from_network(player_index : int, \
		hero : String, coord : Vector2i) -> WorldMoveInfo:
	return make_recruit_hero(player_index, DataHero.from_network_id(hero), \
		coord)


static func make_recruit_unit_from_network(city_coord : Vector2i,
		army_coord : Vector2i, unit : String) -> WorldMoveInfo:
	return make_recruit_unit(city_coord, army_coord, DataUnit.from_network_id(unit))


static func make_build_from_network(city_coord : Vector2i, \
		building_data : String) -> WorldMoveInfo:
	return make_build(city_coord, DataBuilding.from_network_id(building_data))


#endregion Network


# TODO make this function at least tell what kind of move it is
func _to_string() -> String:
	return str(target_tile_coord) + " from " + str(move_source)
