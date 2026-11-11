class_name MissionData
extends Resource

@export_group("1. Companion & Security Guard Roles")
@export var agent_name: String = "Mia"
@export var agent_codename: String = "ORACLE-01"
@export var agent_color: Color = Color("#f600ff")
## "prediction" (Mia: predicts monster's next hack/code) or "forgive_hack" (Naomi: blocks/forgives 1 monster hack)
@export var companion_perk: String = "prediction"
@export var security_guard_name: String = "Naomi"
@export var security_guard_codename: String = "AEGIS-02"
@export var monster_name: String = "SUBJECT-ZERO"
@export var total_security_levels: int = 5
@export var camera_label: String = "CAM_01_CONTROL_ROOM"
@export var sector_name: String = "CONTAINMENT SECTOR // 5 SECURITY GATES"
@export var agent_portrait: Texture2D
@export_file("*.ogv") var seedance_video: String = ""
@export var vn_background: Texture2D
@export var map_agent_pos: Vector2 = Vector2(0.86, 0.50)
@export var map_target_pos: Vector2 = Vector2(0.14, 0.50)
@export var initial_bpm: int = 95
@export var max_bpm: int = 175
@export var initial_affinity: int = 50
@export var mission_time_seconds: int = 180

@export_group("2. Opening & Panic Dialogues (Console)")
@export_multiline var system_intro: String = "NIGHT SHIFT CONTAINMENT ACTIVE. SUBJECT-ZERO DETECTED AT SECURITY LEVEL 1."
@export_multiline var agent_opening_line: String = "«Operator, Subject-Zero is trying to hack our network to open the 5 Security Gates! Counter-hack its matrix so Naomi can lock the blast doors!»"
@export_multiline var agent_panic_line: String = "«It just breached another Security Gate! It's getting closer to the Control Room—hurry!»"

@export_group("3. Companion Interaction (Comfort & Flirt)")
@export var reassure_button_label: String = "HOLD HER HAND & REASSURE (-25 BPM / +20 BOND)"
@export_multiline var operator_reassure_line: String = "«Stay close to me, Mia. I won't let that thing get through the 5th gate.»"
@export_multiline var agent_reassure_reply: String = "«...Okay. When you hold my hand like that, I can focus my neural predictoragain. Let's lock this monster down!»"

@export_group("4. Security Protocols & Monster Logs (BBCode)")
@export var tab_1_title: String = "📁 01_GATE_PROTOCOLS"
@export_multiline var tab_1_content: String = """[b][color=#00f0ff]=== 5-LEVEL CONTAINMENT GATE PROTOCOLS ===[/color][/b]
[color=#667788]------------------------------------------------------------[/color]
To seal all [b]5 Security Levels[/b] with the Field Security Guard, select the active [b]Gate Lock Authority[/b] and inject the matching [b]Override Token[/b]:

[b]• DR. ELENA VANCE[/b] | [color=#ff5577]STATUS: CORRUPTED BY ENTITY[/color]
  Token ID: [code]VANCE-404[/code]
  Warning: Compromised bio-signature. Selecting this lets Subject-Zero advance 1 Security Level!

[b]• MARCUS STERLING[/b] | [color=#ffcc00]STATUS: DAY SHIFT ONLY[/color]
  Token ID: [code]STERLING-01[/code]
  Warning: Offline during Night Shift containment. Will trigger a firewall fault.

[b]• CHIEF SOFIA CHEN[/b] | [color=#00ff9d]STATUS: NIGHT CONTAINMENT WARDEN (VALID)[/color]
  Role: Level 1-5 Blast Door Authority | Active Night Key
  Note: Use her identity + tonight's rotating Override Token (see Tab 02) to seal the gates!"""

@export var tab_2_title: String = "✉️ 02_SECURITY_CODES"
@export_multiline var tab_2_content: String = """[b][color=#00f0ff]=== EMERGENCY CONTAINMENT DISPATCH #884 ===[/color][/b]
[color=#667788]FROM: warden-system@zero-facility.net -> TO: night-operator@zero-facility.net[/color]
[color=#667788]SUBJECT: Subject-Zero Containment & Blast Door Override Key[/color]

Operator,
[b]Subject-Zero[/b] has learned how to hack our security terminals. Every time its hack bar reaches 100% (or you fail a counter-hack), it will breach one of the [b]5 Security Levels[/b].
If it breaches [b]Level 5[/b], it will enter the Control Room and kill your companion and you.

[b]HOW TO SEAL THE 5 SECURITY GATES:[/b]
1. Break the Entity's jamming in [b][03_COUNTER_HACK][/b].
2. Authorize the Security Guard using [b]Chief Sofia Chen[/b] and Override Token: [b][color=#00ff9d]OMEGA-99[/color][/b]."""

@export_group("5. Counter-Hack Minigame (Breach Matrix)")
@export var require_firewall_breach: bool = true
@export var breach_difficulty: int = 3
@export_multiline var breach_success_log: String = "COUNTER-HACK COMPLETE: Entity jamming disrupted! Send the Override Token so the Security Guard can seal the blast door!"

@export_group("6. Gate Lock Credentials")
@export var suspects_list: PackedStringArray = ["Dr. Elena Vance", "Marcus Sterling", "Chief Sofia Chen"]
@export var correct_suspect_index: int = 2
@export var correct_token_code: String = "OMEGA-99"
@export var wrong_suspect_feedback: PackedStringArray = [
	"«Alert! Dr. Vance's key is corrupted by Subject-Zero! The monster used the fault to breach a Security Gate!»",
	"«Error! Sterling's day-shift key was rejected! Subject-Zero exploited the delay to advance a Security Level!»",
	"«The Warden identity is right, but the Override Token is wrong! Check Tab 02 before the monster advances!»"
]

@export_group("7. Actions & Outcomes")
@export var btn_mission_label: String = "🔒 SEAL SECURITY GATE (Guard Closes Door)"
@export_multiline var mission_success_text: String = "ALL 5 SECURITY GATES SEALED: Subject-Zero is locked back in the Core! You and your companion survived the night!"

@export var btn_romance_label: String = "💖 OVERCHARGE SHIELD FOR HER (Romance / Instant Seal)"
@export_multiline var operator_protect_line: String = "«I'm rerouting 100% of the Control Room's auxiliary power to your position—sealing all blast doors right now!»"
@export_multiline var agent_protect_reply: String = "«You risked overloading your own neural rig just to keep us safe from that monster... Come here, Operator.»"
@export_multiline var romance_success_text: String = "ROMANCE CONTAINMENT COMPLETE: You protected both girls and sealed Subject-Zero with maximum bond!"

@export_group("8. Visual Novel - Phase Scripts")
@export_multiline var vn_intro_script: String = """SYSTEM | [CONTAINMENT BUNKER ZERO // 11:55 PM] — 5 Minutes until Night Shift.
Mia | «Operator, Subject-Zero is restless tonight. If it hacks through all 5 Security Levels, we're both dead.»
OPERATOR | «That won't happen, Mia. With you predicting its hacks beside me and Naomi locking the 5 blast doors on patrol, we'll contain it.»
CHOICE | «Stay close to me tonight, Mia. I trust your predictions (+15 Mia Bond)» | 15 | «...Thank you! I'll highlight every move the monster makes on your console.» | «Let's stay focused on the 5 security gates (+5 Mia Bond)» | 5 | «Right! I'll feed you the monster's attack vectors as soon as the shift starts.»
Mia | «Midnight alarm! Subject-Zero is attacking Security Gate 1—get on the console!»"""

@export_multiline var vn_outro_mission_script: String = """SYSTEM | [06:00 AM // NIGHT SHIFT SURVIVED — ALL 5 GATES SEALED]
Mia | «Phew... Naomi just locked the fifth and final blast door! Subject-Zero is trapped back in the core.»
OPERATOR | «Your predictions saved us tonight, Mia. Neither of you got hurt.»
Mia | «My heart is still pounding... Stay with me in the lounge for a bit before we go to sleep, Operator.»"""

@export_multiline var vn_outro_romance_script: String = """SYSTEM | [06:00 AM // PRIVATE QUARTERS — MAXIMUM BOND]
Mia | «I was terrified when Subject-Zero tried to hack our terminal... but you didn't hesitate for a second to protect us.»
OPERATOR | «I told you I'd never let that thing reach you, Mia.»
Mia | «Tonight proved we make an unbeatable team. Don't let go of my hand yet, Operator...»"""

@export_multiline var vn_outro_failure_script: String = """SYSTEM | [CRITICAL BREACH // ALL 5 SECURITY LEVELS COMPROMISED]
Mia | «NO! The Level 5 blast door just ruptured! It's inside the Control Room—AAAAAH!»
OPERATOR | «MIA, NO! STAY BACK—!»
SYSTEM | CONTAINMENT FAILED. Your companion was killed, and Subject-Zero claimed your life next. Restarting Night Shift..."""
