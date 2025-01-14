# Is move legal

### All possible current scenarios

index  scenario name - TRUE/FALSE
If a scenario should return true, this means that in such case a unit should be able to move toward that tile.
Types of scenarios listed:
empty/enemy - if enemy unit is present at that tile
enemy unremovable/killable - state if a move toward a tile with enemy present will result in this enemy being removed from that tile

hill/pit - type of special movement tile
good/bad angle - if a unit that wants to move is turned toward that tile before attempting a move there (good - is facing that tile)
landing spot free/occupied - if a tile directly "behind" a pit from the direction of the unit is occupied by a unit or not.

1 empty tile - TRUE  
2 enemy removable - TRUE  
3 enemy unremovable - FALSE  
4 hill bad angle - FALSE  
5 hill good angle empty - TRUE  
6 hill good angle enemy removable - TRUE  
7 hill good angle enemy unremovable - FALSE  
8 pit good angle landing spot free - TRUE  
9 pit good angle landing spot occupied - FALSE  
10 pit bad angle - FALSE

 Types of scenarios we hope to prevent using User Interface only:
 1 ally - FALSE
 You cannot move to a tile where an ally is present, UI should prevent it as selecting a tile with ally present attempts to select that unit instead of trying to move there.
 