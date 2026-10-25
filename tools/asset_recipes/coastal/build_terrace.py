#!/usr/bin/env python3
"""Compile source-referenced geometry; no ROM pixels are written to the mod."""
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[6]
sys.path.insert(0,str(ROOT/'workspace/tools/voxels'))
import geometry
recipe=json.loads(Path(__file__).with_name('cherrygrove-terrace.voxel.json').read_text())
model=geometry.compile(recipe)
assert model['components']==1 and model['bounds']==[0,0,0,31,7,31]
placement=recipe['placement'];identity=recipe['identity']
def lua(value):
    if isinstance(value,str):return json.dumps(value)
    if isinstance(value,list):return '{'+','.join(map(lua,value))+'}'
    if isinstance(value,dict):return '{'+','.join(k+'='+lua(v)for k,v in sorted(value.items()))+'}'
    return str(value)
spec={'tiles':placement['tiles'],'placements':placement['at8px'],'runs':model['runs'],
      'height':identity['height'],'capBounds':identity['capBounds'],'materials':identity['materials'],
      'voxels':model['voxelCount'],'sourceTiles':placement['tiles']+[[identity['materials']['topTile']]*4]}
text='-- Generated from tools/asset_recipes/coastal/cherrygrove-terrace.voxel.json.\nreturn '+lua(spec)+'\n'
output=Path(__file__).resolve().parents[3]/'data/cherrygrove_terraces.lua'
output.write_text(text)
print(model['voxelCount'],'voxels;',model['exposedFaces'],'exposed unit faces; one connected terrace')
