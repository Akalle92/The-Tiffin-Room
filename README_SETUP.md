# THE TIFFIN ROUTE — Dev Setup Guide

## Opening the Project

1. Launch **Godot 4.3+** (GL Compatibility renderer recommended)
2. In the Project Manager click **Import**
3. Browse to this folder and select `project.godot`
4. Click **Import & Edit**

The editor will scan and import all files. A few "missing texture" warnings on first open are expected — placeholder PNGs are in `assets/placeholder/` and `assets/sprites/`.

---

## Controls

| Key | Action |
|-----|--------|
| WASD / Arrow Keys | Move (also used inside movement/traversal mini-games) |
| E | Interact with NPC (deliver tiffin / talk) |
| J | Open Route Journal |
| R | Rest until morning (night only) |
| N | Toggle Day ↔ Night (**debug only**) |
| Esc / X | Close dialogue / journal |
| Enter / Space | Advance dialogue / act in timing mini-games |

Mini-games are **optional**. Every one has an on-screen **Skip** button, and a
global **"Skip mini-games"** toggle lives on the Title screen (persisted to
`user://settings.cfg`). A higher relevant stat makes each mini-game easier.

---

## Project Structure

```
project.godot           ← Open this in Godot 4
scenes/
  main.tscn             ← Root scene (run this)
  world/
	city_day.tscn       ← Day city (ColorRect placeholder art)
	city_night.tscn     ← Night spirit-city
  player/
	player.tscn         ← CharacterBody2D, 4-dir movement
  npc/
	npc.tscn            ← Day NPC (StaticBody2D + interaction area)
	npc_spirit.tscn     ← Night spirit NPC (glowing, pulse)
  ui/
	hud.tscn            ← Always-visible HUD
	dialogue_box.tscn   ← Dialogue panel with choices + skill voices
	route_journal.tscn  ← Full-screen relationship journal [J]

scripts/
  autoload/
	GameState.gd        ← SINGLETON: stats, routes, day/night, flags
	DialogueManager.gd  ← SINGLETON: runs dialogue trees, stat checks
	SaveLoad.gd         ← SINGLETON: ConfigFile save to user://
  player/Player.gd      ← Movement, interaction detection
  npc/NPC.gd            ← Day NPC behaviour, delivery tracking
  npc/NPCSpirit.gd      ← Night spirit NPC, pulse glow
  world/DayNightController.gd  ← Scene swap, CanvasModulate
  ui/DialogueBox.gd     ← Typewriter, choices, skill-voice panel
  ui/RouteJournal.gd    ← Relationship web UI
  ui/HUD.gd             ← Time bar, delivery counter, stat display
  ui/DayNightClock.gd   ← Radial clock widget
  systems/StatCheck.gd  ← Stat roll helpers (class_name, static)
  minigames/            ← Optional "gameplay verb" mini-games
	MinigameBase.gd     ← Shared overlay scaffold (skip button, result signal)
	MinigameLayer.gd    ← Bridges DialogueManager <-> mini-game scenes
	SelectClues.gd      ← NOSE deduction board + Champa chai matching
	Balance.gd          ← STEADY_HANDS carry-the-stack
	Route.gd            ← STREET_SENSE read-the-street
	Dreamscape.gd       ← spirit-world traversal
	Silence.gd          ← "let the silence land" timing beat

scenes/minigames/       ← One thin .tscn per mini-game (root + script)

data/
  dialogue/
	npc_data.json       ← ALL dialogue trees (5 NPCs + Babulal finale; incl. small_talk, convergence, spirit_hardened)
	skill_voices.json   ← EMPATHY/NOSE/STEADY_HANDS/STREET_SENSE/GRIEF voice lines

assets/
  placeholder/          ← 16×16 RGBA PNGs for tiles (colour-coded)
  sprites/
	player/             ← Placeholder player day + night sprites
	npcs/               ← Placeholder portrait PNGs per NPC
```

---

## Systems Overview

### GameState (Autoload)
Central truth for everything. Tracks:
- **Player stats**: EMPATHY, NOSE, STEADY_HANDS, STREET_SENSE, GRIEF (0–5)
- **Routes**: per-NPC dict with `day_state`, `trust_level`, `spirit_unlocked`, `spirit_resolved`, `notes`
- **Day / Night**: `is_night`, `day_number`, `time_of_day`
- **Flags**: arbitrary key/value for story events
- **Save/Load**: delegates to SaveLoad autoload (user://save_game.cfg)

### DialogueManager (Autoload)
- Call `DialogueManager.start_dialogue("mrs_mehta")` from any NPC
- Auto-selects the right tree based on route progress (`first_meeting` →
  `developing` → `small_talk` → `trust`; night: `spirit_intro` →
  `spirit_resolution`, or `spirit_hardened` if neglected, then `spirit_aftermath`)
- Emits `node_displayed`, `choices_presented`, `voice_interjected`,
  `minigame_requested`, `dialogue_ended`
- `DialogueBox.gd` connects to these signals and renders the UI

### Mini-games / Neglect / Finale (new systems)
- **Mini-games**: a node with a `"minigame"` block pauses dialogue, runs an
  overlay via `MinigameLayer`, then branches to `success_next` / `fail_next`.
  Fail is always narrative-only (never a game over) and every game is skippable.
- **Neglect / decay**: a spirit left unresolved for `DECAY_DAYS` (GameState)
  becomes `hardened` — still resolvable, but only through the bittersweet
  `spirit_hardened` tree. Surfaced in the journal as "Distant".
- **Finale**: when all five spirits resolve, `DayNightController` plays the
  `babulal` `finale` tree (the protagonist's own last delivery), then the
  choice-reflective ending assembled in `Ending.gd` from story flags.

### Dialogue Tree JSON Format
```json
{
  "npc_id": {
	"dialogue_trees": {
	  "tree_id": {
		"start": "first_node_id",
		"nodes": {
		  "node_id": {
			"speaker": "Name or null",
			"text": "Line of dialogue",
			"voice_interjections": [
			  {"skill": "EMPATHY", "text": "Internal voice text", "requires_stat": 2}
			],
			"choices": [
			  {
				"id": "c1a",
				"text": "Player choice text",
				"stat_check": {"skill": "GRIEF", "threshold": 2},
				"requires_flag": "only_show_if_set",
				"requires_not_flag": "hide_once_set",
				"next": "next_node_id",
				"fail_next": "fallback_node_id",
				"effects": {
				  "route_update": {"day_state": 2},
				  "stat_modify": {"EMPATHY": 1},
				  "set_flag": "flag_name",
				  "set_flags": ["flag_a", "flag_b"],
				  "add_note": "Note added to journal"
				}
			  }
			],
			"next": "auto_advance_node_or_END"
		  },
		  "minigame_node": {
			"speaker": "NARRATOR",
			"text": "Narrative setup shown before the mini-game.",
			"minigame": {"type": "nose_board", "stat": "NOSE"},
			"success_next": "node_if_win",
			"fail_next": "node_if_fail",
			"success_effects": {"add_note": "..."},
			"fail_effects": {}
		  }
		}
	  }
	}
  }
}
```

Mini-game `type` values: `nose_board`, `prep`, `balance`, `route`,
`dreamscape`, `silence`. Node-level `"effects"` are also applied on display.

### NPC Scene Setup
Each NPC instance in `city_day.tscn` needs its `npc_id` set in the Inspector:
- `MrsMehta` → `npc_id = "mrs_mehta"`
- `Raju` → `npc_id = "raju"`
- `Champa` → `npc_id = "champa"`
- `Desai` → `npc_id = "desai"`
- `Arjun` → `npc_id = "arjun"`

Same for spirits in `city_night.tscn`. Do this in the Godot editor after first open.

---

## Five NPCs — Quick Reference

| NPC | Location | Day Arc | Spirit Delivery |
|-----|----------|---------|-----------------|
| **Mrs. Mehta** | Flat 4B area | Widow, unsent letter | His letter, read aloud |
| **Raju** | Temple steps | Runaway schoolboy | The unmade phone call home |
| **Desai Sahib** | Municipal office | Corrupt clerk (wife is ill) | PM-JAY form he never filed |
| **Arjun** | Family home | Estranged son, missed funeral | Words through a closed door |
| **Champa Tai** | Tea stall corner | Homesick 25-year stall owner | Permission to belong to two homes |

---

## Phase 2 Checklist (next steps before Higgsfield)
- [ ] Open project in Godot, verify it runs without errors
- [ ] Set `npc_id` export vars on each NPC instance in scene Inspector
- [ ] Test player movement + NPC interaction (E key)
- [ ] Test dialogue system: walk up to Mrs. Mehta, press E
- [ ] Test day/night toggle (N key) — city should swap, CanvasModulate should shift
- [ ] Test Route Journal (J key) — routes should populate
- [ ] Test save/load: make progress, quit, reopen

## Phase 3 Checklist (after placeholder verification)
- [ ] **CHECK IN** → approve Higgsfield art direction batch
- [ ] Generate protagonist sprite sheet + 5 NPC day/night sheets
- [ ] Import into Godot as AnimatedSprite2D (nearest filter, no mipmaps)
- [ ] Generate environment tiles: market streets, tenement, tea stall, temple, kitchen
- [ ] Build TileMap/TileSet in city_day.tscn + city_night.tscn
- [ ] Generate UI skin: tiffin-tin dialogue box, journal, HUD clock
- [ ] Generate intro cinematic (Higgsfield video) → VideoStreamPlayer cutscene
- [ ] Generate music: bazaar day track, dreamlike night track
- [ ] Generate SFX: tiffin-clink, bicycle bell, ambient city
- [ ] Configure Web + Desktop export → test both builds

---

## Export (when ready)
```
Project → Export → Add Preset:
  Web (HTML5) → Export to exports/web/index.html
  Windows Desktop → exports/windows/TheTiffinRoute.exe
```
Export templates must be installed in Godot (Editor → Manage Export Templates).
