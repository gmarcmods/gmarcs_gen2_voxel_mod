# Optional Black / White battle sprites

BTL SPRITES offers NATIVE and BLACK/WHITE. Black 2 / White 2 is not a
supported choice. Older saved `gen5_b2w2` selections resolve to NATIVE.

Enable the Gen 5 sprite provider and import your own supported Black / White
ROM using IMPORTERS in the gen1recomp launcher. When the provider reports no
usable imported pack, the choice displays an IMPORT ROM reminder. The mod
configuration help explains the required ROM and launcher action. Native
sprites remain active until artwork is available.

Availability comes from the provider's `status('gen5_bw')` contract, backed
by the engine's validated asset-pack API. The voxel mod does not inspect ROM
files or private cache paths. Registered providers should implement that
status function with a boolean `ready` field.

Run the focused checks from the workspace root:

```sh
luajit mods/gen2/new_mod_ex/tests/test_battle_sprite_config.lua
luajit mods/gen2/new_mod_ex/tests/test_battle_sprite_provider.lua
```
