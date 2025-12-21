#include "unit.hpp"

#include <format>

namespace libspear {

Symbol Unit::symbol_when_rotated(int side) const {
    if(flags & FLAG_ON_SWAMP) {
        return Symbol();
    }
    return sides[(6-rotation + side) % 6];
}

Symbol Unit::front_symbol() const {
    if(flags & FLAG_ON_SWAMP) {
        return Symbol();
    }
    return sides[0];
}

bool Unit::try_apply_effect(EffectMask mask, int8_t duration) {
	const auto it = effects.try_push_anywhere(Effect {
		.mask = mask,
		.counter = duration,
	});
	return it != effects.end();
}

bool Unit::try_apply_martyr(UnitID id, int8_t duration) {
    _martyr_id = id;
    return try_apply_effect(FLAG_EFFECT_MARTYR, duration);
}

void Unit::remove_martyr() {
    _martyr_id = NO_UNIT;
    remove_effects(FLAG_EFFECT_MARTYR);
}

void Unit::remove_effects(EffectMask mask) {
    flags &= ~mask;
    for(auto& eff : effects) {
        eff.mask &= ~mask;
    }
}

UnitID Unit::get_martyr_id() const {
    return _martyr_id;
}

bool Unit::is_effect_active(EffectMask effect_mask) const {
    return (flags & effect_mask);
}

void Unit::on_turn_end() {
    for(Effect& eff : effects.all()) {
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
            remove_effects(eff.mask);
        }
    }
}



EffectMask Unit::effect_string_to_flag(godot::String str) {
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
    else if(str == godot::String("Burning")) {
        return FLAG_EFFECT_BURNING;
    }
    /// Add new effect-string mappings before this line
    else {
        ERR_FAIL_V_MSG(0, std::format("Unknown effect: '{}'", str.ascii().get_data()).c_str());
    }
}

/// Convert Godot effects (except Martyr) to LibSpear flags
void Unit::set_effect_gd(godot::String str, int duration) {
    if(!try_apply_effect(effect_string_to_flag(str), duration)) {
        ERR_FAIL_MSG(std::format("Failed to apply effect: '{}'", str.ascii().get_data()).c_str());
    }
}

int Unit::get_effect_duration_counter(EffectMask mask) const {
    for(const Effect& eff : effects) {
        if(eff.mask & mask) {
            return eff.counter;
        }
    }
    return -1;
}

}
