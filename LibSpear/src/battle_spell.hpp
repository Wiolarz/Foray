#ifndef BATTLE_SPELL_H
#define BATTLE_SPELL_H

#include <format>
#include "godot_cpp/variant/string.hpp"

#include "unit.hpp"

namespace libspear {

struct BattleSpell {
	/// Spell's state - currently only represents type, but in the future might represent more complex spells as state machines
	enum class State : uint8_t {
		NONE,
		SENTINEL, // No spells after that in the spell list

		// Uncast spells
		TELEPORT,
		FIREBALL,
		MARTYR,
		VENGEANCE,
		BLOOD_CURSE,
		WIND_DASH,
		ANCHOR,
		SUMMON_DRYAD,
		FIRE_WALL,
		SACRIFICE,
	} state = State::SENTINEL;
	UnitID unit = NO_UNIT; // An owner for uncast spells

	constexpr BattleSpell() = default;
	constexpr operator bool() const noexcept {
		using enum State;
		return state != NONE and state != SENTINEL;
	}
	BattleSpell(godot::String string, UnitID _unit) {
		if(string == godot::String("Teleport")) {
			state = State::TELEPORT;
		}
		else if(string == godot::String("Fireball")) {
			state = State::FIREBALL;
		}
		else if(string == godot::String("Martyr")) {
			state = State::MARTYR;
		}
		else if(string == godot::String("Vengeance")) {
			state = State::VENGEANCE;
		}
		else if(string == godot::String("Blood Ritual")) {
			state = State::BLOOD_CURSE;
		}
		else if(string == godot::String("Wind Dash")) {
			state = State::WIND_DASH;
		}
		else if(string == godot::String("Anchor")) {
			state = State::ANCHOR;
		}
		else if(string == godot::String("Summon Dryad")) {
			state = State::SUMMON_DRYAD;
		}
		else if(string == godot::String("Fire Wall")) {
			state = State::FIRE_WALL;
		}
		else if(string == godot::String("Sacrifice")) {
			state = State::SACRIFICE;
		}
		/// Add new spell-string mappings right before this line
		else {
			ERR_FAIL_MSG(std::format("Unknown spell: '{}'", string.ascii().get_data()).c_str());
		}

		unit = _unit;
	}
};

}

#endif
