Within map editor, there is split between Battle and World map. For each a different set of tiles is used.

Tiles are currently saved as set of 3 variables: String path to a texture, boolean if the texture should be horizontally flipped (not yet implemented) and String Type

# Tile Types
Basic types that won't have additional properties such as:

SENTINEL, EMPTY, WALL

are saved using SCREAMING_CASE

rest of the types are saved using snake_case, additional parameters are placed always after the type name and are separated by spaces.