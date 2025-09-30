#include "battle_mcts.hpp"

#include <cmath>
#include <cassert>
#include <limits>
#include <utility>
#include <algorithm>
#include <chrono>
#include <random>
#include <omp.h>


BattleMCTSNode::BattleMCTSNode(BattleManagerFast bm, BattleMCTSManager& manager, BattleMCTSNode* parent, Move move) 
	: _manager(manager),
	  _parent(parent),
	  _bm(bm),
	  _move(move)
{
	
}

float BattleMCTSNode::uct() const {
	const float coeff = sqrt(2);

	if(abs(_visits) < 1e-5f) {
		// not explored, a large number to force exploring it
		return 10000.0f;
	}
	float parent_visits = _parent ? _parent->_visits : _visits;
	return (_reward/_visits) + coeff * sqrt(log2(parent_visits) / _visits);
}

std::optional<std::pair<Move, BattleMCTSNode&>> BattleMCTSNode::select() {
	if(!is_explored()) {
		return {};
	}

	float uct_max = -std::numeric_limits<float>::infinity();
	BattleMCTSNode* uct_max_idx = nullptr;
	Move best_move{};

	for(auto& [move, node] : _children) {
		float uct = node->uct();
		if(uct >= uct_max) {
			uct_max = uct;
			// Safe as long as it doesn't outlive parent
			uct_max_idx = &(*node);
			best_move = move;
		}
	}

	if(uct_max_idx == nullptr) {
		return {};
	}

	return std::make_pair(best_move, std::ref(*uct_max_idx));
}

BattleMCTSNode& BattleMCTSNode::expand() {
	if(_bm.is_battle_finished()) {
		return *this;
	}

	auto [move, heur_chosen] = _bm.get_random_move(_manager.heuristic_probability);

	if(_children.count(move) == 0) {
		_children.emplace(move, std::make_shared<BattleMCTSNode>(_bm, _manager, this, move));
		BattleMCTSNode& child = *_children.at(move);
		child._bm.play_move(move);
		child._mcts_iterations = _mcts_iterations;

		if(heur_chosen) {
			float prior_reward = _mcts_iterations * float(_manager.heuristic_prior_reward_per_iteration);
			child._visits += prior_reward;
			child._reward += prior_reward;
		}
		return child;
	}
	return *this;
}

BattleResult _simulate_thread(BattleManagerFast bmnew, BattleMCTSManager& mcts, const BattleMCTSNode& node) {
	BattleResult* result;
	Move move;
	int i = 0;

	bool save_replay = false;
	std::vector<Move> replay;

	float heuristic_probability, max_sim_iterations;
	bool should_save_replays;

	heuristic_probability = mcts.heuristic_probability;
	max_sim_iterations = mcts.max_sim_iterations;
	should_save_replays = mcts.should_save_replays();

	do {
		move = bmnew.get_random_move(heuristic_probability).first;
		if(!save_replay && should_save_replays) {
			replay.push_back(move);
		}

		bmnew.play_move(move);
		result = &bmnew.get_result();
		if(result->error) {
			save_replay = true;
		}

	} while(result->winner_team == -1 && !result->error && i++ < max_sim_iterations);

	if(save_replay && should_save_replays) {
		mcts.add_error_playout(node, replay);
	}

	return *result;
}

BattleResult BattleMCTSNode::simulate(int max_sim_iterations, int simulations) {
	BattleResult ret;

	if(_bm.is_battle_finished()) {
		return _bm.get_result();
	}

	std::vector<BattleResult> results{size_t(simulations)};

	#pragma omp parallel for schedule(dynamic)
	for(int i = 0; i < simulations; i++) {
		results[i] = _simulate_thread(_bm, this->_manager, *this);
	}

	for(BattleResult& result : results) {
		for(unsigned i = 0; i < ret.total_scores.size(); i++) {
			ret.total_scores[i] += result.total_scores[i];
			ret.max_scores[i] += result.max_scores[i];
		}
	}

	return ret;
}

void BattleMCTSNode::backpropagate(BattleResult& result, int new_visits) {
	_visits += new_visits;

	if(_parent == nullptr) { // Root node does not need backpropagation
		return;
	}
	int current_team = _bm.get_army_team(_bm.get_previous_participant());
	float ally_score = 0.0f, enemy_score = 0.0f;
	float max_ally_score = 0.0f, max_enemy_score = 0.0f;

	for(unsigned i = 0; i < result.total_scores.size(); i++) {
		if(_bm.get_army_team(i) == current_team) {
			ally_score += result.total_scores[i];
			max_ally_score += result.max_scores[i];
		}
		else {
			enemy_score += result.total_scores[i];
			max_enemy_score += result.max_scores[i];
		}
	}

	float reward_add = (ally_score + max_enemy_score - enemy_score) / (max_ally_score+max_enemy_score); 
	// just in case
	if(reward_add < 0.0f || reward_add > 1.0f || std::isnan(reward_add) || std::isinf(reward_add)) {
		if(_manager.debug_bmfast_internals) {
			WARN_PRINT(std::format("invalid reward {} (ally:{}/{}, enemy:{}/{})", reward_add, ally_score, max_ally_score, enemy_score, max_enemy_score).c_str());
		}
		_reward += 0.5f * new_visits;
	}
	else {
		_reward += reward_add * new_visits;
	}

	_parent->backpropagate(result, new_visits);
}

bool BattleMCTSNode::is_explored() {
	return _bm.get_move_count() == _children.size();
}

void BattleMCTSManager::iterate(int iterations) {
	ERR_FAIL_COND_MSG(!_root.has_value(), "Root node not set in BattleMCTSManager");

	_root->_bm.set_debug_internals(debug_bmfast_internals);
	_root->_mcts_iterations = iterations;
	_root->iterate(iterations);
	call_deferred("emit_signal", "complete");
}

void BattleMCTSNode::iterate(int iterations) {

	int visits = _manager.max_playouts_per_visit;
	auto begin = std::chrono::high_resolution_clock::now();

	// Make sure the first level is explored to ensure every move will have at least one visit (select prioritizes nodes with 0 moves)
	while(!is_explored()) {
		expand();
	}

	for(int i = 0; i < iterations; i+=visits) {
		BattleMCTSNode* parent_node_ptr = this;

		while(true) {
			auto node_opt = parent_node_ptr->select(); 
			if(!node_opt.has_value()) {
				break;
			}

			parent_node_ptr = &node_opt.value().second;
		}

		BattleMCTSNode& node = parent_node_ptr->expand();
		BattleResult result = node.simulate(_manager.max_sim_iterations, visits);

		node.backpropagate(result, visits);

		if(result.winner_team == _manager._army_team) {
			this->_wins++;
		}
		else if(result.winner_team == -1) {
			this->_draws++;
		}
		else {
			this->_loses++;
		}
	}
	
	auto end = std::chrono::high_resolution_clock::now();
	std::chrono::duration<float> seconds = end - begin;
	printf("Iterate finished in %fs\n", seconds.count());
}

Move BattleMCTSManager::get_optimal_move(float reward_per_visit_dither) {
	ERR_FAIL_COND_V_MSG(!_root.has_value(), {}, "Root node not set in BattleMCTSManager");

	static thread_local std::random_device rand_dev;
	static thread_local std::mt19937 rand_engine{rand_dev()};
	std::uniform_real_distribution<float> dither_dist{0.0, reward_per_visit_dither};
	
	if(debug_print_move_lists) {
		print_move_list();
	}

	double max_ratio = -1.0;
	Move chosen{};

	for(auto& [move, node] : _root->_children) {
		double new_ratio = (node->_reward / node->_visits) + dither_dist(rand_engine);
		if(node->_visits < 1.0) {
			new_ratio = 0.0;
		}
		if(new_ratio > max_ratio) {
			chosen = move;
			max_ratio = new_ratio;
		}
	}

	return chosen;
}

godot::Array BattleMCTSManager::get_optimal_move_gd(float reward_per_visit_dither) {
	return get_optimal_move(reward_per_visit_dither).as_libspear_tuple();
}

godot::Dictionary BattleMCTSManager::get_move_scores() {
	ERR_FAIL_COND_V_MSG(!_root.has_value(), {}, "Root node not set in BattleMCTSManager");
	
	godot::Dictionary ret{};
	for(auto& [move, node] : _root->_children) {
		ret[move.as_libspear_tuple()] = node->_reward / node->_visits;
	}
	return ret;
}

void BattleMCTSManager::print_move_list() {
	ERR_FAIL_COND_MSG(!_root.has_value(), "Root node not set in BattleMCTSManager");

	for(auto& [move, node] : _root->_children) {
		auto& hmoves = _root->_bm.get_heuristically_good_moves();
		bool is_heur_move = std::find(hmoves.begin(), hmoves.end(), move) != hmoves.end();

		printf("Child %c %d->%d,%d UCT=%f, R/V=%f (reward: %f, visits: %f)\n", 
				is_heur_move ? 'H':' ', move.unit, move.pos.x, move.pos.y, 
				node->uct(), node->_reward / node->_visits, node->_reward, node->_visits
		);
	}
	printf("%i/%i/%i\n", _root->_wins, _root->_draws, _root->_loses);
}

void BattleMCTSManager::add_error_playout(const BattleMCTSNode& node_arg, std::vector<Move> extra_moves) {
	godot::Array replay;
	const BattleMCTSNode* node = &node_arg;

	if(!should_save_replays()) {
		return;
	}

	while(node->_parent) {
		replay.push_back(node->_move.as_libspear_tuple());
		node = node->_parent;
	}

	replay.reverse();
	
	for(Move i : extra_moves) {
		replay.push_back(i.as_libspear_tuple());
	}

	_error_playouts.push_back(replay);
}

godot::Array BattleMCTSManager::get_error_replays() {
	return _error_playouts;
}

void BattleMCTSManager::set_root(BattleManagerFastCpp* bmwrapper) {
	ERR_FAIL_COND_MSG(bmwrapper == nullptr, "Provided BattleManagerFastCpp is null");
	BattleManagerFast bm = bmwrapper->get_bm_copy();

	_root.emplace(bm, *this, nullptr, Move());
	_army_id = bm.get_current_participant();
	_army_team = bm.get_army_team(_army_id);
}

void BattleMCTSManager::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_optimal_move", "reward_per_visit_dither"), &BattleMCTSManager::get_optimal_move_gd);
	ClassDB::bind_method(D_METHOD("iterate", "iterations"), &BattleMCTSManager::iterate);
	ClassDB::bind_method(D_METHOD("set_root", "battle_manager"), &BattleMCTSManager::set_root);
	ClassDB::bind_method(D_METHOD("get_error_replays"), &BattleMCTSManager::get_error_replays);
	ClassDB::bind_method(D_METHOD("get_move_scores"), &BattleMCTSManager::get_move_scores);

	ADD_SIGNAL(MethodInfo("complete"));

	BIND_MCTS_PARAMETER(Variant::INT, max_sim_iterations);
	BIND_MCTS_PARAMETER(Variant::FLOAT, heuristic_probability);
	BIND_MCTS_PARAMETER(Variant::FLOAT, heuristic_prior_reward_per_iteration);
	BIND_MCTS_PARAMETER(Variant::INT, max_playouts_per_visit);
	BIND_MCTS_PARAMETER(Variant::BOOL, debug_bmfast_internals);
	BIND_MCTS_PARAMETER(Variant::BOOL, debug_print_move_lists);
	BIND_MCTS_PARAMETER(Variant::INT, debug_max_saved_fail_replays);
}

