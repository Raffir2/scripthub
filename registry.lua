-- Game registry for the launcher (loader.lua).
-- Detection: game.GameId (universe, covers every sub-place) first, then game.PlaceId.
--
-- Script source, one of:
--   url  = full raw URL (scripts that live in their own repo, always newest)
--   path = file in THIS repo (mirrored copies, refresh with tools/sync.sh)
-- Flags:
--   default = picked for auto-load when the user has no remembered choice
--   quiet   = (game) launcher writes nothing to the console here (Adonis log scanner)
--   nocache = always fetch, never fall back to a cached copy

return {
	version = "1.0.0",
	games = {
		{
			id = "spellbound",
			name = "Spellbound",
			universe = { 3822976934 },
			places = { 10506677779 },
			scripts = {
				{ id = "gui", name = "Spellbound GUI", default = true,
					desc = "Full GUI: combat, Auto-Clash, economy tools, configs.",
					url = "https://raw.githubusercontent.com/Raffir2/spellbound/main/spellbound_gui.lua" },
				{ id = "books", name = "Book Farm",
					desc = "Walks to every BookDrop and collects it, loops on respawns. Stop: getgenv().StopBookFarm()",
					path = "games/spellbound/book_farm.lua" },
			},
		},
		{
			id = "wizard-west",
			name = "Wizard West",
			universe = { 5939817752 },
			places = { 17357719939 },
			scripts = {
				{ id = "main", name = "Wizard West", default = true,
					desc = "Money vacuum, gem mining, broom travel, Apparate TP, silent aim, auto farm.",
					url = "https://raw.githubusercontent.com/Raffir2/wizard-west/main/wizard_west.lua" },
			},
		},
		{
			id = "tsc",
			name = "Thunder Scientific Corporation",
			universe = { 2762257604 },
			places = { 7131355525, 89095961698342 },
			quiet = true,
			scripts = {
				{ id = "main", name = "TSC Menu", default = true,
					desc = "Combat, visuals, Auto Vent, Auto Hack, staff radar. Hook-free.",
					url = "https://raw.githubusercontent.com/filipmijo2/tsc-hub/main/tsc_hub.lua" },
				{ id = "vent", name = "Auto Vent (standalone)",
					desc = "Old standalone vent solver. The TSC Menu already contains it; only use one.",
					path = "games/tsc/auto_vent.lua" },
			},
		},
		{
			id = "utg",
			name = "Untitled Tag Game",
			universe = { 4864117649 },
			places = { 14044547200 },
			scripts = {
				{ id = "assist", name = "Tag Assist", default = true,
					desc = "Autopilot chase/flee, height planner, map memory, 3rd person, perfect rolls.",
					url = "https://raw.githubusercontent.com/filipmijo2/utg-tag-assist/main/tag_gui.lua" },
				{ id = "autopilot", name = "Autopilot (new)",
					desc = "From-scratch autopilot with nav graph, learn + evade layers, boosts (F4).",
					path = "games/utg/utg_autopilot.lua" },
				{ id = "slide", name = "Infinite Slide",
					desc = "Slide without time limit and keep gaining speed. Game-native multipliers only.",
					path = "games/utg/infinite_slide.lua" },
			},
		},
		{
			id = "aot",
			name = "Attack on Titan Revolution",
			universe = { 4658598196 },
			places = { 14916516914, 13379208636, 13379349730, 13904207646, 112374853034490 },
			scripts = {
				{ id = "main", name = "AOT:R Menu", default = true,
					desc = "Kill aura, blades/refill, ESP, gas/ODM buffs, anti-ragdoll, auto chest/retry.",
					url = "https://raw.githubusercontent.com/filipmijo2/aot-hub/main/aot_hub.lua" },
			},
		},
		{
			id = "elemental-magic-arena",
			name = "Elemental Magic Arena",
			universe = { 2822776643 },
			places = { 7243409883 },
			scripts = {
				{ id = "main", name = "EMA Helper", default = true,
					desc = "Remote diamond pickup, free element pads, silent aim, poison target lock.",
					path = "games/elemental-magic-arena/ema_script.lua" },
			},
		},
		{
			id = "quantify",
			name = "QUANTIFY (Shape Factory)",
			universe = { 8161187430 },
			places = { 73648930852061, 106281373202161 },
			scripts = {
				{ id = "tool", name = "Shape Tool", default = true,
					desc = "Auto sell, auto craft, auto build, conveyor helper.",
					path = "games/quantify/shape_gui.lua" },
				{ id = "autoplay", name = "Autoplay",
					desc = "Plans the best craft chain for the round and drives the crafter.",
					path = "games/quantify/autoplay.lua" },
				{ id = "autocraft", name = "Auto Craft & Sell",
					desc = "Flies loose shapes into your crafter and crafted ones onto the sell pad.",
					path = "games/quantify/autocraft.lua" },
			},
		},
		{
			id = "anime-expeditions",
			name = "Anime Expeditions",
			universe = { 7613921865 },
			places = { 84515722934860 },
			scripts = {
				{ id = "fish", name = "Auto Fishing", default = true,
					desc = "Casts, waits for the bite and wins the client-side reel minigame.",
					path = "games/anime-expeditions/autofish.lua" },
			},
		},
		{
			id = "drain-the-lake",
			name = "Drain the Lake",
			universe = { 10267363348 },
			places = { 138381251771774 },
			scripts = {
				{ id = "main", name = "DTL Auto Farm", default = true,
					desc = "Auto drain, round-robin auto sell, auto upgrade, open all chests. Reload each round.",
					path = "games/drain-the-lake/dtl_gui.lua" },
			},
		},
		{
			id = "mine-a-mountain",
			name = "Mine a Mountain",
			universe = { 10187294555 },
			places = { 125927821145949 },
			scripts = {
				{ id = "main", name = "Crystal Farm", default = true,
					desc = "Crystal autofarm with scouting, carry-weight logic and auto rejoin.",
					path = "games/mine-a-mountain/crystal_farm.lua" },
			},
		},
		{
			id = "absolvement",
			name = "Absolvement",
			universe = { 5403859973 },
			places = { 15646364136, 17430958679 },
			scripts = {
				{ id = "main", name = "Absolvement", default = true,
					desc = "Obsidian-UI script (gist).",
					url = "https://gist.githubusercontent.com/Raffir2/0a7e026058262aac29a3310ecf14d6d5/raw/main.lua" },
			},
		},
	},
}
