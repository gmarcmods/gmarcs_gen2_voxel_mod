# Cycling Road free movement

Gen 2's old camera adapter sent every downhill map back to native grid steps.
That lost continuous camera-relative movement and walking-cycle state.
Downhill roads now use the regular free-move adapter. Its idle drift reads the
native bicycle state and downhill flag, moves south, and respects A/B braking.
Ice, currents, whirlpools, shore transitions and scripted grid movement retain
their native dispatch.

`tests/cycling_camera_live.lua` checks twelve first/third-person headings on
actual Route 17, native bicycle coasting, braking, menu ownership and the
ordinary angled-view grid fallback. The live Gold driver passes.
