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
@export var sector_name: String = "CONTAINMENT SECTOR // 5 SECURITY GATES"
@export var agent_portrait: Texture2D
@export_file("*.ogv") var seedance_video: String = ""
@export var vn_background: Texture2D
@export var initial_bpm: int = 95
@export var max_bpm: int = 175
@export var initial_affinity: int = 50
@export var mission_time_seconds: int = 180

@export_group("2. Console Settings & Minigame")
@export_multiline var agent_panic_line: String = "«It just breached another Security Gate! It's getting closer to the Control Room—hurry!»"
@export var breach_difficulty: int = 3

@export_group("3. Outcomes")
@export_multiline var mission_success_text: String = "ALL 5 SECURITY GATES SEALED: Subject-Zero is locked back in the Core! You and your companion survived the night!"
@export_multiline var romance_success_text: String = "ROMANCE CONTAINMENT COMPLETE: You protected both girls and sealed Subject-Zero with maximum bond!"

@export_group("4. Standalone Visual Novel Scripts (Optional)")
@export_multiline var vn_intro_script: String = ""
@export_multiline var vn_outro_mission_script: String = ""
@export_multiline var vn_outro_romance_script: String = ""
@export_multiline var vn_outro_failure_script: String = ""
