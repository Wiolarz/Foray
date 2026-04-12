#include "army.hpp"

namespace libspear {

int Army::find_unit_id_to_deploy(unsigned i) const {
	for(; i < MAX_UNITS_IN_ARMY; i++) {
		if(units[i].status == UnitStatus::DEPLOYING) {
			return i;
		}
	}
	return -1;
}


int Army::find_empty_unit_slot() const {
	const std::size_t index = units.find_first_empty().first;
	if (index < units.max_size())
		return index;
	return -1;
}


int Army::count_alive_units() const {
	return std::ranges::count_if(
		units,
		[](const Unit& unit) { return unit.status == UnitStatus::ALIVE; });
}

}
