# Imported battle sprite providers

BTL SPRITES selects NATIVE (default) or BLACK/WHITE for the MAP/PLATFORMS
3D battle modes. STADIUM models remain their own option. Install the code-only
GEN5_PRIVATE_SPRITES companion and import your own supported Black / White ROM
through the engine launcher IMPORTERS tab. Black 2 / White 2 is not supported;
older saved `gen5_b2w2` choices resolve to NATIVE.

When a usable Black / White pack is unavailable, the configuration choice and
OPTIONS value display an IMPORT ROM reminder. Configuration help explains the
provider and launcher import requirements. Availability uses the provider's
`status('gen5_bw')`, backed by the engine's validated asset-pack API. See
[battle-sprite-imports.md](battle-sprite-imports.md).

The provider API is independent of extraction. The voxel export
`registerBattleSpriteProvider(source,label,provider)` accepts API 2 providers
with `capabilities.contract="national-dex-battle-sprites"` and a
`frame(request)` function. Providers should also expose `status(source)` with
a boolean `ready` field for configuration guidance. New supported sources
become selectable rows; registering `gen5_b2w2` is rejected. The request
contains source, national dex, front side, shiny, gender, base form, battle
and actor identity; results contain an image and integer width/height up to
256. nil/invalid/error results retain native art. Providers own timing, bounded
image caches and cleanup; the voxel renderer never reads a ROM or extracted
pack files.

Both actors use front artwork as before. GPU transforms fit it within the
existing 56-pixel card footprint without baking another resized sprite. The
native draw path retains box visibility, slides, fainting and attack layers.
Trainer pictures, substitutes and Unown forms remain native. Temporary method
wrappers are restored even if a draw fails. Native mode does not query a
provider. Imported sprite animations are the original battle idle animations,
not newly authored move animations.

Focused tests cover configuration, provider behavior and billboard sizing:
`test_battle_sprite_config.lua`, `test_battle_sprite_provider.lua` and
`test_variable_sprite_billboards.lua`. The workspace
`gen5_battle_sprite_live.lua` driver exercises live Gold battles. No ROMs or
extracted packs are included in mod ZIPs. Physical iOS/Android and all species
have not been exhaustively visually tested.

The battle compositor also follows the engine's iOS vertical correction. The
Gen 2 overworld correction lives in gen1recomp, so that part needs an engine
update. It is regression-tested against the existing iOS/LÖVE 12 policy, not
verified on an actual iOS device. Authored voxel profiles are unchanged.
