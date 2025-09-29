#ifndef FAST_BATTLE_MANAGER_H
#define FAST_BATTLE_MANAGER_H

#include "godot_cpp/classes/node.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include <cstdint>
#include <array>
#include <vector>

#include "data.hpp"
#include "battle_structs.hpp"
#include "cache_grid.hpp"
#include "tile_grid_fast.hpp"
#include "battle_spell.hpp"

// Assertions used (only in) BattleManagerFast

#define BM_ASSERT_V(cond, v, ...)													\
	do {																			\
		if(!(cond)) {																\
			_print_assert(std::format("BMFast assert failed: " __VA_ARGS__).c_str());\
			_set_error_flag(); return v;											\
		}																			\
	} while(0)

#define BM_ASSERT(cond, ...) BM_ASSERT_V(cond, , __VA_ARGS__)

#define CHECK_UNIT(idx, ret) BM_ASSERT_V(unsigned(idx) < MAX_UNITS_IN_ARMY, ret, "Invalid unit id {}", idx)
#define CHECK_ARMY(idx, ret) BM_ASSERT_V(unsigned(idx) < MAX_ARMIES, ret, "Invalid army id {}", idx)


using godot::Node;
using godot::Vector2i;

// Internal battle manager class, generally owned by eg. MCTS nodes
class BattleManagerFast {
	int8_t _current_army = -1;
	int8_t _previous_army = -1;
	int8_t _cyclone_target = -1;
	BattleState _state = BattleState::INITIALIZING;
	ArmyList _armies{};
	std::array<BattleSpell, MAX_SPELLS> _spells{};
	TileGridFast _tiles{};
	
	std::array<int8_t, 16> _cyclone_counter_values{-1};
	int8_t _mana_well_power = -1;

	BattleResult _result{};

	CacheGrid _unit_cache{};
	std::vector<Move> _moves{};
	std::vector<Move> _heuristic_moves{};
	bool _moves_dirty = true;
	bool _heuristic_moves_dirty = true;
	bool _debug_internals = false;


	void _process_unit(UnitID uid, MovePhase phase);
	void _process_bow(UnitID uid, MovePhase phase);
	void _process_push(UnitID pushed, UnitID pusher, Position direction, uint8_t max_power);
	void _process_spell(UnitID uid, int8_t spell_id, Position target);
	void _update_move_end();
	void _update_turn_end();
	void _check_blood_curse(int8_t army_id);

	void _spells_append_moves();

	void _append_moves_unit(UnitID uid, int8_t spell_id, TeamRelation relation, IncludeSelf include_self);
  void _append_curse_moves_unit(UnitID uid, int8_t spell_id, TeamRelation relation, IncludeSelf include_self, int8_t min_units);
	void _append_moves_all_tiles(UnitID uid, int8_t spell_id, IncludeImpassable include_impassable);

	void _append_moves_lines(UnitID uid, int8_t spell_id, Position center, int range_min, int range_max);
	void _append_moves_line(UnitID uid, int8_t spell_id, Position center, uint8_t dir, int range_min, int range_max);
	void _append_moves_neighbors(UnitID uid, int8_t spell_id, Position center, IncludeImpassable include_impassable);

	void _refresh_legal_moves();
	void _refresh_heuristically_good_moves();
	void _refresh_heuristically_good_deploy_moves();

	void _move_unit(UnitID id, Position pos);
	void _kill_unit(UnitID id, UnitID killer_id);
	void _summon_unit(Unit& unit, Army& army, Position target);

	void _next_army();

	void _update_mana();
	void _update_mana_target();
	std::pair<size_t, size_t> _get_cyclone_worst_and_best_idx() const;

	void _print_assert(const char* str);

	friend class BattleManagerFastCpp;

public:
	BattleManagerFast() = default;
	~BattleManagerFast() = default;

	void play_move(Move move);

	/// Get winner team, or -1 if the battle has not yet ended. On error returns -2.
	int get_winner_team();
	BattleResult& get_result() {return _result;}

	const std::vector<Move>& get_legal_moves();
	unsigned get_move_count();
	/// Get moves that are likely to increase score/win the game/avoid losses. If there are no notable moves, returns all moves
	const std::vector<Move>& get_heuristically_good_moves();
	/// Return a random move with a custom bias towards heuristically sensible moves, and whether such a move was chosen
	std::pair<Move, bool> get_random_move(float heuristic_probability);

	void finish_initialization();

	bool is_occupied(Position pos, const Army& army, TeamRelation relation) const;
	int get_army_team(int army) {
		return _armies[army].team;
	}

	bool skip_army(const Army& army, const Army& other_army, TeamRelation relation) const {
		switch(relation) {
			case TeamRelation::ME:
				return &army != &other_army;
			case TeamRelation::ALLY:
				return army.team != other_army.team;
			case TeamRelation::ENEMY:
				return army.team == other_army.team;
			case TeamRelation::ANY:
				return false;
		}
		return false;
	}

	int get_current_participant() const {
		return _current_army;
	}

	int get_previous_participant() const {
		return _previous_army;
	}

	bool is_battle_finished() const {
		return _state == BattleState::FINISHED;
	}


	void set_debug_internals(bool state) {
		_debug_internals = state;
	}


private:
	_FORCE_INLINE_ std::optional<UnitRef> _get_unit(UnitID id) {
		if(id == NO_UNIT) { // The only valid null value, any other hints at an error
			return {};
		}

		BM_ASSERT_V(unsigned(id.army) < _armies.size(), {}, "Invalid army id {}", id.army);
		BM_ASSERT_V(unsigned(id.unit) < _armies[id.army].units.size(), {}, "Invalid unit id {}/{}", id.army, id.unit);

		return UnitRef{_armies[id.army].units[id.unit], _armies[id.army]};
	}

	_FORCE_INLINE_ std::optional<UnitRef> _get_unit(Position coord) {
		return _get_unit(_unit_cache.get(coord));
	}

	/// Sets internal error flag, used for assert macros
	void _set_error_flag() {
		_result.error = true;
	}
};

/// Main GDScript-side wrapper class for BattleManagerFast
class BattleManagerFastCpp : public Node {
	GDCLASS(BattleManagerFastCpp, Node);

	BattleManagerFast bm;

protected:
	static void _bind_methods();

public:
	inline BattleManagerFast get_bm_copy() const {
		return bm;
	}

	int play_move(godot::Array libspear_tuple);
	int play_moves(godot::Array libspear_tuple_array);

	void insert_unit(int army, int idx, Vector2i pos, int rotation, bool is_deploying);
	void set_army_team(int army, int team);
	void set_unit_symbol(
		int army, int unit, int side,
		int attack_strength, int defense_strength, int ranged_reach,
		bool is_counter, int push_force, bool parries, bool breaks_parry,
		bool activate_on_leap, bool activate_on_turn
	);

	void set_unit_mana(int army, int idx, int mana);
	void set_unit_score(int army, int idx, int score);

	void set_unit_effect(int army, int idx, godot::String effect, int duration);
	void set_unit_martyr(int army, int idx, int martyr_id, int duration);
	void set_unit_solo_martyr(int army, int martyr_id, int duration);

	void insert_spell(int army, int unit, int spell_id, godot::String spell_name);
	void set_army_cyclone_timer(int army, int timer);
	void set_tile_grid(TileGridFastCpp* tilegrid);
	void set_current_participant(int army);
	void set_cyclone_constants(godot::PackedInt32Array cyclone_values, int mana_well_power);

	void finish_initialization() {
		bm.finish_initialization();
	}
	void force_battle_ongoing();
	void force_battle_sacrifice();

	/// Get legal moves in an array of arrays [[unit, position], ...]
	godot::Array get_legal_moves_gd();

	godot::Array get_unit_id_on_position(Vector2i pos) const;

	// Getters, primarily for testing correctness with regular BattleManager

	int get_current_participant() const {
		return bm.get_current_participant();
	}

	int get_previous_participant() const {
		return bm.get_previous_participant();
	}

	int count_spell(int army, int idx, godot::String name);
	int get_unit_spell_count(int army, int idx);

	Vector2i get_unit_position(int army, int unit) const {
		Position p = bm._armies[army].units[unit].pos; 
		return Vector2i(p.x, p.y);
	}

	int get_unit_rotation(int army, int unit) const {
		return bm._armies[army].units[unit].rotation;
	}

	int get_army_cyclone_timer(int army) const {
		return bm._armies[army].cyclone_timer;
	}

	int get_army_mana_points(int army) const {
		return bm._armies[army].mana_points;
	}

	int get_cyclone_target() const {
		return bm._cyclone_target;
	}

	bool is_unit_alive(int army, int unit) const {
		return bm._armies[army].units[unit].status == UnitStatus::ALIVE;
	}

	bool is_unit_being_deployed(int army, int unit) const {
		return bm._armies[army].units[unit].status == UnitStatus::DEPLOYING;
	}

	bool is_in_sacrifice_phase() const {
		return bm._state == BattleState::SACRIFICE;
	}

	bool is_in_deployment_phase() const {
		return bm._state == BattleState::DEPLOYMENT;
	}

	bool get_unit_effect(int army, int idx, godot::String str) const {
		return bm._armies[army].units[idx].is_effect_active(Unit::effect_string_to_flag(str));
	}

	int get_unit_effect_duration_counter(int army, int idx, godot::String str) const {
		return bm._armies[army].units[idx].get_effect_duration_counter(Unit::effect_string_to_flag(str));
	}

	int get_unit_effect_count(int army, int idx);

	int get_unit_martyr_id(int army, int idx) const {
		return bm._armies[army].units[idx].get_martyr_id().unit;
	}

	int get_unit_martyr_team(int army, int idx) const {
		return bm._armies[army].units[idx].get_martyr_id().army;
	}

	int get_max_units_in_army() const {
		return MAX_UNITS_IN_ARMY;
	}

	/// Sets internal error flag, used for assert macros
	void _set_error_flag() {
		bm._set_error_flag();
	}

	void set_debug_internals(bool state) {
		bm.set_debug_internals(state);
	}

	void _print_assert(const char* str) {
		bm._print_assert(str);
	}
};

#endif
