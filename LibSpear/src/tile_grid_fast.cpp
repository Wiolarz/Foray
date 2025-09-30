#include "tile_grid_fast.hpp"
#include <algorithm>


void TileGridFast::set_tile(Position pos, Tile type) {
	unsigned idx = pos.x + pos.y * _dims.x;
	if(idx >= _tiles.size()) {
		printf("ERROR - invalid tile position %d %d (idx - %d, dims - %dx%d)\n", pos.x, pos.y, idx, _dims.x, _dims.y);
		return;
	}
	int old_army = _tiles[idx].get_spawning_army();
	int new_army = type.get_spawning_army();

	if(old_army != -1) {
		Position* old_spawn = std::find(_spawns[old_army].begin(), _spawns[old_army].end(), pos);
		// Put the last spawn position in the place of replaced spawn position
		*old_spawn = _spawns[old_army][_numbers_of_spawns[old_army]-1];
		_numbers_of_spawns[old_army]--;
	}

	if(new_army != -1) {
		_spawns[new_army][_numbers_of_spawns[new_army]] = pos;
		_numbers_of_spawns[new_army]++;
	}

	if(_tiles[idx].is_mana_well()) {
		_number_of_mana_wells--;
	}

	if(type.is_mana_well()) {
		_number_of_mana_wells++;
	}

	_tiles[idx] = type;
}

void TileGridFastCpp::set_map_size(Vector2i dimensions) {
	grid._dims = dimensions;
}

void TileGridFastCpp::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_tile", "passable", "wall", "swamp", "mana_well", "pit", "army", "direction"), &TileGridFastCpp::set_tile);
	ClassDB::bind_method(D_METHOD("set_map_size", "dimensions"), &TileGridFastCpp::set_map_size);
}


