extends Node3D

# Football Stars 3D — playable prototype.
# All pitch/player geometry is procedural so the project runs without external assets.

const FIELD_W := 58.0
const FIELD_L := 94.0
const BALL_R := 0.38
const PLAYER_SPEED := 7.2
const SPRINT_SPEED := 10.0
const GRAVITY := 18.0
const AI_PRESS_OFFSET := 0.9
const AI_COVER_OFFSET := 2.8

var players: Array[Dictionary] = []
var controlled := 0
var ball_pos := Vector3(0, BALL_R, 0)
var ball_vel := Vector3.ZERO
var score_home := 0
var score_away := 0
var match_seconds := 0.0
var shoot_cooldown := 0.0
var pass_cooldown := 0.0
var ai_action_cooldown := 0.0
var goalkeeper_save_cooldown := 0.0
var celebration_timer := 0.0
var celebration_team := -1
var ball_curve_strength := 0.0
var ball_curve_time := 0.0
var skill_cooldown := 0.0
var feint_cooldown := 0.0
var tackle_cooldown := 0.0
var skill_boost_timer := 0.0
var skill_direction := Vector3.FORWARD
var sprinting := false
var move_input := Vector2.ZERO
var action_text := "ابدأ المباراة"
var camera_pivot: Node3D
var camera: Camera3D
var ball_mesh: MeshInstance3D
var hud: Label
var score_label: Label
var help_label: Label
var joystick_center := Vector2(115, 600)
var joystick_active := false
var joystick_vector := Vector2.ZERO
var screen_size := Vector2(1280, 720)
var match_started := false
var match_paused := false
var home_team_name := "نجوم الأزرق"
var away_team_name := "نجوم الأبيض"
var home_formation := "4-4-2"
var away_formation := "4-4-2"
var selected_player_number := 10
var menu_panel: PanelContainer
var menu_status: Label
var home_team_option: OptionButton
var away_team_option: OptionButton
var home_formation_option: OptionButton
var away_formation_option: OptionButton
var player_option: OptionButton
var pause_button: Button

func _ready() -> void:
    _build_world()
    _build_pitch()
    _build_players()
    _build_ball()
    _build_camera()
    _build_hud()
    _build_match_menu()
    _refresh_hud()

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.38, 0.58, 0.78)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.78, 0.86)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

func _mat(color: Color, roughness := 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.position = pos
    mesh.material_override = _mat(color)
    parent.add_child(mesh)
    return mesh

func _build_pitch() -> void:
    _box(self, Vector3(0, -0.35, 0), Vector3(FIELD_W, 0.6, FIELD_L), Color(0.07, 0.34, 0.12))
    for i in range(10):
        var stripe_color = Color(0.10, 0.43, 0.16) if i % 2 == 0 else Color(0.08, 0.38, 0.13)
        _box(self, Vector3(0, -0.035, -FIELD_L/2 + (i + 0.5) * FIELD_L/10), Vector3(FIELD_W, 0.025, FIELD_L/10), stripe_color)
    var line_mat := _mat(Color(0.92, 0.94, 0.86))
    _line(Vector3(-FIELD_W/2, 0.02, -FIELD_L/2), Vector3(FIELD_W/2, 0.02, -FIELD_L/2), line_mat)
    _line(Vector3(-FIELD_W/2, 0.02, FIELD_L/2), Vector3(FIELD_W/2, 0.02, FIELD_L/2), line_mat)
    _line(Vector3(-FIELD_W/2, 0.02, -FIELD_L/2), Vector3(-FIELD_W/2, 0.02, FIELD_L/2), line_mat)
    _line(Vector3(FIELD_W/2, 0.02, -FIELD_L/2), Vector3(FIELD_W/2, 0.02, FIELD_L/2), line_mat)
    _line(Vector3(-FIELD_W/2, 0.02, 0), Vector3(FIELD_W/2, 0.02, 0), line_mat)
    _circle_line(Vector3(0, 0.025, 0), 9.15, line_mat)
    _box(self, Vector3(0, 0.04, -FIELD_L/2 + 16.5), Vector3(40.3, 0.025, 0.04), Color.WHITE)
    _box(self, Vector3(0, 0.04, FIELD_L/2 - 16.5), Vector3(40.3, 0.025, 0.04), Color.WHITE)
    _box(self, Vector3(0, 0.04, -FIELD_L/2 + 5.5), Vector3(18.3, 0.025, 0.04), Color.WHITE)
    _box(self, Vector3(0, 0.04, FIELD_L/2 - 5.5), Vector3(18.3, 0.025, 0.04), Color.WHITE)
    # Low-poly stands and goal frames
    for z in [-FIELD_L/2 - 5.0, FIELD_L/2 + 5.0]:
        _box(self, Vector3(0, 3.0, z), Vector3(FIELD_W + 12, 6, 2.2), Color(0.12, 0.16, 0.22))
        _box(self, Vector3(0, 6.2, z), Vector3(FIELD_W + 12, 0.35, 2.4), Color(0.72, 0.76, 0.82))
    _make_goal(-FIELD_L/2)
    _make_goal(FIELD_L/2)

func _line(a: Vector3, b: Vector3, material: Material) -> void:
    var mi := MeshInstance3D.new()
    var im := ImmediateMesh.new()
    im.surface_begin(Mesh.PRIMITIVE_LINES, material)
    im.surface_add_vertex(a)
    im.surface_add_vertex(b)
    im.surface_end()
    mi.mesh = im
    add_child(mi)

func _circle_line(center: Vector3, radius: float, material: Material) -> void:
    var im := ImmediateMesh.new()
    im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
    for i in range(49):
        var a := TAU * float(i) / 48.0
        im.surface_add_vertex(center + Vector3(cos(a) * radius, 0, sin(a) * radius))
    im.surface_end()
    var mi := MeshInstance3D.new()
    mi.mesh = im
    add_child(mi)

func _make_goal(z: float) -> void:
    var direction := -1.0 if z < 0 else 1.0
    var goal_color := Color(0.92, 0.94, 0.98)
    for x in [-3.7, 3.7]:
        _box(self, Vector3(x, 1.25, z), Vector3(0.18, 2.5, 0.18), goal_color)
    _box(self, Vector3(0, 2.5, z), Vector3(7.5, 0.18, 0.18), goal_color)
    _box(self, Vector3(0, 1.15, z + direction * 1.5), Vector3(7.3, 2.2, 0.08), Color(0.75, 0.82, 0.88, 0.22))

func _create_player(team: int, shirt: Color, number: int, pos: Vector3, keeper := false) -> Dictionary:
    var root := Node3D.new()
    root.position = pos
    add_child(root)

    # Load team-specific low-poly GLB body. Arms and legs remain procedural so
    # running, passing and shooting still animate even when the GLB has no clips.
    var model_path := "res://assets/goalkeeper.glb" if keeper else ("res://assets/player_home.glb" if team == 0 else "res://assets/player_away.glb")
    var model_instance: Node3D = null
    if ResourceLoader.exists(model_path):
        var model_resource := load(model_path)
        if model_resource is PackedScene:
            model_instance = (model_resource as PackedScene).instantiate() as Node3D
        if model_instance != null:
            model_instance.name = "GLB_Character"
            model_instance.scale = Vector3.ONE * 0.92
            root.add_child(ضmodel_instance)

    if model_instance == null:
        var body := MeshInstance3D.new()
        var capsule := CapsuleMesh.new()
        capsule.radius = 0.48 if not keeper else 0.52
        capsule.height = 1.65
        body.mesh = capsule
        body.position.y = 1.05
        body.material_override = _mat(shirt)
        root.add_child(body)
        var head := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.28
        head.mesh = sphere
        head.position = Vector3(0, 2.02, 0)
        head.material_override = _mat(Color(0.78, 0.57, 0.42))
        root.add_child(head)
        var shorts := MeshInstance3D.new()
        var short_mesh := BoxMesh.new()
        short_mesh.size = Vector3(0.78, 0.35, 0.48)
        shorts.mesh = short_mesh
        shorts.position.y = 0.52
        shorts.material_override = _mat(Color(0.06, 0.09, 0.16) if team == 0 else Color(0.92, 0.92, 0.92))
        root.add_child(shorts)

    # Lightweight procedural rig: pivot nodes let the limbs swing without a skeletal asset.
    var arms: Array[Node3D] = []
    var legs: Array[Node3D] = []
    var shorts_color := _mat(Color(0.06, 0.09, 0.16) if team == 0 else Color(0.92, 0.92, 0.92))
    for side in [-1.0, 1.0]:
        var arm_pivot := Node3D.new()
        arm_pivot.position = Vector3(side * 0.53, 1.43, 0)
        root.add_child(arm_pivot)
        var arm := MeshInstance3D.new()
        var arm_mesh := CapsuleMesh.new()
        arm_mesh.radius = 0.15
        arm_mesh.height = 0.86
        arm.mesh = arm_mesh
        arm.position.y = -0.39
        arm.material_override = _mat(shirt.darkened(0.08))
        arm_pivot.add_child(arm)
        arms.append(arm_pivot)

        var leg_pivot := Node3D.new()
        leg_pivot.position = Vector3(side * 0.22, 0.58, 0)
        root.add_child(leg_pivot)
        var leg := MeshInstance3D.new()
        var leg_mesh := CapsuleMesh.new()
        leg_mesh.radius = 0.19
        leg_mesh.height = 0.92
        leg.mesh = leg_mesh
        leg.position.y = -0.43
        leg.material_override = shorts_color
        leg_pivot.add_child(leg)
        legs.append(leg_pivot)

    var model_animator: AnimationPlayer = _find_animation_player(model_instance) if model_instance != null else null
    return {"node": root, "team": team, "number": number, "home": pos, "keeper": keeper,
        "velocity": Vector3.ZERO, "arms": arms, "legs": legs, "anim_phase": 0.0,
        "anim_speed": 0.0, "action_anim": "", "action_timer": 0.0,
        "model_animator": model_animator, "model_anim_name": "",
        "model_instance": model_instance, "save_direction": 0.0,
        "skill_profile": ("ronaldo" if number == 7 else ("messi" if number == 10 else "standard")),
        "spin_timer": 0.0, "spin_direction": 1.0}

func _build_players() -> void:
    players.clear()
    var home_color := Color(0.05, 0.18, 0.82)
    var away_color := Color(0.88, 0.88, 0.84)
    var home_positions = [
        Vector3(0,0,29), Vector3(-19,0,17), Vector3(-7,0,18), Vector3(7,0,18), Vector3(19,0,17),
        Vector3(-19,0,2), Vector3(-7,0,3), Vector3(7,0,3), Vector3(19,0,2),
        Vector3(-8,0,-13), Vector3(8,0,-13)
    ]
    var away_positions = [
        Vector3(0,0,-29), Vector3(-19,0,-17), Vector3(-7,0,-18), Vector3(7,0,-18), Vector3(19,0,-17),
        Vector3(-19,0,-2), Vector3(-7,0,-3), Vector3(7,0,-3), Vector3(19,0,-2),
        Vector3(-8,0,13), Vector3(8,0,13)
    ]
    for i in range(11):
        players.append(_create_player(0, home_color, i + 1, home_positions[i], i == 0))
    for i in range(11):
        players.append(_create_player(1, away_color, i + 1, away_positions[i], i == 0))
    controlled = 9

func _build_ball() -> void:
    ball_mesh = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = BALL_R
    ball_mesh.mesh = sphere
    ball_mesh.material_override = _mat(Color(0.96, 0.96, 0.92), 0.45)
    add_child(ball_mesh)
    ball_mesh.position = ball_pos

func _build_camera() -> void:
    camera_pivot = Node3D.new()
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 27, 35)
    camera.rotation_degrees = Vector3(-34, 0, 0)
    camera.current = true
    camera.fov = 54
    camera_pivot.add_child(camera)
    camera_pivot.position = Vector3(0, 0, 0)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    score_label = Label.new()
    score_label.position = Vector2(24, 18)
    score_label.add_theme_font_size_override("font_size", 28)
    score_label.add_theme_color_override("font_color", Color.WHITE)
    score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    score_label.add_theme_constant_override("shadow_offset_x", 2)
    score_label.add_theme_constant_override("shadow_offset_y", 2)
    layer.add_child(score_label)
    hud = Label.new()
    hud.position = Vector2(24, 64)
    hud.add_theme_font_size_override("font_size", 18)
    hud.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(hud)
    help_label = Label.new()
    help_label.position = Vector2(20, 660)
    help_label.text = "تحريك WASD • تمرير K • تسديد J • مراوغة E • خدعة Q • افتكاك C • 360 R • مهارة T • مقوس L • بعيد U"
    help_label.add_theme_font_size_override("font_size", 16)
    help_label.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(help_label)
    _make_touch_button(layer, "تمرير", Vector2(1080, 565), KEY_K)
    _make_touch_button(layer, "تسديد", Vector2(1160, 475), KEY_J)
    _make_touch_button(layer, "تبديل", Vector2(970, 650), KEY_TAB)
    _make_touch_button(layer, "ركض", Vector2(1155, 650), KEY_SHIFT)
    _make_touch_button(layer, "360°", Vector2(850, 260), KEY_R)
    _make_touch_button(layer, "رونالدو/ميسي", Vector2(950, 260), KEY_T)
    _make_touch_button(layer, "مقوس", Vector2(1050, 260), KEY_L)
    _make_touch_button(layer, "بعيد", Vector2(1150, 260), KEY_U)
    _make_touch_button(layer, "احتفال", Vector2(850, 340), KEY_H)
    _make_touch_button(layer, "مراوغة", Vector2(1060, 385), KEY_E)
    _make_touch_button(layer, "خدعة", Vector2(950, 475), KEY_Q)
    _make_touch_button(layer, "افتكاك", Vector2(850, 565), KEY_C)
    _make_touch_button(layer, "إيقاف", Vector2(25, 110), KEY_P)

func _build_match_menu() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 5
    add_child(layer)
    menu_panel = PanelContainer.new()
    menu_panel.position = Vector2(350, 62)
    menu_panel.size = Vector2(580, 590)
    menu_panel.custom_minimum_size = Vector2(580, 590)
    layer.add_child(menu_panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    menu_panel.add_child(column)

    var title := Label.new()
    title.text = "FOOTBALL STARS 3D — إعداد المباراة"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 27)
    column.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "اختر الفريقين والتشكيلة واللاعب الذي ستتحكم به"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(subtitle)

    home_team_option = _add_menu_option(column, "فريقك", ["نجوم الأزرق", "نجوم الصقور", "نجوم المدينة"], 0)
    away_team_option = _add_menu_option(column, "الفريق المنافس", ["نجوم الأبيض", "نجوم الأسود", "نجوم الأطلس"], 0)
    home_formation_option = _add_menu_option(column, "تشكيلة فريقك", ["4-4-2", "4-3-3", "3-5-2"], 0)
    away_formation_option = _add_menu_option(column, "تشكيلة المنافس", ["4-4-2", "4-3-3", "3-5-2"], 0)
    player_option = _add_menu_option(column, "اللاعب الذي ستتحكم به", [
        "10 — صانع الألعاب (مهارة ميسي)",
        "7 — الجناح (مهارة رونالدو)",
        "9 — المهاجم",
        "8 — لاعب الوسط",
        "6 — محور الارتكاز",
        "2 — الظهير الأيمن",
        "3 — الظهير الأيسر"
    ], 0)
    var note := Label.new()
    note.text = "المباراة: 90 دقيقة افتراضية • تحكم لمس • كاميرا تلفزيونية"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(note)
    menu_status = Label.new()
    menu_status.text = "اختر إعداداتك ثم اضغط بدء المباراة"
    menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(menu_status)
    var start := Button.new()
    start.text = "بدء المباراة"
    start.custom_minimum_size = Vector2(0, 58)
    start.add_theme_font_size_override("font_size", 24)
    start.pressed.connect(_start_match_from_menu)
    column.add_child(start)
    var tip := Label.new()
    tip.text = "المهارات: E مراوغة • R دوران • T مهارة خاصة • L مقوس • U بعيد"
    tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(tip)

func _add_menu_option(parent: VBoxContainer, caption: String, choices: Array, selected: int) -> OptionButton:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var label := Label.new()
    label.text = caption
    label.custom_minimum_size = Vector2(205, 34)
    row.add_child(label)
    var option := OptionButton.new()
    option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for choice in choices:
        option.add_item(String(choice))
    option.select(selected)
    row.add_child(option)
    return option

func _start_match_from_menu() -> void:
    home_team_name = home_team_option.get_item_text(home_team_option.selected)
    away_team_name = away_team_option.get_item_text(away_team_option.selected)
    home_formation = home_formation_option.get_item_text(home_formation_option.selected)
    away_formation = away_formation_option.get_item_text(away_formation_option.selected)
    var player_choice := player_option.selected
    var jersey_numbers := [10, 7, 9, 8, 6, 2, 3]
    selected_player_number = jersey_numbers[player_choice]
    _apply_formation(0, home_formation)
    _apply_formation(1, away_formation)
    controlled = selected_player_number - 1
    match_started = true
    match_paused = false
    menu_panel.visible = false
    action_text = "انطلقت المباراة — بالتوفيق!"
    _refresh_hud()

func _apply_formation(team: int, formation: String) -> void:
    var sign_z := 1.0 if team == 0 else -1.0
    var positions: Array[Vector3] = [Vector3(0, 0, 29 * sign_z)]
    var defenders: Array[float] = []
    var midfielders: Array[float] = []
    var forwards: Array[float] = []
    if formation == "4-3-3":
        defenders = [-19.0, -7.0, 7.0, 19.0]
        midfielders = [-12.0, 0.0, 12.0]
        forwards = [-17.0, 0.0, 17.0]
    elif formation == "3-5-2":
        defenders = [-14.0, 0.0, 14.0]
        midfielders = [-21.0, -10.0, 0.0, 10.0, 21.0]
        forwards = [-8.0, 8.0]
    else:
        defenders = [-19.0, -7.0, 7.0, 19.0]
        midfielders = [-19.0, -7.0, 7.0, 19.0]
        forwards = [-8.0, 8.0]
    for x in defenders:
        positions.append(Vector3(x, 0, 17 * sign_z))
    for x in midfielders:
        positions.append(Vector3(x, 0, 3 * sign_z))
    for x in forwards:
        positions.append(Vector3(x, 0, -13 * sign_z))
    while positions.size() < 11:
        positions.append(Vector3(0, 0, -8 * sign_z))
    for i in range(11):
        var index := team * 11 + i
        var player: Dictionary = players[index]
        player.home = positions[i]
        var node: Node3D = player.node
        node.position = positions[i]
        players[index] = player

func _make_touch_button(layer: CanvasLayer, caption: String, pos: Vector2, keycode: Key) -> void:
    var b := Button.new()
    b.text = caption
    b.position = pos
    b.size = Vector2(92, 68)
    b.add_theme_font_size_override("font_size", 20)
    b.modulate = Color(0.9, 0.95, 1, 0.88)
    b.pressed.connect(func(): _perform_action(keycode))
    layer.add_child(b)

func _refresh_hud() -> void:
    score_label.text = "%s  %d - %d  %s     %02d:%02d" % [home_team_name, score_home, score_away, away_team_name, int(match_seconds) / 60, int(match_seconds) % 60]
    hud.text = "تشكيلتك %s  |  المنافس %s  |  " % [home_formation, away_formation] + action_text

func _physics_process(delta: float) -> void:
    if not match_started or match_paused:
        return
    match_seconds += delta
    shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
    pass_cooldown = maxf(0.0, pass_cooldown - delta)
    ai_action_cooldown = maxf(0.0, ai_action_cooldown - delta)
    goalkeeper_save_cooldown = maxf(0.0, goalkeeper_save_cooldown - delta)
    celebration_timer = maxf(0.0, celebration_timer - delta)
    ball_curve_time = maxf(0.0, ball_curve_time - delta)
    skill_cooldown = maxf(0.0, skill_cooldown - delta)
    feint_cooldown = maxf(0.0, feint_cooldown - delta)
    tackle_cooldown = maxf(0.0, tackle_cooldown - delta)
    skill_boost_timer = maxf(0.0, skill_boost_timer - delta)
    _read_movement()
    _update_players(delta)
    _update_ball(delta)
    _update_camera(delta)
    _refresh_hud()

func _read_movement() -> void:
    var x := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
    var y := Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    if joystick_active:
        x = joystick_vector.x
        y = joystick_vector.y
    move_input = Vector2(x, y).limit_length(1.0)
    sprinting = Input.is_key_pressed(KEY_SHIFT)

func _update_players(delta: float) -> void:
    var ball_ground := Vector3(ball_pos.x, 0, ball_pos.z)
    var blue_chaser := _nearest_player_index(0, ball_ground)
    var white_chaser := _nearest_player_index(1, ball_ground)
    var blue_cover := _second_nearest_player_index(0, ball_ground, blue_chaser)
    var white_cover := _second_nearest_player_index(1, ball_ground, white_chaser)
    for i in range(players.size()):
        var p: Dictionary = players[i]
        var node: Node3D = p.node
        var previous_position: Vector3 = node.position
        var team: int = int(p.team)
        var target: Vector3 = p.home
        var keeper: bool = bool(p.keeper)
        var attacking_direction := -1.0 if team == 0 else 1.0
        var primary_chaser := blue_chaser if team == 0 else white_chaser
        var cover_player := blue_cover if team == 0 else white_cover

        if i == controlled:
            var speed := SPRINT_SPEED if sprinting else PLAYER_SPEED
            if skill_boost_timer > 0.0:
                speed *= 1.32
            var desired := Vector3(move_input.x, 0, move_input.y) * speed
            node.position += desired * delta
            node.position.x = clampf(node.position.x, -FIELD_W/2 + 1.0, FIELD_W/2 - 1.0)
            node.position.z = clampf(node.position.z, -FIELD_L/2 + 1.0, FIELD_L/2 - 1.0)
            if desired.length() > 0.1:
                node.look_at(node.position + desired, Vector3.UP)
            if float(p.skill_timer) > 0.0:
                p.skill_timer = maxf(0.0, float(p.skill_timer) - delta)
                node.rotate_y(float(p.spin_direction) * delta * 7.5)
            if node.position.distance_to(ball_ground) < 2.0 and ball_pos.y < 1.7:
                ball_vel.x = lerpf(ball_vel.x, desired.x * (0.55 if skill_boost_timer <= 0.0 else 0.82), 0.16)
                ball_vel.z = lerpf(ball_vel.z, desired.z * (0.55 if skill_boost_timer <= 0.0 else 0.82), 0.16)
        elif keeper:
            # Goalkeeper anticipates the ball's crossing point instead of only following its current X.
            var time_to_line := absf(node.position.z - ball_pos.z) / maxf(absf(ball_vel.z), 2.0)
            var predicted_x := ball_pos.x + ball_vel.x * minf(time_to_line, 0.7)
            target.x = clampf(lerpf(ball_pos.x, predicted_x, 0.55) * 0.68, -3.2, 3.2)
            target.z = p.home.z + clampf((ball_pos.z - p.home.z) * 0.035, -2.0, 2.0)
        elif i == primary_chaser:
            # The first defender closes the ball from the goal side, reducing easy forward turns.
            target = ball_ground + Vector3(0, 0, -attacking_direction * AI_PRESS_OFFSET)
        elif i == cover_player:
            # A second defender blocks the nearest central passing lane while keeping a safe gap.
            target = ball_ground + Vector3(-ball_pos.x * 0.08, 0, -attacking_direction * AI_COVER_OFFSET)
        else:
            # Shift the team as a compact block while preserving width and staggered forward runs.
            var support_x := clampf(ball_pos.x * 0.18, -5.0, 5.0)
            var support_z := clampf(ball_pos.z * 0.15, -6.0, 6.0)
            target = p.home + Vector3(support_x, 0, support_z)
            var role_index := i % 11
            if role_index >= 5 and role_index <= 8:
                target.x = lerpf(target.x, ball_pos.x, 0.16)
            if role_index >= 9:
                target.z += attacking_direction * clampf(absf(ball_pos.z - p.home.z) * 0.10, 0.0, 4.0)
                target.x = lerpf(target.x, ball_pos.x, 0.12)
            if role_index >= 1 and role_index <= 4:
                var ball_in_own_half := ball_pos.z * -attacking_direction > 0.0
                if ball_in_own_half:
                    target.z = lerpf(target.z, p.home.z, 0.28)
                var opponent_index := _nearest_opponent_index(team, node.position)
                if opponent_index >= 0:
                    var opponent: Node3D = players[opponent_index].node
                    if opponent.position.distance_to(node.position) < 13.0:
                        var mark_point := opponent.position + Vector3(0, 0, attacking_direction * 1.8)
                        target = target.lerp(mark_point, 0.18)
            if team == 0 and ball_pos.z < 4.0:
                target.z -= 1.5
            elif team == 1 and ball_pos.z > -4.0:
                target.z += 1.5

        if i != controlled:
            var diff := target - node.position
            diff.y = 0
            var max_speed := 6.0 if team == 0 else 6.4
            if keeper:
                max_speed = 4.8
            elif i == primary_chaser:
                max_speed = 7.0
            elif i == cover_player:
                max_speed = 6.6
            if diff.length() > 0.18:
                node.position += diff.normalized() * minf(diff.length(), max_speed * delta)
                node.look_at(node.position + diff.normalized(), Vector3.UP)

        # Opponent decision: shoot only with a useful angle; otherwise find a safer forward pass.
        if team == 1 and i == white_chaser and ai_action_cooldown <= 0.0 and node.position.distance_to(ball_ground) < 1.7 and ball_pos.y < 1.35:
            var away_goal := Vector3(0, 0, FIELD_L / 2.0)
            var shot_direction := away_goal - ball_ground
            shot_direction.y = 0
            var can_shoot := ball_pos.z > 19.0 or node.position.distance_to(away_goal) < 23.0
            if can_shoot and _shot_lane_clear(ball_ground, away_goal, 1):
                ball_vel = shot_direction.normalized() * 16.5 + Vector3(0, 3.4, 0)
                p.action_anim = "shoot"
                p.action_timer = 0.32
                action_text = "الخصم يسدد!"
            else:
                var receiver_index := _best_pass_target_for_team(node.position, 1, i)
                if receiver_index >= 0:
                    var receiver: Node3D = players[receiver_index].node
                    var receiver_velocity: Vector3 = players[receiver_index].velocity
                    var pass_target := receiver.position + receiver_velocity * 0.22
                    var pass_direction := pass_target - node.position
                    pass_direction.y = 0
                    ball_vel = pass_direction.normalized() * 13.8 + Vector3(0, 1.7, 0)
                    action_text = "الخصم يمرر إلى زميله"
                else:
                    ball_vel = Vector3(0, 1.0, 5.5)
                    action_text = "الخصم يتقدم بالكرة"
                p.action_anim = "pass"
                p.action_timer = 0.24
            ai_action_cooldown = 1.05

        var actual_velocity := (node.position - previous_position) / maxf(delta, 0.001)
        p.velocity = actual_velocity
        p.anim_speed = actual_velocity.length()
        _animate_player(p, delta)
        players[i] = p

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _play_model_animation(p: Dictionary, requested: String) -> void:
    var animator: AnimationPlayer = p.get("model_animator")
    if animator == null:
        return
    var aliases := {
        "idle": ["idle", "standing", "stand"],
        "run": ["run", "running", "jog"],
        "sprint": ["sprint", "run_fast", "running_fast"],
        "shoot": ["shoot", "kick", "shot"],
        "pass": ["pass", "passing"],
        "save": ["save", "dive", "goalkeeper_save"],
        "dribble": ["dribble", "dribbling", "skill_move"],
        "feint": ["feint", "body_feint", "side_step"],
        "tackle": ["tackle", "sliding_tackle", "steal"],
        "celebrate": ["celebrate", "celebration", "goal_celebration"],
        "roulette": ["roulette", "spin", "360_dribble"],
        "messi_dribble": ["messi_dribble", "close_control", "dribble"],
        "ronaldo_stepover": ["ronaldo_stepover", "step_over", "skill_move"]
    }
    var candidates: Array = aliases.get(requested, [requested])
    var available := animator.get_animation_list()
    for candidate in candidates:
        for animation_name in available:
            if String(animation_name).to_lower() == String(candidate).to_lower():
                if String(p.get("model_anim_name", "")) != String(animation_name):
                    animator.play(String(animation_name))
                    p["model_anim_name"] = String(animation_name)
                return

func _animate_player(p: Dictionary, delta: float) -> void:
    var speed: float = float(p.anim_speed)
    if p.get("model_animator") != null:
        var action_timer_model: float = maxf(0.0, float(p.action_timer) - delta)
        p.action_timer = action_timer_model
        var requested := "idle"
        if action_timer_model > 0.0 and String(p.action_anim) in ["shoot", "pass", "save", "dribble", "feint", "tackle", "celebrate", "roulette", "messi_dribble", "ronaldo_stepover"]:
            requested = String(p.action_anim)
        elif speed > 7.5:
            requested = "sprint"
        elif speed > 0.35:
            requested = "run"
        _play_model_animation(p, requested)
        return
    var phase: float = float(p.anim_phase)
    var moving := speed > 0.35
    var sprinting_now := speed > 7.5
    var model: Node3D = p.get("model_instance")
    var action_timer: float = maxf(0.0, float(p.action_timer) - delta)
    p.action_timer = action_timer
    var action_name := String(p.action_anim)
    var is_dribbling: bool = p.node.position.distance_to(Vector3(ball_pos.x, 0.0, ball_pos.z)) < 1.9 and ball_pos.y < 1.5
    var body_bob := (0.035 if sprinting_now else 0.018) * sin(phase * 2.0) if moving else 0.0
    if model != null:
        model.position.y = body_bob
        model.position.x = 0.0
        model.rotation = Vector3.ZERO
        if moving:
            model.rotation.x = -0.10 if sprinting_now else (-0.065 if is_dribbling else -0.025)
        if action_timer > 0.0 and action_name == "shoot":
            model.rotation.x = -0.24 * (action_timer / 0.32)
        elif action_timer > 0.0 and action_name == "pass":
            model.rotation.z = -0.10 * (action_timer / 0.24)
        elif action_timer > 0.0 and action_name == "dribble":
            model.rotation.z = 0.16 * sin((1.0 - action_timer / 0.48) * PI)
            model.rotation.x = -0.14
        elif action_timer > 0.0 and action_name == "feint":
            model.rotation.z = 0.28 * sin((1.0 - action_timer / 0.36) * PI)
        elif action_timer > 0.0 and action_name == "tackle":
            model.rotation.x = -0.22 * (action_timer / 0.42)
        elif action_timer > 0.0 and action_name == "save" and bool(p.keeper):
            var dive_weight := action_timer / 0.42
            var dive_direction := float(p.get("save_direction", 1.0))
            model.position.x = dive_direction * 0.82 * (1.0 - dive_weight)
            model.rotation.z = -dive_direction * 0.72 * (1.0 - dive_weight)
        elif action_timer > 0.0 and action_name in ["roulette", "messi_dribble", "ronaldo_stepover"]:
            model.rotation.y = 0.35 * sin((1.0 - action_timer / 0.85) * TAU)
            model.rotation.z = 0.18 * sin((1.0 - action_timer / 0.7) * PI)
        elif action_timer > 0.0 and action_name == "celebrate":
            model.position.y = 0.10 + 0.08 * absf(sin(phase * 3.0))
            model.rotation.z = 0.12 * sin(phase * 2.0)
            model.rotation.x = -0.12 * absf(sin(phase * 3.0))
    var frequency := 5.5 if sprinting_now else 4.2
    if moving:
        phase += delta * frequency
    else:
        phase += delta * 1.4
    p.anim_phase = phase
    var legs: Array = p.legs
    var arms: Array = p.arms
    var swing := sin(phase) * (0.72 if sprinting_now else 0.52) if moving else 0.025 * sin(phase)
    for j in range(legs.size()):
        var leg: Node3D = legs[j]
        var side := -1.0 if j == 0 else 1.0
        leg.rotation.x = swing * side
    for j in range(arms.size()):
        var arm: Node3D = arms[j]
        var side := -1.0 if j == 0 else 1.0
        arm.rotation.x = -swing * side * 0.8
        arm.rotation.z = 0.0
    if action_timer > 0.0 and action_name == "shoot":
        var kick_leg: Node3D = legs[1]
        kick_leg.rotation.x = -1.15 * (action_timer / 0.32)
    elif action_timer > 0.0 and action_name == "pass":
        var pass_leg: Node3D = legs[1]
        pass_leg.rotation.x = -0.72 * (action_timer / 0.24)
    elif action_timer > 0.0 and action_name == "save":
        var save_weight := action_timer / 0.42
        var save_direction := float(p.get("save_direction", 1.0))
        arms[0].rotation.z = -save_direction * 1.25 * (1.0 - save_weight)
        arms[1].rotation.z = -save_direction * 0.85 * (1.0 - save_weight)
    elif action_timer > 0.0 and action_name == "dribble":
        var move_weight := action_timer / 0.48
        legs[0].rotation.x = -0.9 * move_weight
        legs[1].rotation.x = 0.82 * move_weight
        arms[0].rotation.z = -0.25 * move_weight
        arms[1].rotation.z = 0.25 * move_weight
    elif action_timer > 0.0 and action_name == "feint":
        var feint_weight := action_timer / 0.36
        legs[0].rotation.x = 0.55 * feint_weight
        legs[1].rotation.x = -0.50 * feint_weight
    elif action_timer > 0.0 and action_name == "tackle":
        var tackle_weight := action_timer / 0.42
        legs[0].rotation.x = -0.95 * tackle_weight
        arms[0].rotation.z = -0.45 * tackle_weight
        arms[1].rotation.z = 0.45 * tackle_weight
    elif action_timer > 0.0 and action_name in ["roulette", "messi_dribble", "ronaldo_stepover"]:
        var skill_weight := clampf(action_timer / 0.85, 0.0, 1.0)
        legs[0].rotation.x = -0.75 * skill_weight
        legs[1].rotation.x = 0.65 * skill_weight
        arms[0].rotation.z = -0.38 * skill_weight
        arms[1].rotation.z = 0.38 * skill_weight
    elif action_timer > 0.0 and action_name == "celebrate":
        var celebrate_weight := clampf(action_timer / 2.0, 0.0, 1.0)
        arms[0].rotation.z = -1.2 * celebrate_weight
        arms[1].rotation.z = 1.2 * celebrate_weight
        legs[0].rotation.x = -0.35 * absf(sin(phase * 3.0))
        legs[1].rotation.x = 0.35 * absf(sin(phase * 3.0))

func _nearest_player_index(team: int, target: Vector3) -> int:
    var best := -1
    var best_dist := INF
    for i in range(players.size()):
        if int(players[i].team) != team or bool(players[i].keeper):
            continue
        var n: Node3D = players[i].node
        var d := n.position.distance_squared_to(target)
        if d < best_dist:
            best_dist = d
            best = i
    return best

func _second_nearest_player_index(team: int, target: Vector3, excluded: int) -> int:
    var best := -1
    var best_dist := INF
    for i in range(players.size()):
        if int(players[i].team) != team or bool(players[i].keeper) or i == excluded:
            continue
        var node: Node3D = players[i].node
        var distance_sq := node.position.distance_squared_to(target)
        if distance_sq < best_dist:
            best_dist = distance_sq
            best = i
    return best

func _nearest_opponent_index(team: int, target: Vector3) -> int:
    var best := -1
    var best_dist := INF
    var opponent_team := 1 - team
    for i in range(players.size()):
        if int(players[i].team) != opponent_team or bool(players[i].keeper):
            continue
        var node: Node3D = players[i].node
        var distance_sq := node.position.distance_squared_to(target)
        if distance_sq < best_dist:
            best_dist = distance_sq
            best = i
    return best

func _distance_to_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
    var segment := finish - start
    var length_sq := segment.length_squared()
    if length_sq < 0.001:
        return point.distance_to(start)
    var amount := clampf((point - start).dot(segment) / length_sq, 0.0, 1.0)
    return point.distance_to(start + segment * amount)

func _shot_lane_clear(start: Vector3, finish: Vector3, attacking_team: int) -> bool:
    var defending_team := 1 - attacking_team
    for i in range(players.size()):
        if int(players[i].team) != defending_team or bool(players[i].keeper):
            continue
        var defender: Node3D = players[i].node
        if _distance_to_segment(defender.position, start, finish) < 1.25:
            return false
    return true

func _update_ball(delta: float) -> void:
    ball_vel.y -= GRAVITY * delta
    ball_pos += ball_vel * delta
    _try_goalkeeper_save()
    if ball_pos.y < BALL_R:
        ball_pos.y = BALL_R
        ball_vel.y = absf(ball_vel.y) * 0.28
        ball_vel.x *= 0.985
        ball_vel.z *= 0.985
        if absf(ball_vel.y) < 0.8:
            ball_vel.y = 0
    if ball_curve_time > 0.0:
        var curve_sign := signf(ball_curve_strength)
        ball_vel.x += curve_sign * minf(absf(ball_curve_strength), 8.0) * delta
        ball_curve_strength = move_toward(ball_curve_strength, 0.0, delta * 1.6)
    ball_vel.x = move_toward(ball_vel.x, 0, delta * 1.1)
    ball_vel.z = move_toward(ball_vel.z, 0, delta * 1.1)
    if absf(ball_pos.x) > FIELD_W/2 - BALL_R:
        ball_pos.x = clampf(ball_pos.x, -FIELD_W/2 + BALL_R, FIELD_W/2 - BALL_R)
        ball_vel.x *= -0.65
    if absf(ball_pos.z) > FIELD_L/2 + 2:
        _check_goal()
    ball_mesh.position = ball_pos
    ball_mesh.rotate_x(delta * 3.0)
    ball_mesh.rotate_z(delta * 2.0)

func _try_goalkeeper_save() -> bool:
    if goalkeeper_save_cooldown > 0.0:
        return false
    for keeper_index in [0, 11]:
        var keeper_data: Dictionary = players[keeper_index]
        var keeper_node: Node3D = keeper_data.node
        var team: int = int(keeper_data.team)
        var ball_heading_to_goal := (team == 0 and ball_vel.z > 0.0) or (team == 1 and ball_vel.z < 0.0)
        if not ball_heading_to_goal:
            continue
        if absf(ball_pos.z - keeper_node.position.z) < 1.25 and absf(ball_pos.x - keeper_node.position.x) < 1.8 and ball_pos.y < 2.8:
            ball_vel.z *= -0.62
            ball_vel.x += signf(ball_pos.x - keeper_node.position.x) * 2.6
            ball_vel.y = maxf(ball_vel.y, 2.0)
            keeper_data.action_anim = "save"
            keeper_data.action_timer = 0.42
            var dive_direction := signf(ball_pos.x - keeper_node.position.x)
            if is_zero_approx(dive_direction):
                dive_direction = signf(ball_vel.x)
            if is_zero_approx(dive_direction):
                dive_direction = 1.0
            keeper_data.save_direction = dive_direction
            players[keeper_index] = keeper_data
            goalkeeper_save_cooldown = 0.55
            action_text = "تصدي رائع من الحارس!"
            return true
    return false

func _check_goal() -> void:
    if absf(ball_pos.x) < 3.6 and ball_pos.y < 2.6:
        if ball_pos.z < 0:
            score_home += 1
            celebration_team = 0
            action_text = "هدف للفريق الأزرق!"
        else:
            score_away += 1
            celebration_team = 1
            action_text = "هدف للفريق الأبيض!"
        ball_pos = Vector3.ZERO
        ball_vel = Vector3.ZERO
        celebration_timer = 2.8
        for i in range(players.size()):
            var p: Dictionary = players[i]
            var n: Node3D = p.node
            n.position = p.home
            if int(p.team) == celebration_team:
                p.action_anim = "celebrate"
                p.action_timer = 2.0
                players[i] = p
    else:
        ball_pos.z = clampf(ball_pos.z, -FIELD_L/2 + 1, FIELD_L/2 - 1)
        ball_vel.z *= -0.6

func _update_camera(delta: float) -> void:
    var target := Vector3(ball_pos.x * 0.25, 0, ball_pos.z * 0.18)
    camera_pivot.position = camera_pivot.position.lerp(target, minf(1.0, delta * 2.2))

func _perform_action(keycode: Key) -> void:
    if keycode == KEY_P:
        match_paused = not match_paused
        action_text = "المباراة متوقفة مؤقتاً" if match_paused else "استؤنفت المباراة"
    elif keycode == KEY_TAB:
        controlled = (controlled + 1) % 11
        action_text = "تم تبديل اللاعب"
    elif keycode == KEY_K and pass_cooldown <= 0:
        var p: Node3D = players[controlled].node
        if p.position.distance_to(Vector3(ball_pos.x, 0, ball_pos.z)) > 2.8:
            action_text = "اقترب من الكرة أولاً"
            return
        var teammate := _best_pass_target_for_team(p.position, 0, controlled)
        var dir := Vector3(0, 0, -1)
        if teammate >= 0:
            var receiver: Node3D = players[teammate].node
            var receiver_velocity: Vector3 = players[teammate].velocity
            var lead_position := receiver.position + receiver_velocity * 0.22
            dir = (lead_position - p.position).normalized()
        ball_vel = dir * 14.0 + Vector3(0, 2.0, 0)
        players[controlled].action_anim = "pass"
        players[controlled].action_timer = 0.24
        pass_cooldown = 0.5
        action_text = "تمريرة إلى زميلك!"
    elif keycode == KEY_J and shoot_cooldown <= 0:
        var p: Node3D = players[controlled].node
        if p.position.distance_to(Vector3(ball_pos.x, 0, ball_pos.z)) > 2.8:
            action_text = "اقترب من الكرة أولاً"
            return
        var goal_dir := Vector3(-ball_pos.x * 0.025, 0, -1).normalized()
        ball_vel = goal_dir * 22.0 + Vector3(0, 4.2, 0)
        players[controlled].action_anim = "shoot"
        players[controlled].action_timer = 0.32
        shoot_cooldown = 0.75
        action_text = "تسديدة قوية!"
    elif keycode == KEY_E:
        _perform_dribble_skill()
    elif keycode == KEY_Q:
        _perform_feint()
    elif keycode == KEY_C:
        _perform_tackle()
    elif keycode == KEY_R:
        _start_360_dribble()
    elif keycode == KEY_T:
        _use_player_signature_skill()
    elif keycode == KEY_L:
        _shoot_curved()
    elif keycode == KEY_U:
        _shoot_long_range()
    elif keycode == KEY_H:
        _celebrate_goal()
    elif keycode == KEY_SHIFT:
        sprinting = true
    _refresh_hud()

func _controlled_move_direction() -> Vector3:
    var direction := Vector3(move_input.x, 0.0, move_input.y)
    if direction.length_squared() < 0.04:
        var player_node: Node3D = players[controlled].node
        direction = -player_node.global_transform.basis.z
    direction.y = 0.0
    return direction.normalized() if direction.length_squared() > 0.001 else Vector3(0, 0, -1)

func _has_ball_control(max_distance := 2.35) -> bool:
    var player_node: Node3D = players[controlled].node
    return player_node.position.distance_to(Vector3(ball_pos.x, 0.0, ball_pos.z)) <= max_distance and ball_pos.y < 1.65

func _perform_dribble_skill() -> void:
    if skill_cooldown > 0.0:
        action_text = "مهارة المراوغة قيد التبريد"
        return
    if not _has_ball_control(2.6):
        action_text = "اقترب من الكرة لتنفيذ المراوغة"
        return
    var direction := _controlled_move_direction()
    var player_node: Node3D = players[controlled].node
    var nearest_enemy := _nearest_opponent_index(0, player_node.position)
    var lateral := Vector3(-direction.z, 0.0, direction.x)
    if nearest_enemy >= 0:
        var enemy_node: Node3D = players[nearest_enemy].node
        var to_enemy := enemy_node.position - player_node.position
        if to_enemy.dot(lateral) < 0.0:
            lateral = -lateral
    skill_direction = (direction * 0.82 + lateral * 0.58).normalized()
    ball_vel = skill_direction * 10.8 + Vector3(0.0, 0.45, 0.0)
    skill_boost_timer = 0.48
    skill_cooldown = 1.65
    players[controlled].action_anim = "dribble"
    players[controlled].action_timer = 0.48
    action_text = "مراوغة سريعة وتغيير اتجاه!"
    _refresh_hud()

func _perform_feint() -> void:
    if feint_cooldown > 0.0:
        action_text = "الخدعة قيد التبريد"
        return
    if not _has_ball_control(2.5):
        action_text = "احتفظ بالكرة أولاً لتنفيذ الخدعة"
        return
    var direction := _controlled_move_direction()
    var lateral := Vector3(-direction.z, 0.0, direction.x)
    var player_node: Node3D = players[controlled].node
    var enemy_index := _nearest_opponent_index(0, player_node.position)
    if enemy_index >= 0:
        var enemy_node: Node3D = players[enemy_index].node
        if (enemy_node.position - player_node.position).dot(lateral) < 0.0:
            lateral = -lateral
    # A short lateral touch simulates a body feint followed by a change of direction.
    ball_vel = (direction * 3.2 + lateral * 8.2) + Vector3(0.0, 0.25, 0.0)
    feint_cooldown = 1.15
    players[controlled].action_anim = "feint"
    players[controlled].action_timer = 0.36
    action_text = "خدعة جسمية وتغيير اتجاه!"
    _refresh_hud()

func _perform_tackle() -> void:
    if tackle_cooldown > 0.0:
        action_text = "انتظر قبل محاولة الافتكاك التالية"
        return
    var player_node: Node3D = players[controlled].node
    var enemy_index := _nearest_opponent_index(0, player_node.position)
    if enemy_index < 0:
        return
    var enemy_node: Node3D = players[enemy_index].node
    var distance := player_node.position.distance_to(enemy_node.position)
    if distance > 2.8:
        action_text = "اقترب من الخصم لافتكاك الكرة"
        return
    var toward_enemy := enemy_node.position - player_node.position
    toward_enemy.y = 0.0
    if toward_enemy.length_squared() > 0.001:
        player_node.look_at(player_node.position + toward_enemy.normalized(), Vector3.UP)
    if distance < 1.75 and enemy_node.position.distance_to(Vector3(ball_pos.x, 0.0, ball_pos.z)) < 2.3:
        ball_vel = (player_node.position - enemy_node.position).normalized() * 5.0 + Vector3(0.0, 1.1, 0.0)
        action_text = "افتكاك ناجح! الكرة أصبحت حرة"
    else:
        action_text = "محاولة افتكاك؛ الخصم يحمي الكرة"
    players[controlled].action_anim = "tackle"
    players[controlled].action_timer = 0.42
    tackle_cooldown = 1.0
    _refresh_hud()

func _start_360_dribble() -> void:
    if skill_cooldown > 0.0:
        action_text = "انتظر حتى تعود المهارة"
        return
    if not _has_ball_control():
        action_text = "اقترب من الكرة لتنفيذ دوران 360"
        return
    var p: Dictionary = players[controlled]
    p.skill_timer = 0.85
    p.spin_direction = 1.0 if ball_pos.x >= p.node.position.x else -1.0
    p.action_anim = "roulette"
    p.action_timer = 0.85
    players[controlled] = p
    var forward := -1.0 if int(p.team) == 0 else 1.0
    ball_vel = Vector3(p.spin_direction * 3.8, 1.0, forward * 5.8)
    skill_cooldown = 1.4
    action_text = "مراوغة دوران 360 درجة!"

func _use_player_signature_skill() -> void:
    if skill_cooldown > 0.0:
        action_text = "المهارة الخاصة قيد التبريد"
        return
    if not _has_ball_control():
        action_text = "اقترب من الكرة أولاً"
        return
    var p: Dictionary = players[controlled]
    var profile := String(p.skill_profile)
    var node: Node3D = p.node
    if profile == "messi":
        # Messi-style close control: short burst and tight touch, tuned for control.
        var forward := -node.global_transform.basis.z
        ball_vel = forward * 8.0 + Vector3(0, 0.45, 0)
        p.skill_timer = 0.55
        p.action_anim = "messi_dribble"
        p.action_timer = 0.55
        action_text = "مهارة ميسي: لمسات قريبة وانطلاقة!"
    elif profile == "ronaldo":
        # Ronaldo-style step-over burst with a stronger acceleration.
        var forward := -node.global_transform.basis.z
        var side := node.global_transform.basis.x * (1.8 if ball_pos.x < node.position.x else -1.8)
        ball_vel = forward * 10.5 + side + Vector3(0, 0.7, 0)
        p.skill_timer = 0.7
        p.action_anim = "ronaldo_stepover"
        p.action_timer = 0.7
        action_text = "مهارة رونالدو: خدعة وانطلاقة قوية!"
    else:
        var forward := -node.global_transform.basis.z
        ball_vel = forward * 8.5 + Vector3(0, 0.5, 0)
        p.skill_timer = 0.45
        p.action_anim = "skill"
        p.action_timer = 0.45
        action_text = "مراوغة مهارية!"
    players[controlled] = p
    skill_cooldown = 2.0

func _shoot_curved() -> void:
    if shoot_cooldown > 0.0 or not _has_ball_control():
        action_text = "اقترب من الكرة أو انتظر"
        return
    var p: Dictionary = players[controlled]
    var goal_dir := Vector3(-ball_pos.x * 0.035, 0, -1).normalized()
    ball_vel = goal_dir * 19.0 + Vector3(0, 5.2, 0)
    ball_curve_strength = -5.5 if ball_pos.x > 0.0 else 5.5
    ball_curve_time = 1.15
    p.action_anim = "shoot"
    p.action_timer = 0.34
    players[controlled] = p
    shoot_cooldown = 0.9
    action_text = "تسديدة مقوسة!"

func _shoot_long_range() -> void:
    if shoot_cooldown > 0.0 or not _has_ball_control():
        action_text = "اقترب من الكرة أو انتظر"
        return
    var p: Dictionary = players[controlled]
    var goal_dir := Vector3(-ball_pos.x * 0.018, 0, -1).normalized()
    ball_vel = goal_dir * 27.0 + Vector3(0, 6.0, 0)
    ball_curve_strength = 0.0
    ball_curve_time = 0.0
    p.action_anim = "shoot"
    p.action_timer = 0.4
    players[controlled] = p
    shoot_cooldown = 1.15
    action_text = "تسديدة قوية من بعيد!"

func _celebrate_goal() -> void:
    if celebration_timer > 0.0:
        action_text = "احتفال بالهدف!"
        for i in range(players.size()):
            var p: Dictionary = players[i]
            if int(p.team) == celebration_team:
                p.action_anim = "celebrate"
                p.action_timer = 1.6
                players[i] = p
    else:
        action_text = "سجّل هدفاً أولاً للاحتفال"

func _best_pass_target(from: Vector3) -> int:
    return _best_pass_target_for_team(from, 0, controlled)

func _best_pass_target_for_team(from: Vector3, team: int, passer_index: int) -> int:
    var best := -1
    var best_score := -INF
    var first_index := team * 11
    var last_index := first_index + 11
    var attacking_sign := -1.0 if team == 0 else 1.0
    for i in range(first_index, last_index):
        if i == passer_index or bool(players[i].keeper):
            continue
        var receiver: Node3D = players[i].node
        var receiver_velocity: Vector3 = players[i].velocity
        var lead_position := receiver.position + receiver_velocity * 0.22
        var pass_vector := lead_position - from
        var distance := pass_vector.length()
        if distance < 4.0 or distance > 36.0:
            continue
        var forward_progress := pass_vector.z * attacking_sign
        var nearest_defender := 99.0
        var lane_penalty := 0.0
        for j in range((1 - team) * 11, (1 - team) * 11 + 11):
            if bool(players[j].keeper):
                continue
            var defender: Node3D = players[j].node
            nearest_defender = minf(nearest_defender, defender.position.distance_to(lead_position))
            var lane_distance := _distance_to_segment(defender.position, from, lead_position)
            if lane_distance < 2.2:
                lane_penalty += (2.2 - lane_distance) * 2.0
        var pressure_penalty := maxf(0.0, 5.5 - nearest_defender) * 1.8
        var score := forward_progress * 0.62 - distance * 0.12 + minf(nearest_defender, 10.0) * 0.18 - pressure_penalty - lane_penalty
        if score > best_score:
            best_score = score
            best = i
    return best

func _nearest_teammate(from: Vector3) -> int:
    var best := -1
    var dist := INF
    for i in range(1, 11):
        if i == controlled:
            continue
        var n: Node3D = players[i].node
        var d := n.position.distance_to(from)
        if d < dist:
            dist = d
            best = i
    return best

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_J, KEY_K, KEY_TAB, KEY_SHIFT, KEY_E, KEY_Q, KEY_C, KEY_R, KEY_T, KEY_L, KEY_U, KEY_H, KEY_P]:
            _perform_action(event.keycode)
    elif event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < 260 and event.position.y > 430:
                joystick_active = true
                _set_joystick(event.position)
            elif event.position.x > 900:
                if event.position.y < 560:
                    _perform_action(KEY_J)
                elif event.position.y < 635:
                    _perform_action(KEY_K)
                else:
                    _perform_action(KEY_SHIFT)
        else:
            joystick_active = false
            joystick_vector = Vector2.ZERO
    elif event is InputEventScreenDrag and joystick_active:
        _set_joystick(event.position)

func _set_joystick(pos: Vector2) -> void:
    joystick_vector = ((pos - joystick_center) / 85.0).limit_length(1.0)
