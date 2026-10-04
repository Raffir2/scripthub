#!/usr/bin/env bash
# Copies the local dev copies of the mirrored scripts into games/.
# Scripts that have their own repo (Spellbound, Wizard West, TSC, UTG Tag Assist,
# Absolvement) are NOT mirrored: the registry points at their raw URLs.
set -e
cd "$(dirname "$0")/.."
U=/c/Users/Seifb
P=$U/AppData/Local/Potassium
cp_() { mkdir -p "$(dirname "$2")"; if [ -f "$1" ]; then cp "$1" "$2"; echo "ok   $2"; else echo "MISS $1"; fi; }
cp_ "$P/workspace/book_farm.lua"            games/spellbound/book_farm.lua
cp_ "$P/workspace/ema_script.lua"           games/elemental-magic-arena/ema_script.lua
cp_ "$P/workspace/shape_gui.lua"            games/quantify/shape_gui.lua
cp_ "$P/workspace/autoplay.lua"             games/quantify/autoplay.lua
cp_ "$P/workspace/autocraft.lua"            games/quantify/autocraft.lua
cp_ "$P/workspace/autofish.lua"             games/anime-expeditions/autofish.lua
cp_ "$P/scripts/dtl_gui.lua"                games/drain-the-lake/dtl_gui.lua
cp_ "$U/Downloads/crystal_farm.lua"         games/mine-a-mountain/crystal_farm.lua
cp_ "$U/utg-slide/infinite_slide.lua"       games/utg/infinite_slide.lua
cp_ "$U/utg-autopilot/dist/utg_autopilot.lua" games/utg/utg_autopilot.lua
cp_ "$U/auto_vent.lua"                      games/tsc/auto_vent.lua
cp_ "$U/aot-hub/aot_hub.lua"                games/aot/aot_hub.lua
cp_ "$P/workspace/leaves_script.lua"        games/clean-all-the-leaves/leaf_farm.lua
cp_ "$U/vesteria-hub/vesteria_hub.lua"     games/vesteria/vesteria_hub.lua
