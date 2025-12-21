#ifndef DATA_H
#define DATA_H

#include <cstdint>
#include <cstdio>
#include <array>

#include "godot_cpp/variant/vector2i.hpp"
#include "godot_cpp/variant/string.hpp"

namespace libspear {

enum class UnitStatus : uint8_t {
	DEPLOYING,
	ALIVE,
	DEAD
};

enum class BattleState : uint8_t {
	INITIALIZING,
	DEPLOYMENT,
	ONGOING,
	SACRIFICE,
	FINISHED
};

enum class MovePhase : uint8_t {
	TURN,
	LEAP,
	PASSIVE,
	DASH,
};

struct Position {
	int8_t x{};
	int8_t y{};

	constexpr Position() = default;
	constexpr Position(int8_t x, int8_t y) noexcept : x(x), y(y) {};
	Position(godot::Vector2i p) : x(p.x), y(p.y) {};

	constexpr Position operator+(const Position& other) const {
		return Position(x + other.x, y + other.y);
	}

	constexpr Position& operator+=(const Position& other) {
		x += other.x;
		y += other.y;
		return *this;
	}

	constexpr Position operator-(const Position& other) const {
		return Position(x - other.x, y - other.y);
	}

	constexpr Position& operator-=(const Position& other) {
		x -= other.x;
		y -= other.y;
		return *this;
	}

	constexpr Position operator*(const int mult) const {
		return Position(x * mult, y * mult);
	}

	constexpr std::strong_ordering
	operator<=>(const Position& other) const = default;

	constexpr bool is_in_line_with(Position other) const {
		Position delta = *this - other;
		return delta.x == -delta.y || delta.x == 0 || delta.y == 0;
	}

	constexpr int axial_distance(const Position& other) const {
		return (abs(x - other.x)
			+ abs(x + y - other.x - other.y)
			+ abs(y - other.y)) / 2;
	}
};

class Symbol {
	uint8_t _attack_strength = 0;
	uint8_t _defense_strength = 0;
	uint8_t _push_strength = 0;
	uint8_t _ranged_reach = 0;
	uint8_t _flags = 0;

public:
	static const uint8_t FLAG_COUNTER_ATTACK = 0x01;
	static const uint8_t FLAG_PARRY = 0x02;
	static const uint8_t FLAG_PARRY_BREAK = 0x04;
	static const uint8_t FLAG_ACTIVATE_ON_LEAP = 0x08; // |
	static const uint8_t FLAG_ACTIVATE_ON_TURN = 0x10; // | only for ranged weapons

	static const int MIN_SHIELD_DEFENSE = 2;

	constexpr Symbol() = default;
	constexpr Symbol(uint8_t attack_strength, uint8_t defense_strength, uint8_t push_force, uint8_t ranged_reach, uint8_t flags) noexcept
		: _attack_strength(attack_strength),
		_defense_strength(defense_strength),
		_push_strength(push_force),
		_ranged_reach(ranged_reach),
		_flags(flags)
	{

	}

	constexpr int get_attack_force() const noexcept {
		return _attack_strength;
	}

	constexpr int get_counter_force() const noexcept {
		return (_flags & FLAG_COUNTER_ATTACK) ? _attack_strength : 0;
	}

	constexpr int get_defense_force() const noexcept {
		return _defense_strength;
	}

	constexpr bool does_bow_activate_on(MovePhase phase) const noexcept {
		return phase == MovePhase::DASH // Should never occur naturally, special value for convenience
			|| (phase == MovePhase::LEAP && (_flags & FLAG_ACTIVATE_ON_LEAP))
			|| (phase == MovePhase::TURN && (_flags & FLAG_ACTIVATE_ON_TURN));
	}

	constexpr int get_bow_force(MovePhase phase) const noexcept {
		return (_ranged_reach > 1 && does_bow_activate_on(phase)) ? _attack_strength : 0;
	}

	constexpr int get_reach() const noexcept {
		return _ranged_reach;
	}

	constexpr int get_push_force() const noexcept {
		return _push_strength;
	}

	constexpr bool protects_against(Symbol other, MovePhase phase) const noexcept {
		// Parry disables melee attacks
		if(other.get_bow_force(phase) <= 0 && (parries() && !other.breaks_parry())) {
			return true;
		}

		int other_force = (phase == MovePhase::PASSIVE) ? other.get_counter_force() : other.get_attack_force();
		return other_force <= get_defense_force();
	}

	constexpr bool holds_ground_against(Symbol other) const noexcept {
		bool parry_succesful = parries() && !other.breaks_parry();
		bool push_succesful = other.get_push_force() > 0 && !parry_succesful;
		return protects_against(other, MovePhase::TURN) && !push_succesful;
	}

	constexpr bool dies_to(Symbol other, MovePhase phase) const noexcept {
		return !protects_against(other, phase);
	}

	constexpr bool parries() const noexcept {
		return (_flags & FLAG_PARRY);
	}

	constexpr bool breaks_parry() const noexcept {
		return (_flags & FLAG_PARRY_BREAK);
	}

	void print() const {
		printf("a%dc%dd%d", get_attack_force(), get_counter_force(), get_defense_force());
	}
};

class Tile {
	static const uint16_t PASSABLE = 0x1;
	static const uint16_t WALL = 0x2;
	static const uint16_t SWAMP = 0x4;
	static const uint16_t FORBIDDEN = 0x8;
	static const uint16_t MANA_WELL = 0x10;
	static const uint16_t PIT = 0x20;
	static const uint16_t HILL = 0x40;
	static const uint16_t SPAWN = 0x80;
	static const uint16_t FIRE = 0x100;

	uint16_t _flags = FORBIDDEN | WALL;
	int8_t _army = -1; // Spawning army for spawning tiles, controlling army for mana wells
	uint8_t _spawning_direction{};

public:
	constexpr Tile() = default;
	constexpr Tile(bool passable, bool wall, bool swamp, bool mana_well, bool pit, bool hill, bool fire, int army, unsigned direction) noexcept :
		_flags(
			(passable ? PASSABLE : 0)
		  | (wall ? WALL : 0)
		  | (swamp ? SWAMP : 0)
		  | (mana_well ? MANA_WELL : 0)
		  | (pit ? PIT : 0)
		  | (hill ? HILL : 0)
		  | (fire ? FIRE : 0)
		  | ((!mana_well && army >= 0) ? SPAWN : 0)
		),
		_army(army),
		_spawning_direction(direction)
	{}

	constexpr bool is_passable() const noexcept {
		return (_flags & PASSABLE) != 0;
	}

	constexpr bool is_wall() const noexcept {
		return (_flags & WALL) != 0;
	}

	constexpr bool is_swamp() const noexcept {
		return (_flags & SWAMP) != 0;
	}

	constexpr bool is_mana_well() const noexcept {
		return (_flags & MANA_WELL) != 0;
	}

	constexpr bool is_hill() const noexcept {
		return (_flags & HILL) != 0;
	}

	constexpr bool is_pit() const noexcept {
		return (_flags & PIT) != 0;
	}

	constexpr bool is_fire() const noexcept {
		return (_flags & FIRE) != 0;
	}

	constexpr bool is_spawn() const noexcept {
		return (_flags & SPAWN) != 0;
	}

	constexpr int get_spawning_army() const noexcept {
		return is_spawn() ? _army : -1;
	}

	constexpr int get_controlling_army() const noexcept {
		return is_mana_well() ? _army : -1;
	}

	void set_controlling_army(int army_id) {
		ERR_FAIL_COND_MSG(!is_mana_well(), "Only mana well tiles can be controlled as an army");
		_army = army_id;
	}

	constexpr unsigned get_spawn_rotation() const noexcept {
		return _spawning_direction;
	}
};

constexpr inline std::array<Position, 6> DIRECTIONS = {
	Position(-1, 0),
	Position(0, -1),
	Position(1, -1),
	Position(1, 0),
	Position(0, 1),
	Position(-1, 1),  // non-axes - -1,-1; 1,1
};


constexpr inline int get_rotation(Position origin, Position relative) noexcept {
	Position pos = relative - origin;
	for(int i = 0; i < 6; i++) {
		if(DIRECTIONS[i] == pos) {
			return i;
		}
	}
	return 6;
}

constexpr inline int flip(int rot) noexcept {
	return (rot + 3) % 6;
}

constexpr _FORCE_INLINE_ int clamp(int val, int min, int max) noexcept {
	if(val < min) {
		return min;
	}
	else if(val > max) {
		return max;
	}
	return val;
}

}

#endif
