#ifndef ARMY_H
#define ARMY_H

#include <cstdint>

#include "arraymap.hpp"
#include "unit.hpp"
#include "battle_passive.hpp"

namespace libspear {

struct Army {
	static const int16_t CYCLONE_UNINITIALIZED = -1000;

	int8_t id = 0;
	int8_t team = -1;

	int8_t hero_id_opt = -1;
	int16_t mana_points = 0;
	int16_t cyclone_timer = CYCLONE_UNINITIALIZED;

	ArrayMap<BattlePassive, MAX_PASSIVES> passives{};

	ArrayMap<Unit, MAX_UNITS_IN_ARMY> units{};

	int find_unit_id_to_deploy(unsigned from = 0) const;
	int find_empty_unit_slot() const;

	constexpr bool is_defeated() const noexcept {
		return units.empty();
	}

	/// Counts number of alive and undeployed units
	int count_alive_units() const;

	constexpr operator bool() const noexcept {
		return not is_defeated();
	}
};

using ArmyList = ArrayMap<Army, MAX_ARMIES>;

}

#endif // ARMY_H
