# Foray Technical Documentation

Design documentation: [[Game design/readme]]

## Foreword
Code is split into two languages:
GDScript -> almost everything, whole documentation is centered around except for:
C++ -> AI for computer opponents in the battle game mode, restricted to res://LibSpear/ with its GDScript interface present in: res://Scripts/AI/MCTS/
Technical documentation for C++ currently consist only of: [[libspear]] with additional information in [[Additional AI notes]]


# List of files to start:

[Ubiquitous Language](language.md) - Dictionary, a reference point if you are confused about any description.


- [Code Structure and basic game flow](Code%20Structure.md)
- [Coding guidelines](coding_guidelines.md)

## Main Categories
- How Hex Grid is handled: [Introduction](<Grid/Implementation.md>)   [Technical](<Grid/Technical.md>) 
- Netcode: Introduction: [[multiplayer_doc]]  Technical: [[Network]]
- AI: [Battle AI](AI%20Interface.md)  and  [World AI](Foundation.md)  They are completely separate.
- Visuals: [[Graphics/Technical]] [[animations]]
- UI: [[General UI architecture]]
- Testing: [[Testing Documentation]]
- Content creation "Editors": [[Map Editor]]
# General Project tips
### Location of Replays Folder
example: C:\\Users\\user_name\\AppData\\Roaming\\Godot\\app_userdata\\Krong
in editor simply click: “Project → Open User Data Folder”

## Foray key bindings

- `KEYS WSAD or Arrows` = camera movement

- `middle mouse button + drag` = drag camera

- `KEY_GO_BACK` = ESC (UI navigation shortcut)

- `KEY_MAXIMIZE_WINDOW` = F2

Debug

- `KEY_BOT_SPEED_SLOW` = 3 (number key)

- `KEY_BOT_SPEED_MEDIUM` = 2

- `KEY_BOT_SPEED_FAST` = 1

- `KEY_DEBUG_COLLISION_SHAPES` = F4

Other

- `KEY_EXIT_GAME` = F1

- `KEY_MENU` = ~


# Obsidian tips

As the entirety of the documentation is written in Markdown, we recommend to read it using Obsidian software.
Simply open this "Documentation" folder using "Open Vault" option.

You can enable zoom with `Ctrl + mouse wheel` in Options / Appearance / Fonts -> Quick Font Adjustment

To enable text filling full screen width you have to disable -> Options / Editor / Display -> Readable Line Length
