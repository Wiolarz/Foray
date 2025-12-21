#ifndef BATTLE_PASSIVE_H
#define BATTLE_PASSIVE_H

#include <format>
#include "godot_cpp/variant/string.hpp"

namespace libspear {

struct BattlePassive {
	enum class Type : uint8_t {
		NONE,
		SENTINEL, // No spells after that in the spell list

        MAGIC_WEAPONS,
        WEAK_WEAPONS,
        WIND_WEAPONS,
        SECOND_WIND,
        BALLISTA_SUMMON, // Requires no logic in LibSpear, only for bookkeeping
	} type = Type::SENTINEL;

	constexpr BattlePassive() = default;
	BattlePassive(godot::String string) {
		if(string == godot::String("ballista_summon")) {
			type = Type::BALLISTA_SUMMON;
		}
		else if(string == godot::String("magic_weapons")) {
			type = Type::MAGIC_WEAPONS;
		}
		else if(string == godot::String("weak_weapons")) {
			type = Type::WEAK_WEAPONS;
		}
		else if(string == godot::String("wind_weapons")) {
			type = Type::WIND_WEAPONS;
		}
		else if(string == godot::String("second_wind")) {
			type = Type::SECOND_WIND;
		}
		/// Add new spell-string mappings right before this line
		else {
			ERR_FAIL_MSG(std::format("Unknown passive: '{}'", string.ascii().get_data()).c_str());
		}
	}

	constexpr operator bool() const noexcept {
		using enum Type;
		return type != NONE and type != SENTINEL;
	}
};

}

#endif // BATTLE_PASSIVE_H
