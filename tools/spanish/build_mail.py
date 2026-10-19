"""Extract script mail operands from paired original editions; no ROM bytes exported."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
import build
ROOT=next(p for p in Path(__file__).resolve().parents if(p/'workspace/mods.json').is_file())
def generate():
    for edition in ('gold','silver','crystal'):
        en_path=ROOT/'roms'/f'{edition}.gbc'
        es_path=ROOT/'roms'/('gold_esp.gbc'if edition=='gold'else edition+'_es.gbc')
        en,es=en_path.read_bytes(),es_path.read_bytes()
        engine=ROOT/'gen1recomp'
        manifest=build.variant_manifest(engine,edition,en,es)
        with tempfile.TemporaryDirectory()as tmp:
            metadata=Path(tmp)/'scripts.json'
            subprocess.run(['luajit',str(Path(__file__).with_name('export.lua')),str(engine),str(en_path),str(es_path),str(metadata),edition,hashlib.sha1(en).hexdigest()],check=True,capture_output=True)
            maps=json.loads(metadata.read_text())
        mapper=build.Mapper(en,es,{int(k):v for k,v in maps['opcodes'].items()});mapper.maps(maps)
        catalog,proof=build.extract_mail_messages(mapper,en,es,*build.character_maps(manifest))
        target=Path(__file__).resolve().parents[2]/'translations'/(edition+'_es')
        build.write_mail_output(target,edition,en,es,catalog,proof)
        print(edition,catalog)
if __name__=='__main__':generate()
