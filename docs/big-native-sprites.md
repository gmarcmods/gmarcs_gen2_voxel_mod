# Native large sprite cards

Snorlax and Lapras big dolls use two stacked native 16px source frames,
mirrored into a complete 32px card. The mesh uses the renderer's quad-number
index convention, not a vertex offset. The pivot sits in the two-cell
footprint; solid and shadow passes share it. Ordinary 16px actors are unchanged.

`luajit tests/test_big_sprite.lua` uses the real renderer index helper and
checks dimensions, mirrored UVs, valid triangle indices and pivot offsets.
The terrain driver captures native Vermilion Snorlax for visual inspection.
