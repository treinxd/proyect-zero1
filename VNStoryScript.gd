class_name VNStoryScript
extends RefCounted

# ==============================================================================
# PARSER DE GUIONES ESTILO REN'PY PARA PROYECT-ZERO
# ==============================================================================
# Comandos soportados:
#   label nombre_bloque:
#   scene nombre_fondo              (bunker, helios_tower, nexus_core, cyber_bar, rooftop_rain o ruta res://...)
#   show maria happy at left hop    (posiciones: left, center, right | emotes: hop, shake, nod)
#   hide maria
#   maria "Texto del diálogo..."
#   operador "Texto del diálogo..."
#   narrador "Texto descriptivo..."
#   menu:
#       "Opción 1" -> label_destino | maria_affinity += 15
#       "Opción 2" -> otro_label | yuri_affinity += 10
#   set variable += 10              (o set variable = 50)
#   if maria_affinity >= 70 -> final_maria
#   hack 0 on_mission=m1_mision on_romance=m1_romance on_fail=m1_fallo
#   jump nombre_label
#   end
# ==============================================================================

static func parse_script(source_text: String) -> Dictionary:
	var labels: Dictionary = {}
	var current_label: String = "start"
	labels[current_label] = []

	var lines = source_text.split("\n")
	var i: int = 0
	while i < lines.size():
		var raw_line = lines[i]
		var line = raw_line.strip_edges()
		i += 1

		if line == "" or line.begins_with("#"):
			continue

		# 1. LABEL
		if line.begins_with("label ") and line.ends_with(":"):
			current_label = line.trim_prefix("label ").trim_suffix(":").strip_edges()
			if not labels.has(current_label):
				labels[current_label] = []
			continue

		# 2. SCENE (Cambio de fondo con crossfade)
		if line.begins_with("scene "):
			var bg_arg = line.trim_prefix("scene ").strip_edges()
			labels[current_label].append({
				"cmd": "scene",
				"bg": bg_arg
			})
			continue

		# 3. SHOW (Mostrar o actualizar sprite animado en pantalla)
		if line.begins_with("show "):
			var tokens = line.trim_prefix("show ").strip_edges().split(" ", false)
			var char_id = tokens[0].to_lower() if tokens.size() > 0 else "maria"
			var expr = "normal"
			var pos_slot = "center"
			var emote = ""

			var t_idx = 1
			while t_idx < tokens.size():
				var tk = tokens[t_idx].to_lower()
				if tk == "at" and t_idx + 1 < tokens.size():
					pos_slot = tokens[t_idx + 1].to_lower()
					t_idx += 2
				elif tk in ["hop", "bounce", "shake", "panic", "nod"]:
					emote = tk
					t_idx += 1
				else:
					expr = tk
					t_idx += 1

			labels[current_label].append({
				"cmd": "show",
				"char_id": char_id,
				"expression": expr,
				"position": pos_slot,
				"emote": emote
			})
			continue

		# 4. HIDE (Ocultar personaje del escenario)
		if line.begins_with("hide "):
			var char_id = line.trim_prefix("hide ").strip_edges().to_lower()
			labels[current_label].append({
				"cmd": "hide",
				"char_id": char_id
			})
			continue

		# 5. MENU (Bloque de elecciones estilo Ren'Py)
		if line == "menu:":
			var options: Array[Dictionary] = []
			while i < lines.size():
				var peek_raw = lines[i]
				var peek = peek_raw.strip_edges()
				if peek == "" or peek.begins_with("#"):
					i += 1
					continue
				if not peek.begins_with("\""):
					break
				i += 1
				options.append(_parse_menu_option(peek))

			labels[current_label].append({
				"cmd": "menu",
				"options": options
			})
			continue

		# 6. HACK (Lanzar minijuego de consola y ramificar según el resultado)
		if line.begins_with("hack "):
			var tokens = line.trim_prefix("hack ").strip_edges().split(" ", false)
			var m_idx = int(tokens[0]) if tokens.size() > 0 else 0
			var on_mission = ""
			var on_romance = ""
			var on_fail = ""
			for tk in tokens:
				if tk.begins_with("on_mission="):
					on_mission = tk.trim_prefix("on_mission=")
				elif tk.begins_with("on_romance="):
					on_romance = tk.trim_prefix("on_romance=")
				elif tk.begins_with("on_fail="):
					on_fail = tk.trim_prefix("on_fail=")
			labels[current_label].append({
				"cmd": "hack",
				"mission_index": m_idx,
				"on_mission": on_mission,
				"on_romance": on_romance,
				"on_fail": on_fail
			})
			continue

		# 7. SET (Modificar variables de estado / afinidad)
		if line.begins_with("set "):
			var expr_str = line.trim_prefix("set ").strip_edges()
			labels[current_label].append({
				"cmd": "set",
				"expr": expr_str
			})
			continue

		# 8. IF (Condicional de salto según variables)
		if line.begins_with("if ") and line.contains("->"):
			var parts = line.trim_prefix("if ").split("->")
			var cond_str = parts[0].strip_edges()
			var target_lbl = parts[1].strip_edges()
			labels[current_label].append({
				"cmd": "if",
				"condition": cond_str,
				"target": target_lbl
			})
			continue

		# 9. JUMP (Salto directo a otro label)
		if line.begins_with("jump "):
			var target_lbl = line.trim_prefix("jump ").strip_edges()
			labels[current_label].append({
				"cmd": "jump",
				"target": target_lbl
			})
			continue

		# 10. END (Fin de la historia / volver al título)
		if line == "end":
			labels[current_label].append({"cmd": "end"})
			continue

		# 11. DIÁLOGO: personaje "Texto..." o "Texto..." directo
		var first_quote = line.find("\"")
		var last_quote = line.rfind("\"")
		if first_quote != -1 and last_quote > first_quote:
			var speaker_id = line.substr(0, first_quote).strip_edges()
			if speaker_id == "":
				speaker_id = "narrador"
			var text_body = line.substr(first_quote + 1, last_quote - first_quote - 1)
			labels[current_label].append({
				"cmd": "say",
				"speaker": speaker_id,
				"text": text_body
			})
		else:
			labels[current_label].append({
				"cmd": "say",
				"speaker": "narrador",
				"text": line
			})

	return labels

static func _parse_menu_option(opt_line: String) -> Dictionary:
	var q_end = opt_line.find("\"", 1)
	var opt_text = opt_line.substr(1, q_end - 1) if q_end != -1 else opt_line
	var rest = opt_line.substr(q_end + 1).strip_edges() if q_end != -1 else ""
	var target_label = ""
	var var_effect = ""

	if rest.begins_with("->"):
		rest = rest.trim_prefix("->").strip_edges()
		var pipe_idx = rest.find("|")
		if pipe_idx != -1:
			target_label = rest.substr(0, pipe_idx).strip_edges()
			var_effect = rest.substr(pipe_idx + 1).strip_edges()
		else:
			target_label = rest

	return {
		"text": opt_text,
		"target": target_label,
		"effect": var_effect
	}

# ==============================================================================
# FULL VISUAL NOVEL SCRIPT: PROYECT-ZERO (DATING SIM + 2D HORROR CONTAINMENT)
# ==============================================================================
const DEFAULT_STORY_SCRIPT: String = """
label start:
	scene bunker
	show mia normal at center hop
	narrador "11:45 PM — FACILITY ZERO CONTROL LOUNGE // 15 MINUTES BEFORE NIGHT SHIFT."
	mia "«Operator, you're finally here. The biometric sensors in Sector Zero are spiking... Subject-Zero is awake inside the Containment Core.»"
	operador "«How bad is it tonight, Mia?»"
	mia "«It's trying to hack directly into our main terminal to open the 5 Security Level blast doors. If it breaches all 5 Security Levels and reaches this Control Room... it'll kill whoever is sitting beside you, and then it'll kill you.»"
	show naomi smile at right hop
	show mia normal at left
	naomi "«Which is why we're not letting that ugly thing get past Level 5! One of us will stay right here with you as your Hacking Companion, and the other will patrol the corridors as the Security Guard to physically lock all 5 Security Gates.»"
	mia "«Choose carefully, Operator. If you pick me as your Hacking Companion, I can use my neural algorithm to predict what the monster is going to do next and highlight its hack sequence for you.»"
	naomi "«And if you pick me as your Hacking Companion, I'll plug my Aegis deck into your console! If the monster manages to hack you, I'll stop and forgive at least one full breach for you!»"
	narrador "Who do you want by your side in the Control Room tonight, and who will patrol the sectors as the Security Guard closing the 5 doors?"
	menu:
		"Choose MIA as Hacking Companion (🔮 Predicts Monster Moves | Naomi is Security Guard) (+15 Mia Bond)" -> companion_mia | mia_affinity += 15
		"Choose NAOMI as Hacking Companion (🛡️ Forgives 1 Monster Hack | Mia is Security Guard) (+15 Naomi Bond)" -> companion_naomi | naomi_affinity += 15

label companion_mia:
	hide naomi
	show mia blush at center hop
	operador "«Mia, stay here with me in the Control Room. I need your predictions tonight—and honestly, I feel better having you close.»"
	mia "«...Really? My heart rate just jumped a little, and it's not because of the monster. I won't let you down, Operator.»"
	show naomi happy at right hop
	show mia normal at left
	naomi "«Alright, lovebirds! I'll grab my stun baton and head out to Security Gate 1. Counter-hack the monster's jamming from the console so I can seal all 5 blast doors!»"
	hide naomi
	show mia happy at center nod
	mia "«It's 12:00 AM! Subject-Zero is launching its first hack against Security Level 1. Watch my predictions on your screen and let's help Naomi close all 5 doors!»"
	hack 0 on_mission=mia_survived on_romance=mia_romance on_fail=night_breach_mia

label companion_naomi:
	hide mia
	show naomi blush at center hop
	operador "«Naomi, stay with me at the console. Having you and your Aegis barrier beside me is the only way we survive tonight.»"
	naomi "«Heh... say stuff like that and I might actually blush, boss! Don't worry—if Subject-Zero slips a hack past you, I'll block it for you at least once tonight!»"
	show mia normal at left
	show naomi smile at right
	mia "«I'll take the Security Guard shift on the floor, then. As soon as you two counter-hack the monster's jamming, send me the Override Key and I'll lock the 5 Security Gates one by one!»"
	hide mia
	show naomi happy at center hop
	naomi "«12:00 AM alarm! Subject-Zero is trying to hack Gate 1! Get on the terminal, Operator—I've got your back!»"
	hack 1 on_mission=naomi_survived on_romance=naomi_romance on_fail=night_breach_naomi

label night_breach_mia:
	scene helios_tower
	show mia panic at center shake
	narrador "⚠️ CRITICAL ALERT — ALL 5 SECURITY LEVELS BREACHED BY SUBJECT-ZERO!"
	mia "«NO! The Level 5 blast door just shattered! Operator, get behind me—AAAAAH!»"
	hide mia
	operador "«MIA! NO—!»"
	narrador "Subject-Zero tore through the Control Room, killing Mia right in front of your console before lunging at you in the dark. [NIGHT FAILED — RESTARTING NIGHT SHIFT...]"
	jump start

label night_breach_naomi:
	scene helios_tower
	show naomi panic at center shake
	narrador "⚠️ CRITICAL ALERT — ALL 5 SECURITY LEVELS BREACHED BY SUBJECT-ZERO!"
	naomi "«My Aegis barrier overloaded! The 5th gate is open—RUN, OPERATOR—AAAAAH!»"
	hide naomi
	operador "«NAOMI! HOLD ON—!»"
	narrador "Subject-Zero struck Naomi down beside the terminal before emerging from the shadows to claim your life next. [NIGHT FAILED — RESTARTING NIGHT SHIFT...]"
	jump start

label mia_romance:
	scene rooftop_rain
	show mia blush at center hop
	narrador "06:00 AM — NIGHT SURVIVED // CONTROL ROOM LOUNGE."
	mia "«We did it... Naomi sealed all 5 Security Gates, and Subject-Zero is locked back inside the Core.»"
	operador "«Your predictions saved our lives tonight, Mia. And when the monster got close, all I could think about was keeping you safe.»"
	show mia happy at center nod
	mia "«You risked overloading your own neural link just to shield me... Don't let go of my hand yet, Operator. Stay with me until we have to report for the next shift.»"
	set mia_affinity += 20
	narrador "★ ENDING UNLOCKED: ORACLE OF MY HEART — MIA ROMANCE ROUTE ★"
	end

label mia_survived:
	scene cyber_bar
	show mia smile at left
	show naomi happy at right hop
	narrador "06:00 AM — NIGHT SURVIVED // ALL 5 SECURITY GATES SEALED."
	naomi "«Phew! Locking five heavy blast doors while a cyber-monster claws at the walls is a serious workout!»"
	mia "«We survived because the three of us worked together. Get some rest, Operator—Subject-Zero will try to escape again tomorrow night.»"
	if mia_affinity >= 70 -> mia_romance
	narrador "★ NIGHT SHIFT COMPLETED: CONTAINMENT PROTOCOL INTACT ★"
	end

label naomi_romance:
	scene rooftop_rain
	show naomi blush at center hop
	narrador "06:00 AM — NIGHT SURVIVED // ROOFTOP DAWN WITH NAOMI."
	naomi "«Haha, we actually locked that thing behind all 5 gates! My heart is still beating a mile a minute.»"
	operador "«You stopped Subject-Zero from frying my terminal, Naomi. I owe you my life.»"
	show naomi happy at center nod
	naomi "«Then pay me back by staying right here with me. Forget Facility ZERO for today, Operator—this morning belongs to just the two of us.»"
	set naomi_affinity += 20
	narrador "★ ENDING UNLOCKED: UNBREAKABLE AEGIS — NAOMI ROMANCE ROUTE ★"
	end

label naomi_survived:
	scene cyber_bar
	show mia smile at left
	show naomi happy at right hop
	narrador "06:00 AM — NIGHT SURVIVED // ALL 5 SECURITY GATES SEALED."
	mia "«All five containment doors are locked and holding at 100% integrity. Great work in the Control Room, you two.»"
	naomi "«Told you my Aegis shield would keep us alive! Come on, Operator, breakfast is on you!»"
	if naomi_affinity >= 70 -> naomi_romance
	narrador "★ NIGHT SHIFT COMPLETED: CONTAINMENT PROTOCOL INTACT ★"
	end
"""
