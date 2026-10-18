# Rocket hideout furniture and Android battle UI

Version 0.1.42 includes runtime 1.10.29's battle HUD DPI correction and a
source-backed furniture pass for Mahogany's Rocket hideout.

Facility props now explicitly use native floor tile 0; neighborhood voting
could previously select a wooden fixture top and paint it beneath chairs and
equipment. Both facility and underground computer desks have open legs, deep
CRT housings with native screen texels on their fronts, and bezel texels on
their side walls. The underground stool has four separate legs. Furniture tile
arrangements and the 441-asset catalog remain intact.

The previous profile is preserved at
`archive/voxel-profile-before-rocket-furniture-0.1.41.lua`. The runtime recipe
`tools/asset_recipes/rocket_furniture.lua` reproduces the authorized changes;
`tests/test_rocket_furniture.lua` compares every resulting profile value with
that recipe applied to the baseline, so unrelated geometry cannot drift.

Live captures were inspected in TEAM_ROCKET_BASE_B1F/B2F/B3F using the authored
project, with companion effects disabled for the furniture comparison.
