# Changelog

## 3.1.0 — Audit fixes, adaptive rendering, bitmap cache

### User-visible

- **True-to-design moon shadow** — the terminator now ends exactly where
  the design intended; previously the darkness penetrated twice as deep
  as specified.
- **Completed singularity arcs** — the outer rings fading behind the
  terminator now trace the intended right half of the dial (all previous
  builds silently drew the wrong half).
- **Adaptive rendering** — every element (hands, markers, rings, shadow,
  circuit) is specified relative to the dial radius instead of hard-coded
  454 px pixels; proportions hold from 260 px to 454 px displays.
- **Native launcher icon** — vector icon provided at each of the 23
  supported products' exact native sizes (60/65/70 px).
- **Smoother rendering** — static background (gradient + 200-star field)
  rasterized once into an 8-bit palette `BufferedBitmap`, blitted each
  tick; direct-draw fallback if the graphics-pool allocation fails.

### Under the hood

- Fixed factor-of-two error in terminator placement (visible depth of an
  equal-diameter disk offset is `2r − Δ`); arcs remapped to the official
  Connect IQ `drawArc` convention (0° = 3 o'clock, counterclockwise
  positive; right half = `ARC_CLOCKWISE` 90° → 270°).
- Replaced the overflowing LCG (intermediate product ≈ 3.6 × 10¹⁵ on a
  32-bit `Number`) with a shift/XOR xorshift generator sampled from
  mid-order bits; explicit floating-point arithmetic for ring and
  penumbra spacing.
- Declared `eng` language in the manifest; untracked build artifacts;
  added `.gitignore`.
- New golden-math test suite: 25 pytest checks (hand angles with
  analytic cases, screen-space clockwise ordering, terminator depth
  including a regression witness of the legacy bug, `drawArc` sectors,
  PRNG determinism).

## 3.0.0

- New design: asymmetric dial, moon-phase shadow, singularity rings.

## 2.0

- New release.

## 1.3.1

- Minor refinement of the hands.

## 1.3.0

- Enhanced background.

## 1.2.0

- Markers in Always-On display mode.
