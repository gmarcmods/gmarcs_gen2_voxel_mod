"""Validate edition catalogs and assemble the single GEN2_ES font recipe."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]/'translations'

def assemble(root=ROOT):
    for edition in ('gold','silver','crystal'):
        source=root/(edition+'_es')
        audit=json.loads((source/'text-audit.json').read_text())
        if audit['game']!=edition or any(audit['untranslated'].values()):
            raise ValueError('Incomplete original Spanish catalog: '+edition)
        expected=(4000,1004) if edition=='crystal' else (3042,882)
        if (audit['dialogue'],audit['rom_text'])!=expected:
            raise ValueError('Unexpected native catalog inventory: '+edition)
        mail=json.loads((source/'mail-provenance.json').read_text())
        if mail['game']!=edition or not mail['mail'] or {v['command'] for v in mail['mail']}!={'givepokemail','checkpokemail'}:
            raise ValueError('Missing original gift/recipient mail coverage: '+edition)
        if len({v['translated'] for v in mail['mail']})!=1:
            raise ValueError('Conflicting native mail correspondence: '+edition)
        for sub in ('pack','pokedex','pokegear','trainer_card','diploma'):
            for image in (root/'gold_es/overrides'/sub).iterdir():
                if image.read_bytes()!=(source/'overrides'/sub/image.name).read_bytes():
                    raise ValueError('Edition-specific graphic requires its own binding: '+str(image))
    gold=(root/'gold_es/font_transforms.lua').read_text()
    crystal=(root/'crystal_es/font_transforms.lua').read_text()
    recipe=('local gold=(function()\n'+gold+'\nend)()\nlocal crystal=(function()\n'+crystal+
            '\nend)()\nreturn function(ctx)\n if ctx.exists("title/crystal_screen.png") then crystal(ctx) else gold(ctx) end\nend\n')
    (root/'gen2_es/font_transforms.lua').write_text(recipe)
    print('GEN2_ES: complete native catalogs; shared graphics verified; edition font recipe assembled')

if __name__=='__main__':assemble()
