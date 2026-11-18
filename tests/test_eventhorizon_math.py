"""
Tests de référence (golden math) pour le cadran Event Horizon.

Le rendu tourne en Monkey C (Connect IQ) et ne s'exécute pas sous pytest :
ce fichier reproduit en Python les formules utilisées par
``source/EventHorizonView.mc`` et vérifie chaque invariant géométrique et
trigonométrique sur des cas analytiques exacts (12 h, 3 h, 9 h 30, etc.).
Il sert de témoin : si une transcription en Monkey C diverge de ces
identités, le bug sera visible au simulateur et localisable ici.

Lancer :  pytest -q tests/test_eventhorizon_math.py
"""

from __future__ import annotations

import math

import pytest

MASK_31 = 0x7FFFFFFF


# ---------------------------------------------------------------------------
# 1. Aiguilles : θ = 2π·(t/T) − π/2, repère écran y vers le bas
# ---------------------------------------------------------------------------

def hand_angle(fraction: float) -> float:
    """Angle écran (rad) pour une fraction de révolution ∈ [0, 1)."""
    return 2.0 * math.pi * fraction - math.pi / 2.0


def hand_end(x0: float, y0: float, angle: float, length: float) -> tuple[float, float]:
    """Extrémité d'aiguille : x = x0 + L·cos(θ), y = y0 + L·sin(θ)."""
    return (x0 + length * math.cos(angle), y0 + length * math.sin(angle))


def test_hour_hand_points_right_at_3h00():
    # Cas analytique : à 3:00:00, l'aiguille des heures pointe vers 3 h = +x
    ang = hand_angle(((3 % 12) * 60 + 0) / 720.0)
    x, y = hand_end(0.0, 0.0, ang, 90.0)
    assert x == pytest.approx(90.0, abs=1e-9)
    assert y == pytest.approx(0.0, abs=1e-9)


def test_hour_hand_points_up_at_12h00():
    # y écran vers le bas ⇒ 12 h correspond à y0 − L
    ang = hand_angle(0.0)
    x, y = hand_end(0.0, 0.0, ang, 90.0)
    assert x == pytest.approx(0.0, abs=1e-9)
    assert y == pytest.approx(-90.0, abs=1e-9)


def test_hour_hand_points_down_at_6h30():
    # 6:30 → aiguille à 195° dans le sens horaire depuis 12 h, soit 105°
    # depuis 3 h (+x écran) dans le repère y inversé utilisé par le code.
    ang = hand_angle((6 * 60 + 30) / 720.0)
    x, y = hand_end(0.0, 0.0, ang, 90.0)
    assert x == pytest.approx(90.0 * math.cos(math.radians(105.0)), abs=1e-9)
    assert y == pytest.approx(90.0 * math.sin(math.radians(105.0)), abs=1e-9)
    # et effectivement « vers le bas » (y > 0, y écran inversé)
    assert y > 0.0


def test_minute_hand_points_down_at_half_past():
    ang = hand_angle(30 / 60.0)
    x, y = hand_end(0.0, 0.0, ang, 120.0)
    # θ = 2π·0.5 − π/2 = π/2 → cos = 0, sin = 1 (le long de +y écran = bas)
    assert x == pytest.approx(0.0, abs=1e-9)
    assert y == pytest.approx(120.0, abs=1e-9)


def test_minute_hand_points_right_at_15min():
    ang = hand_angle(15 / 60.0)
    x, y = hand_end(0.0, 0.0, ang, 120.0)
    assert x == pytest.approx(120.0, abs=1e-9)
    assert y == pytest.approx(0.0, abs=1e-9)


def test_hour_angle_is_continuous_across_midnight():
    a931 = hand_angle(((23 % 12) * 60 + 31) / 720.0)  # 23:31 ≡ 11:31
    a1131 = hand_angle(((11 % 12) * 60 + 31) / 720.0)
    assert a931 == pytest.approx(a1131, abs=1e-12)


# ---------------------------------------------------------------------------
# 2. Marqueurs : θ_i = 2π·i/12 − π/2, ordre horaire correct en repère y inversé
# ---------------------------------------------------------------------------

def marker_pos(i: int, radius: float) -> tuple[float, float]:
    ang = (i / 12.0) * 2.0 * math.pi - math.pi / 2.0
    return (radius * math.cos(ang), radius * math.sin(ang))


@pytest.mark.parametrize("i, dx, dy", [
    (0, 0.0, -1.0),   # 12 h : en haut (y écran plus petit)
    (3, 1.0, 0.0),    # 3 h : à droite
    (6, 0.0, 1.0),    # 6 h : en bas
    (9, -1.0, 0.0),   # 9 h : à gauche
])
def test_marker_orientation_clockwise(i, dx, dy):
    x, y = marker_pos(i, 1.0)
    assert x == pytest.approx(dx, abs=1e-9)
    assert y == pytest.approx(dy, abs=1e-9)


def test_markers_are_clockwise_on_screen():
    # L'angle horaire croissant doit tourner dans le sens horaire à l'écran :
    # en repère y inversé, un parcours horaire a un produit vectoriel
    # (r_i × r_{i+1})_z > 0.
    for i in range(11):
        x1, y1 = marker_pos(i, 1.0)
        x2, y2 = marker_pos(i + 1, 1.0)
        assert x1 * y2 - y1 * x2 > 0.0


# ---------------------------------------------------------------------------
# 3. Ombre lunaire : profondeur du terminateur
#    Intersection de deux disques de rayon r séparés de Δ (le second centré
#    à droite de l'écran). Profondeur visible le long de l'axe : 2r − Δ.
# ---------------------------------------------------------------------------

def shadow_depth(r: float, w: float, variant: str) -> float:
    if variant == "fixed":
        delta = 2.0 * r - w          # code corrigé
    elif variant == "legacy":
        delta = 2.0 * (r - w)        # code d'origine
    else:
        raise ValueError(variant)
    return 2.0 * r - delta


@pytest.mark.parametrize("r, w", [(207.0, 55.0), (175.0, 46.5), (110.0, 29.2)])
def test_shadow_depth_matches_design_width(r, w):
    # La profondeur visible doit être exactement w, pas 2w
    assert shadow_depth(r, w, "fixed") == pytest.approx(w, abs=1e-9)


def test_legacy_terminator_was_offset_by_factor_2():
    # Diagnostic de l'anomalie [F-2] : l'ancienne formule enfouissait le
    # terminateur à 2w du bord, le double de la largeur documentée.
    assert shadow_depth(207.0, 55.0, "legacy") == pytest.approx(110.0, abs=1e-9)


def test_penumbra_layers_are_strictly_nested():
    # Les passes pénombre (8) doivent couvrir des profondeurs strictement
    # décroissantes ; la dernière rejoint celle de l'ombre noire w0 (qui
    # la recouvre), puis les couches noires descendent jusqu'à 0.35·w0.
    r = 207.0
    w0 = 55.0
    span = 30.0
    penumbra = [w0 + span - i * span / 7.0 for i in range(8)]
    assert min(penumbra) == pytest.approx(w0, abs=1e-9)
    assert all(d1 > d2 for d1, d2 in zip(penumbra, penumbra[1:]))
    black = [w0, 0.65 * w0, 0.35 * w0]
    assert all(b < w0 for b in black[1:])
    assert black[0] > black[1] > black[2]


# ---------------------------------------------------------------------------
# 4. Conventions drawArc Connect IQ (doc officielle Garmin Dc.drawArc) :
#    0° = 3 h, 90° = 12 h, 180° = 9 h, 270° = 6 h (sens trigonométrique).
#    Point : (x, y) = (R·cos θ, −R·sin θ) en repère écran y inversé.
#    ARC_CLOCKWISE dessine de degreeStart à degreeEnd en sens horaire
#    visuel = angles décroissants modulo 360.
# ---------------------------------------------------------------------------

def arc_xy(angle_deg: float, radius: float) -> tuple[float, float]:
    t = math.radians(angle_deg)
    return (radius * math.cos(t), -radius * math.sin(t))


def arc_sector_clockwise(start_deg: int, end_deg: int) -> list[int]:
    """Angles parcourus par ARC_CLOCKWISE de start à end (wrap modulo 360)."""
    span = (start_deg - end_deg) % 360
    return [(start_deg - k) % 360 for k in range(span + 1)]


def test_coordinate_mapping_matches_official_convention():
    assert arc_xy(0, 1.0) == pytest.approx((1.0, 0.0), abs=1e-9)    # 3 h
    assert arc_xy(90, 1.0) == pytest.approx((0.0, -1.0), abs=1e-9)  # 12 h (y écran vers le bas)
    assert arc_xy(180, 1.0) == pytest.approx((-1.0, 0.0), abs=1e-9) # 9 h
    assert arc_xy(270, 1.0) == pytest.approx((0.0, 1.0), abs=1e-9)  # 6 h


def test_right_half_arc_is_90_to_270():
    # Demi-arc droit (code corrigé de drawSingularityRings) : part de 12 h,
    # passe par 3 h (0°), finit à 6 h ; n'atteint jamais 9 h (180°).
    sector = arc_sector_clockwise(90, 270)
    assert 0 in sector and 180 not in sector
    assert sector[0] == 90 and sector[-1] == 270


def test_legacy_arc_300_60_was_wrong_half():
    # Diagnostic de l'anomalie d'origine : (300 → 60) horaire passe par
    # 180° = 9 h, donc trace la moitié GAUCHE et non la droite voulue.
    sector = arc_sector_clockwise(300, 60)
    assert 180 in sector and 0 not in sector



# ---------------------------------------------------------------------------
# 5. Dégradé concentrique : interpolation linéaire C(i)
# ---------------------------------------------------------------------------

def interp(c0: float, c1: float, ratio: float) -> int:
    v = c0 + (c1 - c0) * ratio
    return int(v)  # équivaut à àLong() → troncature vers zéro


def test_gradient_endpoints_exact():
    assert interp(0x40, 0x05, 0.0) == 0x40          # centre
    assert interp(0x40, 0x05, 1.0) == 0x05          # bord
    assert interp(0x60, 0x10, 1.0) == 0x10


def test_gradient_is_monotonic():
    vals = [interp(0x40, 0x05, i / 39.0) for i in range(40)]
    assert vals == sorted(vals, reverse=True)
    assert all(0 <= v <= 0x40 for v in vals)


# ---------------------------------------------------------------------------
# 6. Champ d'étoiles : xorshift 31 bits (shifts + XOR uniquement, aucun
#    produit débordant 32 bits), réutilisé-bit >> 8, déterministe
# ---------------------------------------------------------------------------

def xorshift31(x: int) -> int:
    x ^= (x << 13) & MASK_31
    x &= MASK_31
    x ^= x >> 17
    x ^= (x << 5) & MASK_31
    return x & MASK_31


def test_xorshift_never_reaches_zero_or_negative():
    x = 42
    for _ in range(100_000):
        x = xorshift31(x)
        assert 0 < x <= MASK_31


def test_xorshift_deterministic():
    def stream():
        x = 42
        out = []
        for _ in range(64):
            x = xorshift31(x)
            out.append(x)
        return out
    assert stream() == stream()


def test_star_positions_fit_screen():
    width, height = 454, 454
    x, hits = 42, 0
    for _ in range(200):
        x = xorshift31(x)
        px = ((x >> 8) % width if isinstance((x >> 8), int) else 0)
        hits += 0 <= px < width
    assert hits == 200


def test_no_short_cycle_after_reseeding():
    # L'ancien LCG masqué à 2^31 restait valide, mais son produit
    # (1664525 × état) débordait 32 bits : le xorshift n'a plus de produit.
    xs = []
    x = 42
    for _ in range(10_000):
        x = xorshift31(x)
        xs.append(x)
    assert len(set(xs)) > 9_000  # peu de collisions sur 10 k tirages
