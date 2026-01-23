Creating strong battle AI that can crush most players isn't a problem thanks to the MCTS [[libspear]].
Goal is to weaken it in a human-like way, while additionally creating unique playstyles for each faction.


# Current State

Currently there are only two types of AI:
Random: makes a kill move if possible, otherwise moves randomly, good for quick tests.
Pure MCTS: While Easy and Medium difficulty are manageable by human players, hard and insane are simply too strong.
Additionally, easy and medium don't really play overall bad, but mostly just loose duo to an extreme mistake, so against a new players they are still a menace.


# AI interface

All AI implementation are called through an `AIInterface`, a simple parent class providing shared function `choose_move(battle_state : BattleGridState) -> MoveInfo`which provides AI with current game state and expects a legal move.
