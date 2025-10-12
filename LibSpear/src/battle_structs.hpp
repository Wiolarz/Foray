#ifndef BATTLE_STRUCTS_H
#define BATTLE_STRUCTS_H

#include <cstdint>
#include <array>
#include <functional>
#include "godot_cpp/variant/array.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include "godot_cpp/variant/variant.hpp"
#include "godot_cpp/core/error_macros.hpp"

#include "data.hpp"
#include "army.hpp"

class BattleManagerFast;
class BattleMCTSManager;

using Score = int16_t;

struct BattleResult {
	int8_t winner_team = -1;
	bool error = false;
	std::array<Score, MAX_ARMIES> max_scores{0};
	std::array<Score, MAX_ARMIES> total_scores{0};
	std::array<Score, MAX_ARMIES> score_gained{0};
	std::array<Score, MAX_ARMIES> score_lost{0};
};



struct Move {
	static const int8_t NO_SPELL = -1;

	int8_t spell_id = NO_SPELL;
	uint8_t unit = 255;
	Position pos{-1, -1};

	Move() = default;
	Move(uint8_t _unit, Position _pos, int8_t _spell_id = NO_SPELL) : spell_id(_spell_id), unit(_unit), pos(_pos) {}
	Move(godot::Array libspear_tuple) {
		ERR_FAIL_COND_MSG(libspear_tuple.size() < 2 || libspear_tuple.size() > 3, "Invalid LibSpear tuple size");
		unit = libspear_tuple[0];
		pos = Position(libspear_tuple[1]);
		spell_id = (libspear_tuple.size() >= 3) ? int8_t(libspear_tuple[2]) : NO_SPELL;
	}

	std::strong_ordering operator<=>(const Move& other) const {
		return
			std::tie(unit, pos, spell_id) <=>
			std::tie(other.unit, other.pos, other.spell_id);
	}

	bool operator==(const Move& other) const {
		return *this <=> other == 0;
	}

	godot::Array as_libspear_tuple() const {
		godot::Array ret;
		ret.push_back(unit);
		ret.push_back(godot::Vector2i(pos.x, pos.y));
		if(spell_id != NO_SPELL) {
			ret.push_back(spell_id);
		}
		return ret;
	}
};

template<>
struct std::hash<Move> {
	 std::size_t operator()(const Move& move) const {
		auto h1 = std::hash<unsigned>{}(move.unit);
		auto h2 = std::hash<unsigned>{}(move.pos.x);
		auto h3 = std::hash<unsigned>{}(move.pos.y);
		return h1 ^ (h2 << 1) ^ (h3 << 2);
	}
};

/// Reference to unit and its army - please use it only as a
/// temporary convenience value and only ever use it as a local variable.
/// Do not pass it to functions/objects - pass UnitIDs instead
struct UnitRef {
	Unit& unit;
	Army& army;
};


enum class TeamRelation {
	ME,
	ALLY,
	ENEMY,
	ANY
};


enum IncludeSelf : bool {
	INCLUDE_SELF = true,
	NO_INCLUDE_SELF = false
};


enum IncludeImpassable : bool {
	INCLUDE_IMPASSABLE = true,
	NO_INCLUDE_IMPASSABLE = false
};

#endif //BATTLE_STRUCTS_H
