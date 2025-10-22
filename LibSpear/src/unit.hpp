#ifndef UNIT_H
#define UNIT_H

#include <cstdint>
#include <array>

#include "data.hpp"
#include "constants.hpp"


using EffectMask = uint16_t;

struct Effect {
    // A mask of just a single effect
	EffectMask mask = 0;
	int8_t counter = 0;
};

static const Effect NO_EFFECT = Effect{.mask = 0, .counter = 0};


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


struct Unit {
	UnitStatus status = UnitStatus::DEAD;
	Position pos{};
	uint8_t rotation{};
	uint8_t score = 1;
	uint8_t mana = 0;
	uint16_t flags = 0;
	std::array<Symbol, 6> sides{};
	std::array<Effect, MAX_EFFECTS_PER_UNIT> effects{};

private:
	UnitID _martyr_id = NO_UNIT;
public:
    /// If effect duration is -1, then it doesn't expire
	static const int8_t EFFECT_INFINITE = -1;

	static const EffectMask FLAG_ON_SWAMP = 0x01;
	static const EffectMask FLAG_EFFECT_VENGEANCE = 0x02;
	static const EffectMask FLAG_EFFECT_DEATH_MARK = 0x04;
	static const EffectMask FLAG_EFFECT_MARTYR = 0x08;
	static const EffectMask FLAG_EFFECT_BLOOD_CURSE = 0x10;
	static const EffectMask FLAG_EFFECT_ANCHOR = 0x20;
	static const EffectMask FLAG_EFFECT_SUMMONING_SICKNESS = 0x40;
	static const EffectMask FLAG_HERO = 0x80;
	static const EffectMask FLAG_EFFECT_BURNING = 0x100;
	/// Add new effect types/flags before this line

    Symbol symbol_when_rotated(int side) const;
    Symbol front_symbol() const;

    bool try_apply_effect(EffectMask mask, uint8_t duration = DEFAULT_EFFECT_DURATION);
    bool try_apply_martyr(UnitID id, uint8_t duration = DEFAULT_EFFECT_DURATION);
    void remove_martyr();
    void remove_effect(EffectMask mask);

    UnitID get_martyr_id() const;
    bool is_effect_active(EffectMask effect_mask) const;

    void on_turn_end();

    static EffectMask effect_string_to_flag(godot::String str);
    void set_effect_gd(godot::String str, int duration);
    int get_effect_duration_counter(EffectMask mask) const;
};


#endif // UNIT_H
