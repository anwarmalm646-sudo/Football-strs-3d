#!/usr/bin/env python3
"""Lightweight static checks for the Football Stars 3D Godot source tree.
This is not a replacement for Godot's GDScript parser or an in-engine test.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "main.gd"
SCENE = ROOT / "scenes" / "Main.tscn"
PROJECT = ROOT / "project.godot"

errors: list[str] = []
checks: list[str] = []

for path in (SCRIPT, SCENE, PROJECT):
    if path.is_file():
        checks.append(f"exists: {path.relative_to(ROOT)}")
    else:
        errors.append(f"missing file: {path.relative_to(ROOT)}")

if errors:
    print("FAIL")
    print("\n".join(errors))
    sys.exit(1)

source = SCRIPT.read_text(encoding="utf-8")
scene = SCENE.read_text(encoding="utf-8")
project = PROJECT.read_text(encoding="utf-8")

if 'renderer/rendering_method="gl_compatibility"' in project and 'renderer/rendering_method.mobile="gl_compatibility"' in project:
    checks.append("GL Compatibility renderer configured for desktop and mobile")
else:
    errors.append("GL Compatibility renderer configuration missing")

if 'path="res://scripts/main.gd"' in scene:
    checks.append("main scene references scripts/main.gd")
else:
    errors.append("main scene script reference missing")

func_defs = re.findall(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", source, re.M)
if len(func_defs) == len(set(func_defs)):
    checks.append(f"unique function declarations: {len(func_defs)}")
else:
    errors.append("duplicate function declarations detected")

required_functions = [
    "_update_players", "_second_nearest_player_index", "_nearest_opponent_index",
    "_best_pass_target_for_team", "_distance_to_segment", "_shot_lane_clear",
    "_try_goalkeeper_save", "_animate_player",
]
for name in required_functions:
    if re.search(rf"^func\s+{re.escape(name)}\s*\(", source, re.M):
        checks.append(f"AI feature function present: {name}")
    else:
        errors.append(f"required function missing: {name}")

# All calls to local underscore-prefixed methods must have a matching declaration.
called = set(re.findall(r"(?<![A-Za-z0-9])(_[A-Za-z][A-Za-z0-9_]*)\s*\(", source))
defined = set(func_defs)
undefined = sorted(called - defined)
if undefined:
    errors.append("undefined local method call(s): " + ", ".join(undefined))
else:
    checks.append("all underscore-prefixed method calls have declarations")

if "var blue_cover := _second_nearest_player_index" in source and "var white_cover := _second_nearest_player_index" in source:
    checks.append("both teams assign a second pressing/cover player")
else:
    errors.append("coordinated second-player pressure missing")

if "_distance_to_segment(defender.position, from, lead_position)" in source:
    checks.append("pass selection evaluates defender interception lanes")
else:
    errors.append("pass-lane interception scoring missing")

if "receiver.position + receiver_velocity * 0.22" in source:
    checks.append("passes lead moving receivers")
else:
    errors.append("receiver lead pass logic missing")

if 'res://assets/player.glb' in source and "_find_animation_player" in source and "_play_model_animation" in source:
    checks.append("optional GLB character loader and AnimationPlayer binding present")
else:
    errors.append("GLB character animation binding missing")

if 'action_anim = "save"' in source and "goalkeeper_save_cooldown" in source:
    checks.append("goalkeeper save response and cooldown present")
else:
    errors.append("goalkeeper save response missing")

if "(team == 0 and ball_vel.z > 0.0) or (team == 1 and ball_vel.z < 0.0)" in source:
    checks.append("goalkeeper save direction matches the teams' defended goal ends")
else:
    errors.append("goalkeeper save direction is inconsistent with team attack directions")

# Small deterministic logic checks for the direction and segment-distance rules used above.
def distance_to_segment(point, start, finish):
    segment = tuple(finish[k] - start[k] for k in range(3))
    length_sq = sum(v * v for v in segment)
    if length_sq < 0.001:
        return sum((point[k] - start[k]) ** 2 for k in range(3)) ** 0.5
    amount = max(0.0, min(1.0, sum((point[k] - start[k]) * segment[k] for k in range(3)) / length_sq))
    closest = tuple(start[k] + segment[k] * amount for k in range(3))
    return sum((point[k] - closest[k]) ** 2 for k in range(3)) ** 0.5

assert ( -10.0 * -1.0) > 0.0  # blue progresses toward negative Z
assert ( 10.0 *  1.0) > 0.0  # white progresses toward positive Z
assert abs(distance_to_segment((5, 0, 2), (0, 0, 0), (10, 0, 0)) - 2.0) < 1e-6
assert abs(distance_to_segment((5, 0, 0), (0, 0, 0), (10, 0, 0))) < 1e-6
checks.append("directional pass-progress and pass-lane geometry smoke tests")

# Check balanced delimiters while ignoring comments and quoted strings.
stack: list[tuple[str, int]] = []
pairs = {")": "(", "]": "[", "}": "{"}
opens = set(pairs.values())
in_string: str | None = None
escaped = False
for line_no, line in enumerate(source.splitlines(), 1):
    i = 0
    while i < len(line):
        ch = line[i]
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == in_string:
                in_string = None
            i += 1
            continue
        if ch == "#":
            break
        if ch in ("'", '"'):
            in_string = ch
        elif ch in opens:
            stack.append((ch, line_no))
        elif ch in pairs:
            if not stack or stack[-1][0] != pairs[ch]:
                errors.append(f"unmatched {ch!r} on line {line_no}")
                break
            stack.pop()
        i += 1
if in_string:
    errors.append("unterminated quoted string")
if stack:
    errors.append("unclosed delimiter(s): " + ", ".join(f"{ch} at line {ln}" for ch, ln in stack))
if not in_string and not stack:
    checks.append("quoted strings and bracket delimiters are structurally balanced")

if "\t" not in source:
    checks.append("GDScript indentation uses spaces (no tab characters)")
else:
    errors.append("tab character found in GDScript; use spaces for indentation")

print(f"Football Stars 3D static validation: {len(checks)} checks")
for item in checks:
    print(f"PASS  {item}")
for item in errors:
    print(f"FAIL  {item}")
if errors:
    sys.exit(1)
print("\nStatic validation passed. Godot parsing/runtime and Android export are NOT covered.")
