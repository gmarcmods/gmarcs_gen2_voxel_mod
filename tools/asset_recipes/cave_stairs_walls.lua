return {tilesets={TILESET_CAVE={
 classes={cave_rim={base='wall',height=16,art='flat'}},
 pins={
  -- The rocky perimeter is a continuous top at the same height as tile
  -- 22, not a bank of upright sprites folded independently by column.
  cave_rim={5,7,10,11,21,23,36,37,38,39},
  -- Actual stair drawing repeats the 54/55 pair across both tile rows.
  -- South is walking floor; north is the 16px raised rock platform.
  stair_n={54,55},
 },
}}}
