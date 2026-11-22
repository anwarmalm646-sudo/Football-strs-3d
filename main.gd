extends Node3D

# Football Stars 3D — playable prototype.
 
const FIELD_W := 58.0
const FIELD_L := 94.0

const BALL_R := 0.38


const PLAYER_SPEED := 7.2
const SPRINT_SPEED := 10.0
const GRAVITY := 18.0


const AI_COVER_OFFSET := 2.8

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


# Football Stars 3D — playable prototype.
# All pitch/player geometry is procedural so the project runs without external assets.

const FIELD_W := 58.0
const FIELD_L := 94.0
const BALL_R := 0.38

const PLAYER_SPEED := 7.2
const SPRINT_SPEED := 10.0
const GRAVITY := 18.0


const AI_COVER_OFFSET := 2.8

var ai_action_cooldown := 0.0
var goalkeeper_save_cooldown := 0.0
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

func _ready() -> void:
    _build_world()
    _build_pitch()
    _build_players()
    _build_ball()
    _build_camera()
    _build_hud()
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

    # Optional external character: place a rigged GLB at res://assets/player.glb.
    # The model should contain an AnimationPlayer with idle/run/sprint/shoot/pass/save clips.
    var model_scene: PackedScene = null
    if ResourceLoader.exists("res://assets/player.glb"):
        model_scene = load("res://assets/player.glb") as PackedScene
    if model_scene != null:
        var model := model_scene.instantiate() as Node3D
        if model != null:
            root.add_child(model)
            var model_animator := _find_animation_player(model)
            return {"node": root, "team": team, "number": number, "home": pos, "keeper": keeper,
                "velocity": Vector3.ZERO, "arms": [], "legs": [], "anim_phase": 0.0,
                "anim_speed": 0.0, "action_anim": "", "action_timer": 0.0,
                "model_animator": model_animator, "model_anim_name": ""}

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

    return {"node": root, "team": team, "number": number, "home": pos, "keeper": keeper,
        "velocity": Vector3.ZERO, "arms": arms, "legs": legs, "anim_phase": 0.0,
        "anim_speed": 0.0, "action_anim": "", "action_timer": 0.0}

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
    help_label.text = "تحريك: WASD / الأسهم  •  تمرير: K  •  تسديد: J  •  تبديل: Tab  •  ركض: Shift"
    help_label.add_theme_font_size_override("font_size", 16)
    help_label.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(help_label)
    _make_touch_button(layer, "تمرير", Vector2(1080, 565), KEY_K)
    _make_touch_button(layer, "تسديد", Vector2(1160, 475), KEY_J)
    _make_touch_button(layer, "تبديل", Vector2(970, 650), KEY_TAB)
    _make_touch_button(layer, "ركض", Vector2(1155, 650), KEY_SHIFT)

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
    score_label.text = "FOOTBALL STARS 3D     %d  -  %d     %02d:%02d" % [score_home, score_away, int(match_seconds) / 60, int(match_seconds) % 60]
    hud.text = "الفريق الأزرق: هجوم ذكي  |  الخصم: دفاع وضغط  |  " + action_text

func _physics_process(delta: float) -> void:
    match_seconds += delta
    shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
    pass_cooldown = maxf(0.0, pass_cooldown - delta)
    ai_action_cooldown = maxf(0.0, ai_action_cooldown - delta)
    goalkeeper_save_cooldown = maxf(0.0, goalkeeper_save_cooldown - delta)
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
            var desired := Vector3(move_input.x, 0, move_input.y) * speed
            node.position += desired * delta
            node.position.x = clampf(node.position.x, -FIELD_W/2 + 1.0, FIELD_W/2 - 1.0)
            node.position.z = clampf(node.position.z, -FIELD_L/2 + 1.0, FIELD_L/2 - 1.0)
            if desired.length() > 0.1:
                node.look_at(node.position + desired, Vector3.UP)
            if node.position.distance_to(ball_ground) < 2.0 and ball_pos.y < 1.7:
                ball_vel.x = lerpf(ball_vel.x, desired.x * 0.55, 0.16)
                ball_vel.z = lerpf(ball_vel.z, desired.z * 0.55, 0.16)
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
        "save": ["save", "dive", "goalkeeper_save"]
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
    if p.has("model_animator"):
        var action_timer_model: float = maxf(0.0, float(p.action_timer) - delta)
        p.action_timer = action_timer_model
        var requested := "idle"
        if action_timer_model > 0.0 and String(p.action_anim) in ["shoot", "pass", "save"]:
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
    var action_timer: float = maxf(0.0, float(p.action_timer) - delta)
    p.action_timer = action_timer
    if action_timer > 0.0 and String(p.action_anim) == "shoot":
        var kick_leg: Node3D = legs[1]
        kick_leg.rotation.x = -1.15 * (action_timer / 0.32)
    elif action_timer > 0.0 and String(p.action_anim) == "pass":
        var pass_leg: Node3D = legs[1]
        pass_leg.rotation.x = -0.72 * (action_timer / 0.24)
    elif action_timer > 0.0 and String(p.action_anim) == "save":
        arms[0].rotation.z = -0.95 * (action_timer / 0.38)
        arms[1].rotation.z = 0.95 * (action_timer / 0.38)

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
            keeper_data.action_timer = 0.38
            players[keeper_index] = keeper_data
            goalkeeper_save_cooldown = 0.55
            action_text = "تصدي رائع من الحارس!"
            return true
    return false

func _check_goal() -> void:
    if absf(ball_pos.x) < 3.6 and ball_pos.y < 2.6:
        if ball_pos.z < 0:
            score_home += 1
            action_text = "هدف للفريق الأزرق!"
        else:
            score_away += 1
            action_text = "هدف للفريق الأبيض!"
        ball_pos = Vector3.ZERO
        ball_vel = Vector3.ZERO
        for i in range(players.size()):
            var p: Dictionary = players[i]
            var n: Node3D = p.node
            n.position = p.home
    else:
        ball_pos.z = clampf(ball_pos.z, -FIELD_L/2 + 1, FIELD_L/2 - 1)
        ball_vel.z *= -0.6

func _update_camera(delta: float) -> void:
    var target := Vector3(ball_pos.x * 0.25, 0, ball_pos.z * 0.18)
    camera_pivot.position = camera_pivot.position.lerp(target, minf(1.0, delta * 2.2))

func _perform_action(keycode: Key) -> void:
    if keycode == KEY_TAB:
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
    elif keycode == KEY_SHIFT:
        sprinting = true
    _refresh_hud()

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
        if event.keycode in [KEY_J, KEY_K, KEY_TAB, KEY_SHIFT]:
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
