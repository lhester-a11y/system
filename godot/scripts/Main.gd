extends Node2D
class_name CodePlayMain
## ---------------------------------------------------------------------------
## CodePlay - module flow and wiring. The Godot counterpart of js/main.js:
##
##   * owns the save file and the routing between menu screens and the world
##   * spawns waves of bats, then the Syntax Overlord once the module's
##     checkpoints are cleared
##   * turns every answered checkpoint into saved progress, badges and points
##
## The learning loop itself lives in CodePlayCheckpoint.gd; this script is the
## bookkeeping around it.
## ---------------------------------------------------------------------------

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const BAT_SCENE := preload("res://scenes/Bat.tscn")
const BUG_SCENE := preload("res://scenes/Bug.tscn")

enum Mode { LOBBY, PLAY, QUIZ, BANNER, PAUSED }

const HUD_REFRESH := 0.12
const MAX_LIVE_BATS := 3

var progress: Dictionary = {}
var cfg: Dictionary = {}
var mode: int = Mode.LOBBY

var background: Background
var player: Player
var checkpoint: CodePlayCheckpoint
var ambient: AmbientFx
var popups: PopupLayer
var vignette: TextureRect

var hud: GameHUD
var quiz: QuizUI
var banner: BannerPanel
var toasts: ToastStack
var lobby: LobbyScreen
var howto: HowToScreen
var shop: ShopScreen
var progress_screen: ProgressScreen
var review_screen: ReviewScreen
var pause_screen: PauseScreen

var boss: Bat = null
var boss_pending := false
var boss_queued := false
var boss_incoming := 0.0
var kills := 0
var run_points := 0
var spawn_timer := 0.0
var level_complete := false
var play_seconds := 0.0
var _hud_clock := 0.0

func _ready() -> void:
	randomize()
	progress = Save.load_progress()
	play_seconds = float(progress.get("playSeconds", 0.0))
	# One theme for every screen: without it Godot's stock pale-grey controls make
	# the port look like a different game from the web build.
	get_window().theme = UiKit.theme()
	_build_world()
	_build_ui()
	_wire()
	Sfx.set_enabled(bool(progress.get("sound", true)))
	hud.set_sound_enabled(Sfx.enabled)
	to_lobby()
	# The tutorial interrupts exactly once. After the first dismissal the save
	# carries tutorialSeen, and the lobby's How to play button is the only way in.
	if not bool(progress.get("tutorialSeen", false)):
		_open_howto(true)

# ---------------------------------------------------------------- construction

func _build_world() -> void:
	background = Background.new()
	background.name = "Background"
	background.z_index = -10
	add_child(background)

	ambient = AmbientFx.new()
	ambient.name = "Ambient"
	ambient.visible = false
	add_child(ambient)

	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.visible = false
	add_child(player)

	popups = PopupLayer.new()
	popups.name = "Popups"
	add_child(popups)

	# The canvas vignette from renderer.js: it keeps the sprites readable against
	# a bright sky. Both edges fade in, and the middle stays clear.
	vignette = TextureRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.anchor_right = 1.0
	vignette.anchor_bottom = 1.0
	vignette.z_index = 3
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.texture = _vignette_texture()
	add_child(vignette)

	checkpoint = CodePlayCheckpoint.new()
	checkpoint.name = "Checkpoint"
	add_child(checkpoint)

func _build_ui() -> void:
	hud = GameHUD.new()
	hud.name = "HUD"
	add_child(hud)

	quiz = QuizUI.new()
	quiz.name = "Quiz"
	add_child(quiz)

	banner = BannerPanel.new()
	banner.name = "Banner"
	add_child(banner)

	toasts = ToastStack.new()
	toasts.name = "Toasts"
	add_child(toasts)

	lobby = LobbyScreen.new()
	lobby.name = "Lobby"
	add_child(lobby)

	howto = HowToScreen.new()
	howto.name = "HowTo"
	add_child(howto)

	shop = ShopScreen.new()
	shop.name = "Shop"
	add_child(shop)

	progress_screen = ProgressScreen.new()
	progress_screen.name = "Progress"
	add_child(progress_screen)

	review_screen = ReviewScreen.new()
	review_screen.name = "Review"
	add_child(review_screen)

	pause_screen = PauseScreen.new()
	pause_screen.name = "Pause"
	add_child(pause_screen)

func _wire() -> void:
	player.shield_used.connect(_on_shield_used)
	player.took_damage.connect(_on_took_damage)
	player.revived.connect(_on_revived)
	player.died.connect(_on_player_died)
	player.threw_spear.connect(_on_spear_thrown)

	checkpoint.checkpoint_opened.connect(_on_checkpoint_opened)
	checkpoint.checkpoint_resolved.connect(_on_checkpoint_resolved)

	quiz.answer_selected.connect(_on_answer_selected)
	quiz.continue_pressed.connect(_on_quiz_continue)

	hud.move_input.connect(_on_move_input)
	hud.throw_held.connect(_on_throw_held)
	hud.pause_pressed.connect(_on_pause_button)
	hud.sound_pressed.connect(_on_sound_toggled)

	lobby.start_pressed.connect(_on_start_pressed)
	lobby.hero_selected.connect(_on_hero_selected)
	lobby.name_changed.connect(_on_renamed)
	lobby.shop_pressed.connect(_open_shop)
	lobby.progress_pressed.connect(_open_progress)
	lobby.review_pressed.connect(_open_review)
	lobby.howto_pressed.connect(_open_howto)

	shop.buy_requested.connect(_on_buy)
	shop.equip_requested.connect(_on_equip)
	shop.back_pressed.connect(to_lobby)
	progress_screen.back_pressed.connect(to_lobby)
	review_screen.back_pressed.connect(to_lobby)
	howto.back_pressed.connect(_on_howto_back)

	pause_screen.resume_pressed.connect(_on_resume)
	pause_screen.restart_pressed.connect(_on_restart)
	pause_screen.lobby_pressed.connect(_on_pause_lobby)

	banner.primary_pressed.connect(_on_banner_primary)
	banner.secondary_pressed.connect(_on_banner_secondary)

# --------------------------------------------------------------- screen routing

func _hide_screens() -> void:
	lobby.close()
	howto.close()
	shop.close()
	progress_screen.close()
	review_screen.close()
	pause_screen.close()

func _open_shop() -> void:
	Sfx.play("click")
	_hide_screens()
	shop.render(progress)
	shop.open()

func _open_progress() -> void:
	Sfx.play("click")
	_hide_screens()
	progress_screen.render(progress)
	progress_screen.open()

## The study screen: every checkpoint with its answer, nothing hidden.
func _open_review() -> void:
	Sfx.play("click")
	_hide_screens()
	review_screen.render(progress)
	review_screen.open()

func _open_howto(first_time: bool = false) -> void:
	_hide_screens()
	if first_time:
		howto.open_as_gate()
	else:
		howto.open_as_reference()

## Leaving the how-to screen also counts as finishing the tutorial, however it
## was opened, so the gate can never reappear.
func _on_howto_back() -> void:
	if not bool(progress.get("tutorialSeen", false)):
		progress["tutorialSeen"] = true
		toasts.push("Tutorial done - press Start whenever you are ready", "good")
	to_lobby()

func to_lobby() -> void:
	mode = Mode.LOBBY
	level_complete = false
	get_tree().paused = false
	_clear_enemies()
	boss = null
	boss_pending = false
	boss_queued = false
	player.visible = false
	ambient.visible = false
	hud.set_visible_hud(false)
	quiz.set_open(false)
	banner.close()
	_hide_screens()
	lobby.render(progress)
	lobby.open()
	_save()

func start_module(module: int) -> void:
	progress["module"] = maxi(1, module)
	cfg = Rules.level_config(int(progress["module"]))
	var run_seed := int(Time.get_ticks_usec()) & 0x7fffffff

	UpgradeSystem.begin_run(progress, run_seed)
	UpgradeSystem.spear_design = String((progress["equipped"] as Dictionary).get("spear", "spear-bamboo")).replace("spear-", "")
	checkpoint.configure(progress, cfg, run_seed)
	checkpoint.reset_run()

	get_tree().paused = false
	_clear_enemies()
	boss = null
	boss_pending = false
	boss_queued = false
	boss_incoming = 0.0
	level_complete = false
	kills = 0
	run_points = 0
	spawn_timer = 0.9
	_hud_clock = 0.0

	player.begin_run(progress)
	player.touch_dir = 0.0
	player.hold_throw = false
	ambient.target = player
	ambient.set_effect(String((progress["equipped"] as Dictionary).get("effect", "effect-none")))
	ambient.visible = true
	background.set_sky(String(cfg["sky"]), int(progress["module"]) * 7919)
	background.set_target(player)

	_hide_screens()
	banner.close()
	quiz.set_open(false)
	mode = Mode.PLAY
	hud.set_visible_hud(true)
	_refresh_hud()
	toasts.push("Module %d - %s: %s" % [
		int(cfg["module"]), String(cfg["lang_name"]),
		String(Rules.language(String(cfg["lang"])).get("blurb", "")),
	], "good")
	_save()

# ------------------------------------------------------------------- gameplay

func _process(delta: float) -> void:
	play_seconds += delta
	if mode != Mode.PLAY:
		return

	_update_spawning(delta)

	_hud_clock += delta
	if _hud_clock >= HUD_REFRESH:
		_hud_clock = 0.0
		_refresh_hud()

func _update_spawning(delta: float) -> void:
	if level_complete:
		return
	var total := int(cfg["checkpoints"])

	if boss == null and not boss_queued:
		if kills < total:
			spawn_timer -= delta
			if spawn_timer <= 0.0 and _live_bats() < MAX_LIVE_BATS:
				spawn_bat()
				spawn_timer = float(cfg["spawn_interval"]) * randf_range(0.75, 1.25)
		else:
			# The swarm scatters before the boss descends.
			boss_queued = true
			boss_incoming = 1.3
			_clear_enemies()
			toasts.push("Something large is flying in...", "bad")

	if boss_queued and boss == null:
		boss_incoming -= delta
		if boss_incoming <= 0.0:
			spawn_boss()

func spawn_bat() -> void:
	if level_complete or boss != null:
		return
	var bat: Bat = BAT_SCENE.instantiate()
	bat.speed = float(cfg["bat_speed"]) * randf_range(0.85, 1.15)
	bat.altitude_min = float(cfg["bat_altitude_min"])
	bat.altitude_max = float(cfg["bat_altitude_max"])
	bat.can_dive = randf() < float(cfg["swoop_chance"])
	bat.max_hp = 1 + int(cfg["lap"])
	bat.code_box = String(cfg["lang_name"])
	bat.target = player
	bat.position = Vector2(-40.0 if randf() > 0.5 else Rules.WORLD_W + 40.0, 200.0)
	add_child(bat)
	bat.killed.connect(_on_bat_killed)
	bat.wounded.connect(_on_bat_wounded)

func spawn_boss() -> void:
	var bat: Bat = BAT_SCENE.instantiate()
	bat.is_boss = true
	bat.max_hp = int(cfg["boss_hp"])
	bat.speed = float(cfg["boss_speed"])
	bat.fire_interval = float(cfg["boss_fire_interval"])
	bat.altitude_min = 120.0
	bat.altitude_max = 190.0
	bat.code_box = "Boss"
	bat.target = player
	bat.position = Vector2(Rules.WORLD_W / 2.0, 150.0)
	add_child(bat)
	bat.killed.connect(_on_bat_killed)
	bat.boss_engaged.connect(_on_boss_engaged)
	bat.fired.connect(_on_boss_fired)
	boss = bat
	Sfx.play("boss")
	toasts.push("Syntax Overlord - every correct answer is a wound", "bad")

func _clear_enemies() -> void:
	for child in get_children():
		if child is Bat or child is Bug:
			child.queue_free()

func _live_bats() -> int:
	var count := 0
	for child in get_children():
		if child is Bat:
			count += 1
	return count

# ------------------------------------------------------------- bat callbacks

func _on_bat_wounded(bat: Bat) -> void:
	Sfx.play("hit")
	Fx.burst(self, bat.position, Color("#e8eef7"), 4, 50)

func _on_bat_killed(bat: Bat, code_box: String) -> void:
	if bat.is_boss:
		# A boss death is handled by _on_quiz_continue(), which knows whether the
		# killing blow was a correct answer.
		return
	kills += 1
	Sfx.play("absorb")
	Fx.burst(self, bat.position, UiKit.GOLD, 12, 100)
	if kills <= int(cfg["checkpoints"]):
		toasts.push("CODE ABSORBED", "good")
		popups.push("CODE ABSORBED", bat.position - Vector2(0, 24), Color("#5fe08a"))
		checkpoint.request_checkpoint("bat", code_box)
	else:
		toasts.push("Free kill - checkpoint target already met", "")

func _on_boss_engaged(bat: Bat) -> void:
	if boss_pending:
		return
	bat.invulnerable = 1.4
	boss_pending = true
	checkpoint.request_checkpoint("boss", bat.code_box)

func _on_boss_fired(_bat: Bat, origin: Vector2, _speed: float) -> void:
	var shots := 3 if int(cfg["module"]) >= 4 else 1
	for i in shots:
		var spread := (float(i) - float(shots - 1) / 2.0) * 0.16
		var aim := Vector2(player.position.x, Rules.GROUND_Y - 24.0)
		var angle := (aim - origin).angle() + spread
		var bug: Bug = BUG_SCENE.instantiate()
		add_child(bug)
		bug.launch(origin, Vector2.RIGHT.rotated(angle), float(cfg["bug_speed"]))

# ------------------------------------------------------------ checkpoint flow

func _on_checkpoint_opened(question: Dictionary, kind: String) -> void:
	mode = Mode.QUIZ
	var preview := Rules.points_for_correct(
		int(question["difficulty"]), checkpoint.streak + 1, UpgradeSystem.point_bonus()
	)
	quiz.show_question(
		question,
		"Boss checkpoint" if kind == "boss" else "Checkpoint",
		"+%d pts" % preview
	)

func _on_checkpoint_resolved(result: Dictionary) -> void:
	Sfx.play("correct" if bool(result["correct"]) else "wrong")
	_apply_answer(result)
	quiz.show_result(result)
	_refresh_hud()

func _on_answer_selected(index: int) -> void:
	checkpoint.submit(index)

func _on_quiz_continue() -> void:
	quiz.set_open(false)
	var correct := bool(checkpoint.last_result.get("correct", false))
	var boss_was_pending := boss_pending and boss != null
	boss_pending = false

	var defeated := false
	if boss_was_pending:
		if correct:
			Fx.burst(self, boss.position, Color("#b98bff"), 14, 110)
			popups.push("%d HP LEFT" % maxi(1, boss.hp - 1), boss.position - Vector2(0, 54), Color("#e0455f"))
			defeated = boss.lose_health()
		else:
			# Grace period: the same miss is not asked again instantly.
			boss.invulnerable = 1.6

	checkpoint.close()

	if defeated:
		boss = null
		_on_level_cleared()
		return

	if boss_was_pending and boss != null:
		if correct:
			toasts.push("%d HP LEFT" % boss.hp, "bad")
		else:
			toasts.push("No wound - read the explanation, then strike again", "")

	mode = Mode.PLAY
	_refresh_hud()

## One HUD refresh, plus the toast strip staying clear of the readout.
func _refresh_hud() -> void:
	hud.refresh(_hud_data())
	toasts.place_below(hud.content_bottom() + 8.0)

## Port of applyAnswer() in js/main.js: fold the graded answer into the save.
func _apply_answer(result: Dictionary) -> void:
	var question: Dictionary = result["question"]
	var lang := String(question["lang"])
	var mastery: Dictionary = progress["mastery"]
	if not mastery.has(lang):
		mastery[lang] = {"correct": 0, "wrong": 0}
	var record: Dictionary = mastery[lang]

	if bool(result["correct"]):
		progress["correct"] = int(progress["correct"]) + 1
		progress["streak"] = int(result["streak"])
		progress["bestStreak"] = maxi(int(progress["bestStreak"]), int(result["streak"]))
		progress["points"] = int(progress["points"]) + int(result["points"])
		run_points += int(result["points"])
		(progress["answered"] as Dictionary)[String(question["id"])] = true
		record["correct"] = int(record["correct"]) + 1
		var upgrade: Dictionary = result["upgrade"]
		if not upgrade.is_empty():
			(progress["upgrades"] as Dictionary)[String(upgrade["id"])] = int(upgrade["level"])
	else:
		progress["wrong"] = int(progress["wrong"]) + 1
		progress["streak"] = 0
		record["wrong"] = int(record["wrong"]) + 1

	progress["mastery"] = mastery
	_check_badges()
	_save()

func _on_level_cleared() -> void:
	level_complete = true
	mode = Mode.BANNER
	hud.set_visible_hud(false)
	Sfx.play("clear")

	var module := int(cfg["module"])
	progress["modulesCleared"] = int(progress["modulesCleared"]) + 1
	progress["bossesDefeated"] = int(progress["bossesDefeated"]) + 1
	var bonus := Rules.boss_points(module) + Rules.level_clear_points(module, checkpoint.perfect)
	progress["points"] = int(progress["points"]) + bonus
	run_points += bonus
	progress["module"] = mini(99, module + 1)
	progress["highestModule"] = maxi(int(progress["highestModule"]), int(progress["module"]))
	_check_badges()
	_save()

	var attempts := checkpoint.correct_answers + checkpoint.wrong_answers
	var next_cfg := Rules.level_config(int(progress["module"]))
	banner.show_banner({
		"title": "Module %d cleared" % module,
		"body": "Every %s checkpoint absorbed and the Syntax Overlord defeated.%s Next up: %s - %s." % [
			String(cfg["lang_name"]),
			" Flawless run - no wrong answers!" if checkpoint.perfect else "",
			String(next_cfg["lang_name"]),
			String(Rules.language(String(next_cfg["lang"])).get("blurb", "")),
		],
		"stats": [
			["Checkpoints cleared", "%d/%d" % [checkpoint.correct_answers, attempts]],
			["Accuracy this module", "%d%%" % checkpoint.accuracy()],
			["Best streak", checkpoint.best_streak],
			["Clear bonus", "+%d pts" % bonus],
			["Total points", progress["points"]],
		],
		"primary": "Start Module %d" % int(progress["module"]),
		"secondary": "Back to lobby",
	})

func _on_player_died() -> void:
	if mode == Mode.BANNER:
		return
	_save()
	mode = Mode.BANNER
	hud.set_visible_hud(false)
	var total := int(cfg["checkpoints"])
	# The buffs are permanent: the banner spells them out so a retry never looks
	# like it wiped the run's rewards.
	var kept := UpgradeSystem.summary()
	var kept_text := "None yet" if kept.is_empty() else ", ".join(PackedStringArray(kept))
	banner.show_banner({
		"title": "The bats won this round",
		"body": "You cleared %d of %d checkpoints in the %s module. Your points, badges, mastery and buffs are all saved - retry and keep them." % [
			kills, total, String(cfg["lang_name"]),
		],
		"stats": [
			["Checkpoints cleared", "%d/%d" % [kills, total]],
			["Correct answers", checkpoint.correct_answers],
			["Wrong answers", checkpoint.wrong_answers],
			["Points this run", run_points],
			["Total points", progress["points"]],
			["Buffs kept", kept_text],
		],
		"primary": "Retry this module",
		"secondary": "Back to lobby",
	})

# ------------------------------------------------------------ player feedback

func _on_shield_used(charges: int) -> void:
	Sfx.play("shield")
	Fx.burst(self, player.position + Vector2(0, -10), Color("#6bb8ff"), 10, 90)
	toasts.push("Shield absorbed the hit (%d left)" % charges, "")

func _on_took_damage(hearts_left: int) -> void:
	Sfx.play("hurt")
	Fx.burst(self, player.position + Vector2(0, -20), Color("#ef6a5a"), 10, 90)
	toasts.push("Heart lost (%d left)" % hearts_left, "bad")

func _on_revived(hearts_left: int) -> void:
	Sfx.play("badge")
	Fx.burst(self, player.position, Color("#f2c14e"), 16, 120)
	toasts.push("The Elder Headdress pulls you back up (%d heart)" % hearts_left, "good")

func _on_spear_thrown(_spear: Spear) -> void:
	Sfx.play("throw")

func _on_move_input(direction: float) -> void:
	player.touch_dir = direction

func _on_throw_held(held: bool) -> void:
	player.hold_throw = held

# ------------------------------------------------------------ lobby and shop

func _on_start_pressed() -> void:
	Sfx.play("click")
	start_module(int(progress["module"]))

func _on_hero_selected(hero: String) -> void:
	progress["hero"] = "girl" if hero == "girl" else "boy"
	_save()
	player.apply_loadout(progress)
	lobby.render(progress)

func _on_renamed(new_name: String) -> void:
	var trimmed := new_name.substr(0, 12)
	progress["name"] = trimmed if trimmed != "" else "Bagani"
	_save()

func _on_buy(item_id: String) -> void:
	var outcome := Rules.buy_item(progress, item_id)
	if not bool(outcome["ok"]):
		toasts.push("Can't buy: %s" % String(outcome["reason"]), "bad")
	else:
		progress = outcome["progress"]
		UpgradeSystem.recompute(progress)
		_check_badges()
		_save()
		toasts.push("Bought %s" % String((outcome["item"] as Dictionary)["name"]), "good")
	shop.render(progress)

func _on_equip(item_id: String) -> void:
	var outcome := Rules.equip_item(progress, item_id)
	if bool(outcome["ok"]):
		progress = outcome["progress"]
		UpgradeSystem.recompute(progress)
		UpgradeSystem.spear_design = String((progress["equipped"] as Dictionary).get("spear", "spear-bamboo")).replace("spear-", "")
		player.apply_loadout(progress)
		ambient.set_effect(String((progress["equipped"] as Dictionary).get("effect", "effect-none")))
		_save()
		toasts.push("Equipped %s" % String((Rules.shop_item(item_id) as Dictionary).get("name", item_id)), "good")
	shop.render(progress)

# ----------------------------------------------------------------- pause menu

func _set_paused(value: bool) -> void:
	if value:
		if mode != Mode.PLAY:
			return
		mode = Mode.PAUSED
		get_tree().paused = true
		Sfx.play("click")
		pause_screen.render(_hud_data())
		pause_screen.open()
	else:
		if mode != Mode.PAUSED:
			return
		pause_screen.close()
		get_tree().paused = false
		mode = Mode.PLAY

func _on_resume() -> void:
	Sfx.play("click")
	_set_paused(false)

func _on_restart() -> void:
	_set_paused(false)
	start_module(int(progress["module"]))

func _on_pause_lobby() -> void:
	_set_paused(false)
	to_lobby()

## The on-screen pause button. It shares _set_paused() with Esc and P, so the
## touch build and the keyboard build cannot drift apart.
func _on_pause_button() -> void:
	Sfx.play("click")
	_set_paused(true)

func _on_sound_toggled() -> void:
	progress["sound"] = not bool(progress.get("sound", true))
	Sfx.set_enabled(bool(progress["sound"]))
	hud.set_sound_enabled(Sfx.enabled)
	_save()
	if Sfx.enabled:
		Sfx.play("click")
	toasts.push("Sound on" if Sfx.enabled else "Sound muted", "")

func _on_banner_primary() -> void:
	banner.close()
	start_module(int(progress["module"]))

func _on_banner_secondary() -> void:
	banner.close()
	to_lobby()

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode in [KEY_ESCAPE, KEY_P]:
		if mode == Mode.PLAY:
			_set_paused(true)
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ plumbing

func _check_badges() -> void:
	var owned: Array = progress["badges"]
	for id in Rules.new_badges(progress, owned):
		owned.append(id)
		var badge := Rules.badge_by_id(String(id))
		if not badge.is_empty():
			Sfx.play("badge")
			toasts.push("Badge unlocked - %s" % String(badge["name"]), "good")

func _save() -> void:
	progress["playSeconds"] = play_seconds
	Save.save_progress(progress)

func _hud_data() -> Dictionary:
	return {
		"hearts": player.hearts,
		"max_hearts": player.max_hearts,
		"shield": player.shield,
		"module": int(cfg.get("module", 1)),
		"lang_name": String(cfg.get("lang_name", "")),
		"points": int(progress.get("points", 0)),
		"run_points": run_points,
		"streak": checkpoint.streak,
		"cleared": kills,
		"total": int(cfg.get("checkpoints", 0)),
		"boss": boss != null,
		"boss_hp": boss.hp if boss != null else 0,
		"boss_max_hp": boss.max_hp if boss != null else 0,
		"mastery": Rules.mastery_percent(progress, String(cfg.get("lang", "html"))),
		"chips": UpgradeSystem.summary(),
	}

## The vertical fade from renderer.js, as a gradient texture on one overlay.
func _vignette_texture() -> GradientTexture2D:
	var shade := Color(4.0 / 255.0, 7.0 / 255.0, 15.0 / 255.0, 0.34)
	var clear := Color(4.0 / 255.0, 7.0 / 255.0, 15.0 / 255.0, 0.0)
	var deep := Color(4.0 / 255.0, 7.0 / 255.0, 15.0 / 255.0, 0.38)
	var gradient := Gradient.new()
	gradient.set_color(0, shade)
	gradient.set_color(1, deep)
	gradient.add_point(0.22, clear)
	gradient.add_point(0.82, clear)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 4
	texture.height = 128
	return texture

func _exit_tree() -> void:
	Save.save_progress(progress)
