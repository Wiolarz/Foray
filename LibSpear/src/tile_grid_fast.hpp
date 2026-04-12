#ifndef TILE_GRID_FAST_H
#define TILE_GRID_FAST_H

#include "godot_cpp/classes/node.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include "godot_cpp/variant/string.hpp"
#include "godot_cpp/core/defs.hpp"
#include <stdint.h>
#include <array>
#include <span>

#include "data.hpp"
#include "battle_structs.hpp"

namespace libspear {

class TileGridFast {
	godot::Vector2i _dims;
	unsigned _number_of_mana_wells = 0;
	std::array<Tile, MAX_TILES_IN_GRID> _tiles{};
	std::array<std::array<Position, MAX_UNITS_IN_ARMY>, MAX_ARMIES> _spawns{};
	std::array<uint8_t, MAX_ARMIES> _numbers_of_spawns{};

	friend class TileGridFastCpp;

public:
	_FORCE_INLINE_ Tile get_tile(Position pos) {
		int idx = pos.x + pos.y * _dims.x;
		if(pos.x < 0 || pos.x >= _dims.x || pos.y < 0 || pos.y >= _dims.y) {
			return Tile();
		}
		return _tiles[idx];
	}

	void set_tile(Position pos, Tile tile);
	constexpr std::span<const Position> get_spawns(int army) const {
		return std::span(_spawns[army]).subspan(0, _numbers_of_spawns[army]);
	}

	unsigned get_number_of_mana_wells() const {
		return _number_of_mana_wells;
	}

	godot::Vector2i get_dims() const {
		return _dims;
	}
};

class TileGridFastCpp : public godot::Node {
	GDCLASS(TileGridFastCpp, Node);

	TileGridFast grid;

protected:
	static void _bind_methods();

public:
	TileGridFast get_grid_copy() {
		return grid;
	}

	void set_map_size(godot::Vector2i dimensions);
	void set_tile(
			godot::Vector2i pos, bool passable, bool wall, bool swamp,
			bool mana_well, bool pit, bool hill, bool fire, int army, unsigned direction
	) {
		grid.set_tile(Position(pos.x, pos.y), Tile(passable, wall, swamp, mana_well, pit, hill, fire, army, direction));
	}

	godot::Vector2i get_dims() const {
		return grid.get_dims();
	}
};

}

#endif
