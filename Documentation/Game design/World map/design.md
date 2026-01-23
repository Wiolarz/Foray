# Design

# Army

Player has a list of armies, but not all of them have to contain a hero.
Those armies are garrisons in towns and they cannot move on their own.

Only armies containing hero can move -> are displayed in "heroes" tab at the bottom of the screen.

Battle still take place between Army class objects where hero is only another unit
While to determine if the selected army can be moved we use -> does army contain a hero?



## Heroes
As army leader they have limited maximum army size. When recruiting units at the city over the army limit, they will be placed inside a garrsion.

In a battle hero take place he gets added to the unit roster,
but if hero were to fall in a battle instead of being removed he becomes "wounded" and returns to health once he visits a friendly city.

Player is limited to a max of 3 heroes in a game (each of a different class)

### CITY
During a city defense a present hero Army can be supported by additional present garrison troops equal to the city defense level.

### Another Ally Hero
when we selecet a hero then press on another one, instead of swapping we begin the trade





# UI

show list of cities and heroes at the bottom for quick selection option


# Code 

## TODO

Add resources
add combat
add city interface


## think about


World Manager
next_player_turn()
Decide if the players array will store removed players or not.
In case we were to add "leaderboard" variable there will be a need to extend this function
