Currently World AI is made to be weak enough that even on harder Battle AI difficulty player will still have a chance.
Once world gameplay will be finished there could be a possibility of big world refactor enabling implementation of smaller scale MCTS or other algorithms making world AI powerful.



Currently the goal to make playing against AI opponents "fun" is to provide them with various "unique" personalities, so that players may see varied gameplay on the world map.

# Current state
- AFK bot: good for running tests, just skips the turn

Random: a foundation for next bots, is seperated by independent systems:
Economy: just tries to purchase heroes, then any random building, then random units. But there is an algorithm present that randomly obtains build order that fills up max army size while spending as much goods as possible.

Travel: Selects random enemy which units strength is below or comparable to hero's army. And travel there. Current evaluation is really simplistic and doesn't scale with game progression. Selected target can be blocked by stronger opponent along the way leading to crushing defeat.