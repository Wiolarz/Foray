@abstract class_name E
extends Object


enum PlayerType
{
	OBSERVER,
	HUMAN,
	BOT,
}

enum MoveType
{
	TURN,
	MOVE,
}


enum CameraPosition {WORLD, BATTLE}

enum WorldMapTiles
{
	SENTINEL,

	# fundamental game logic
	EMPTY,
	WALL,

	# UI based menu interfaces
	CITY,
	PLACE,

	# undefined
	DEPOSIT,
}

static func player_type_to_name(pt : PlayerType) -> String:
	return PlayerType.keys()[pt].to_lower()


static func world_map_tile_to_name(wmt : WorldMapTiles) -> String:
	return WorldMapTiles.keys()[wmt].to_lower()
