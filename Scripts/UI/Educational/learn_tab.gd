extends Panel


@onready var general_learn_tabs_paired_with_scene = {
	CFG.LearnTabs.PRACTICE: $MainContainer/TopMenu/TabBarPractice,
	CFG.LearnTabs.BATTLE_WIKI: $MainContainer/TopMenu/TabBarBattleWiki,
	CFG.LearnTabs.WORLD_WIKI: $MainContainer/TopMenu/TabBarWorldWiki,
}

@onready var practice_tabs_paired_with_scene = {
	CFG.PracticeTabs.BASIC: $MainContainer/WikiIntroduction,
	CFG.PracticeTabs.TUTORIAL: $MainContainer/Tutorials,
	CFG.PracticeTabs.PUZZLE: $MainContainer/Puzzles,
	CFG.PracticeTabs.CAMPAIGN: $MainContainer/CampaignBattles,
}

@onready var battle_wiki_tabs_paired_with_scene = {
	CFG.BattleWiki.SYMBOLS_WIKI: $MainContainer/WikiSymbols,
	CFG.BattleWiki.MAGIC_WIKI: $MainContainer/WikiMagic,
	CFG.BattleWiki.TERRAIN: $MainContainer/WikiBattleTerrain,
	CFG.BattleWiki.MAGIC_CYCLONE: $MainContainer/WikiMagicCyclone,
}

@onready var world_wiki_tabs_paired_with_scene = {
	CFG.WorldWiki.FACTIONS: $MainContainer/WikiRaces,
	CFG.WorldWiki.ECONOMY: $MainContainer/WikiEconomy,
	CFG.WorldWiki.TERRAIN: $MainContainer/WikiWorldTerrain,
}


#region INIT

func _ready():
	_init_learn_tabs()

	## Failsafe between UI version changes
	var tab_bar_mode_selection : TabBar = $MainContainer/TopMenu/TabBarModeSelection
	var last_selected_tab : int = CFG.LAST_OPENED_LEARN_TAB
	if last_selected_tab > tab_bar_mode_selection.tab_count:
		last_selected_tab = 0

	tab_bar_mode_selection.current_tab = last_selected_tab
	_on_tab_bar_mode_selection_tab_changed(last_selected_tab)


func _init_learn_tabs() -> void:

	var edited_tab_bar : TabBar = general_learn_tabs_paired_with_scene[CFG.LearnTabs.PRACTICE]
	edited_tab_bar.clear_tabs()
	for tab in CFG.PracticeTabs.values():
		edited_tab_bar.add_tab(CFG.PRACTICE_TABS_NAMES[tab])

	edited_tab_bar = general_learn_tabs_paired_with_scene[CFG.LearnTabs.BATTLE_WIKI]
	edited_tab_bar.clear_tabs()
	for tab in CFG.BattleWiki.values():
		edited_tab_bar.add_tab(CFG.BATTLE_WIKI_TABS_NAMES[tab])

	edited_tab_bar  = general_learn_tabs_paired_with_scene[CFG.LearnTabs.WORLD_WIKI]
	edited_tab_bar.clear_tabs()
	for tab in CFG.WorldWiki.values():
		edited_tab_bar.add_tab(CFG.WORLD_WIKI_TABS_NAMES[tab])

#endregion INIT


func _clear_tabs():
	for child in $MainContainer.get_children():
		child.hide()
	$MainContainer/TopMenu.show()


func _on_tab_bar_mode_selection_tab_changed(tab_index):
	CFG.player_options.last_open_learn_tab = tab_index
	CFG.save_player_options()

	for tabbar in general_learn_tabs_paired_with_scene.values():
		tabbar.hide()
	general_learn_tabs_paired_with_scene[tab_index].show()

	match CFG.LearnTabs.values()[tab_index]:
		CFG.LearnTabs.PRACTICE:
			_on_tab_bar_practice_tab_changed(CFG.LAST_OPENED_PRACTICE_TAB)
		CFG.LearnTabs.BATTLE_WIKI:
			_on_tab_bar_battle_wiki_tab_changed(CFG.LAST_OPENED_BATTLE_WIKI_TAB)
		CFG.LearnTabs.WORLD_WIKI:
			_on_tab_bar_world_wiki_tab_changed(CFG.LAST_OPENED_WORLD_WIKI_TAB)


func _on_tab_bar_practice_tab_changed(tab_index):
	CFG.player_options.last_open_practice_tab = tab_index
	CFG.save_player_options()
	_clear_tabs()
	practice_tabs_paired_with_scene[tab_index].show()


func _on_tab_bar_battle_wiki_tab_changed(tab_index):
	CFG.player_options.last_open_battle_wiki_tab = tab_index
	CFG.save_player_options()
	_clear_tabs()
	battle_wiki_tabs_paired_with_scene[tab_index].show()


func _on_tab_bar_world_wiki_tab_changed(tab_index):
	CFG.player_options.last_open_world_wiki_tab = tab_index
	CFG.save_player_options()
	_clear_tabs()
	world_wiki_tabs_paired_with_scene[tab_index].show()
