# Optional Black / White battle sprites

Import your own supported Black / White ROM in gen1recomp’s Extras (IMPORTERS), then choose BLACK/WHITE under BTL SPRITES. No separate sprite-provider mod is needed as of authored release 1.0.15. Black 2 / White 2 is not supported; old selections use NATIVE.

The voxel mod declares the optional gen5_bw/battle_sprites asset pack in its manifest. Its bundled ImportedBattleSprites adapter uses mod.packs to validate and read that pack, preserving animated native-resolution fronts and bounded image caches. No ROM, extracted graphics or private cache paths are included in the ZIP. Native artwork remains available when the pack is missing. Configuration displays IMPORT ROM and explains the supported ROM/import action.

Previously BTL SPRITES silently depended on GEN5_PRIVATE_SPRITES. Testing with that companion installed masked the missing standalone integration. The old provider is no longer required; it can be disabled. Registered external providers remain supported for deliberate extensions.

Tests: test_bundled_battle_sprites.lua, test_battle_sprite_config.lua, test_battle_sprite_provider.lua. The workspace gen5_battle_sprite_live.lua driver with GEN5_STANDALONE=1 asserts that the companion is absent, then renders real Gold battles using the engine-imported pack. Both actors and attack animation were captured. Desktop validation only.
