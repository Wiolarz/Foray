#ifndef BATTLE_STRUCTS_H
#define BATTLE_STRUCTS_H

#include <cstdint>
#include <array>
#include <format>
#include "godot_cpp/variant/array.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include "godot_cpp/variant/variant.hpp"
#include "godot_cpp/core/error_macros.hpp"

#include "data.hpp"

const unsigned MAX_ARMIES = 4;
const unsigned MAX_UNITS_IN_ARMY = 12;
const unsigned MAX_EFFECTS_PER_UNIT = 2;
const unsigned MAX_TILES_IN_GRID = 256;
const unsigned DEFAULT_EFFECT_DURATION = 6;

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


struct UnitID {
	int8_t army;
	int8_t unit;

	UnitID() : army(-1), unit(-1) {}
	UnitID(int8_t _army, int8_t _unit) : army(_army), unit(_unit) {}
	inline bool operator==(const UnitID& other) const {
		return army == other.army && unit == other.unit;
	}
};

static const UnitID NO_UNIT = UnitID(-1,-1);
static UnitID _err_return_dummy_uid = UnitID(-1,-1);

using EffectMask = uint8_t;

struct Effect {
	EffectMask mask = 0;
	int8_t counter = 0;
};

static const Effect NO_EFFECT = Effect{.mask = 0, .counter = 0};

struct Unit {
	UnitStatus status = UnitStatus::DEAD;
	Position pos{};
	uint8_t rotation{};
	uint8_t score = 1;
	uint8_t mana = 0;
	uint8_t flags = 0;
	std::array<Symbol, 6> sides{};
	std::array<Effect, MAX_EFFECTS_PER_UNIT> effects{};

private:
	UnitID _martyr_id = NO_UNIT;
public:
	static const int8_t EFFECT_INFINITE = -1;

	static const EffectMask FLAG_ON_SWAMP = 0x01;
	static const EffectMask FLAG_EFFECT_VENGEANCE = 0x02;
	static const EffectMask FLAG_EFFECT_DEATH_MARK = 0x04;
	static const EffectMask FLAG_EFFECT_MARTYR = 0x08;
	static const EffectMask FLAG_EFFECT_BLOOD_CURSE = 0x10;
	static const EffectMask FLAG_EFFECT_ANCHOR = 0x20;
	static const EffectMask FLAG_EFFECT_SUMMONING_SICKNESS = 0x40;
	/// Add new effect types/flags before this line

	Symbol symbol_when_rotated(int side) const {
		if(flags & FLAG_ON_SWAMP) {
			return Symbol();
		}
		return sides[(6-rotation + side) % 6];
	}

	Symbol front_symbol() const {
		if(flags & FLAG_ON_SWAMP) {
			return Symbol();
		}
		return sides[0];
	}

	bool try_apply_effect(EffectMask mask, uint8_t duration = DEFAULT_EFFECT_DURATION) {
		for(Effect& eff : effects) {
			if(eff.mask == 0) {
				flags |= mask;
				eff.mask = mask;
				eff.counter = duration;
				return true;
			}
		}
		return false;
	}

	bool try_apply_martyr(UnitID id, uint8_t duration = DEFAULT_EFFECT_DURATION) {
		_martyr_id = id;
		return try_apply_effect(FLAG_EFFECT_MARTYR, duration);
	}

	void remove_martyr() {
		_martyr_id = NO_UNIT;
		remove_effect(FLAG_EFFECT_MARTYR);
	}

	void remove_effect(EffectMask mask) {
		flags &= ~mask;
		for(auto& eff : effects) {
			eff.mask &= ~mask;
		}
	}

	UnitID get_martyr_id() const {
		return _martyr_id;
	}

	bool is_effect_active(EffectMask effect_mask) const {
		return (flags & effect_mask);
	}

	void on_turn_end() {
		for(Effect& eff : effects) {
			if(eff.counter == 0 || eff.mask == 0) {
				continue;
			}

			if(eff.counter > 0) {
				eff.counter--;
			}

			if(eff.counter == 0) {
				if(eff.mask & FLAG_EFFECT_MARTYR) {
					_martyr_id = NO_UNIT;
				}
				flags &= ~eff.mask;
				eff.mask = 0;
			}
		}
	}

	static EffectMask effect_string_to_flag(godot::String str) {
		if(str == godot::String("Vengeance")) {
			return FLAG_EFFECT_VENGEANCE;
		}
		else if(str == godot::String("Death Mark")) {
			return FLAG_EFFECT_DEATH_MARK;
		}
		else if(str == godot::String("Martyr")) {
			return FLAG_EFFECT_MARTYR;
		}
		else if(str == godot::String("Blood Ritual")) {
			return FLAG_EFFECT_BLOOD_CURSE;
		}
		else if(str == godot::String("Anchor")) {
			return FLAG_EFFECT_ANCHOR;
		}
		else if(str == godot::String("Summoning Sickness")) {
			return FLAG_EFFECT_SUMMONING_SICKNESS;
		}
		/// Add new effect-string mappings before this line
		else {
			ERR_FAIL_V_MSG(0, std::format("Unknown effect: '{}'", str.ascii().get_data()).c_str());
		}
	}

	/// Convert Godot effects (except Martyr) to LibSpear flags
	void set_effect_gd(godot::String str, int duration) {
		if(!try_apply_effect(effect_string_to_flag(str), duration)) {
			ERR_FAIL_MSG(std::format("Failed to apply effect: '{}'", str.ascii().get_data()).c_str());
		}
	}

	int get_effect_duration_counter(EffectMask mask) const {
		for(const Effect& eff : effects) {
			if(eff.mask & mask) {
				return eff.counter;
			}
		}
		return -1;
	}
};

struct Army {
	static const int16_t CYCLONE_UNINITIALIZED = -1000;

	int8_t id = 0;
	int8_t team = -1;

	int16_t mana_points = 0;
	int16_t cyclone_timer = CYCLONE_UNINITIALIZED;

	std::array<Unit, MAX_UNITS_IN_ARMY> units{};


	int find_unit_id_to_deploy(unsigned from = 0) const;
	int find_empty_unit_slot() const;
	bool is_defeated() const;

	/// Counts number of alive and undeployed units
	int count_alive_units() const {
		int result = 0;
		for (const Unit& unit : units) {
			if (unit.status == UnitStatus::DEPLOYING || unit.status == UnitStatus::ALIVE) {
				result++;
			}
		}
		return result;
	}
};

using ArmyList = std::array<Army, MAX_ARMIES>;

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
