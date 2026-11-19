# Event Horizon – Asymmetric Space Watch Face

*Cross the threshold.*

Event Horizon transforms your Garmin into a window onto the cosmos — asymmetric by design, gravitational by nature.

An off-center dial pulls the hands toward the dark side, where a moon-phase shadow swallows the right edge of the face. Deep within that darkness, concentric rings of electric light trace the boundary of a singularity — the point of no return where time itself bends.

Neon-cyan arcs radiate from the shadows, mapping the invisible forces of a collapsing star. Dauphine hands glow with a cold blue halo, rising from their eccentric pivot like light escaping a black hole's grip — barely.

This is not a symmetric watch face. It was never meant to be.

*Dark matter. Electric light. Event Horizon.*

## Design, calibrated — on every display

Every hand, marker, ring and shadow of Event Horizon is specified in
fractions of the dial radius, so the composition holds its asymmetry
and its negative space from the smallest 260 px display to the largest
454 px one. The launcher icon is delivered at each product's native
size, and the background is rasterized once per layout into an 8-bit
palette buffer for a light, allocation-free rendering loop.

## Engineering

- **Golden-math test suite** (`tests/test_eventhorizon_math.py`):
  analytic, case-exact checks of the hand-angle mapping, screen-space
  clock direction, terminator geometry, `drawArc` sectors and PRNG
  determinism — so any change that breaks the geometry fails in
  seconds, not at the simulator.
- **Zero-warning build** on all three launcher-icon families
  (60/65/70 px).
- **Rendered from fractions, not pixels**: all proportions live in one
  reference block of named constants at the top of
  `source/EventHorizonView.mc`.
