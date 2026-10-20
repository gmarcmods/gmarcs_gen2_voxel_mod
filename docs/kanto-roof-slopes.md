# Kanto roof slopes — 1.0.5

The thirteen authored pitched Kanto roofs now continue from their eaves to a
hip ridge. Previously the rise stopped at eight pixels, leaving a broad flat
plateau. Commercial roofs retain their existing shallow bevel.

Opposite slopes share the same native roof band. Hip faces sample the interior
roof motif along their eaves, avoiding the background and outline pixels in
the original flat sprite corners. The museum uses its first complete roof band
instead of repeating the extra eave stripe in its taller source pattern.

The roofs remain hollow, with exactly the same voxel count. Façades, footprints,
windows, doors and all other authored assets are unchanged. Both authoring
recipes produce the same roof positions and source pixels as the shipped data.

Validation:

- `luajit tests/test_kanto_roof_slopes.lua /tmp/kanto-roofs-before.lua`
  checks every roof column, mirrored texture bands, interior sampling, recipe
  agreement and preservation of all 441 assets against the 1.0.4 profile.
- `tests/kanto_roofs_live.lua` captured front/back views in native Gold of the
  short Celadon house, long Celadon house, Fuchsia two-storey house and Pewter
  museum, with Johto in First Person detached. The captures were inspected.
- No physical Android test was performed. Geometry and native texture mappings
  are shared across Gold, Silver and Crystal.

Selected before/after captures are under `docs/screenshots/kanto-roofs-*`.
