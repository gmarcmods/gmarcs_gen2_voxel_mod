"""Bundle explicit mod folders for one extraction into the game's Mods folder."""
import argparse
import json
import os
from pathlib import Path
import re
import tempfile
import zipfile

EXCLUDED_DIRS = {'.git', '.claude', '__pycache__', 'roms', 'baseroms', 'tests', 'docs', 'tools', 'dist'}
EXCLUDED_SUFFIXES = {'.gb', '.gbc', '.gba', '.nds', '.z64', '.v64', '.n64', '.sav', '.srm', '.log', '.pyc'}


def files(root, relative=Path(), ancestors=frozenset()):
    directory = (root / relative).resolve()
    if directory in ancestors:
        raise ValueError(f'cyclic symlink: {relative}')
    for path in sorted(directory.iterdir()):
        name = relative / path.name
        if path.name.startswith('.') or '.bak' in path.name or '.tmp' in path.name:
            continue
        if path.is_dir():
            if path.name not in EXCLUDED_DIRS:
                yield from files(root, name, ancestors | {directory})
        elif path.is_file() and path.suffix.lower() not in EXCLUDED_SUFFIXES:
            yield path, name


def build(output, folders, exclude_optional_imports=(),
          exclude_optional_dependencies=()):
    exclude_imports = set(exclude_optional_imports)
    exclude_dependencies = set(exclude_optional_dependencies)
    mods, ids = [], set()
    for folder in folders:
        root = Path(folder).resolve()
        manifest = json.loads((root / 'manifest.json').read_text())
        entry = root / manifest.get('entry','main.lua')
        # Editor profiles share a runtime through symlinks. Materializing that
        # code also needs its optional source declarations in the exported
        # manifest, while the author's project file remains untouched.
        if manifest.get('managed_by_editor') and entry.is_symlink():
            runtime_manifest = entry.resolve().parent / 'manifest.json'
            if runtime_manifest.is_file():
                runtime = json.loads(runtime_manifest.read_text())
                inherited = list(manifest.get('optional_imports',[]))
                by_id = {spec['id']:spec for spec in inherited}
                for source in runtime.get('optional_imports',[]):
                    if source['id'] in by_id and by_id[source['id']] != source:
                        raise ValueError('conflicting runtime import: '+source['id'])
                    if source['id'] not in by_id:
                        inherited.append(source);by_id[source['id']]=source
                if inherited: manifest['optional_imports']=inherited
                inherited_deps = list(manifest.get('optional_dependencies',[]))
                def dependency_id(value):
                    return value if isinstance(value,str) else value.get('id') if isinstance(value,dict) else None
                dep_ids = {dependency_id(value) for value in inherited_deps}
                for dependency in runtime.get('optional_dependencies',[]):
                    ident = dependency_id(dependency)
                    if ident and ident not in dep_ids:
                        inherited_deps.append(dependency);dep_ids.add(ident)
                if inherited_deps: manifest['optional_dependencies']=inherited_deps
        if exclude_imports:
            kept = [spec for spec in manifest.get('optional_imports', [])
                    if spec.get('id') not in exclude_imports]
            if kept:
                manifest['optional_imports'] = kept
            else:
                manifest.pop('optional_imports', None)
        if exclude_dependencies:
            kept = [dependency for dependency in manifest.get('optional_dependencies', [])
                    if (dependency if isinstance(dependency, str)
                        else dependency.get('id') if isinstance(dependency, dict)
                        else None) not in exclude_dependencies]
            if kept:
                manifest['optional_dependencies'] = kept
            else:
                manifest.pop('optional_dependencies', None)
        ident = manifest['id']
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', ident):
            raise ValueError(f'unsafe mod id: {ident}')
        if ident in ids:
            raise ValueError(f'duplicate mod id: {ident}')
        if not (root / manifest.get('entry', 'main.lua')).is_file():
            raise ValueError(f'missing entry for {ident}')
        ids.add(ident)
        mods.append((root, ident, manifest))
    output = Path(output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise ValueError(f'output exists: {output}')
    fd, staging = tempfile.mkstemp(prefix='mod-pack-', suffix='.zip', dir=output.parent)
    os.close(fd)
    try:
        with zipfile.ZipFile(staging, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for root, ident, manifest in mods:
                for path, relative in files(root):
                    if path.resolve() in {output, Path(staging)}:
                        continue
                    if relative.as_posix() == 'manifest.json':
                        archive.writestr(f'{ident}/manifest.json',json.dumps(manifest,indent=2)+'\n')
                    else:
                        archive.write(path, f'{ident}/{relative.as_posix()}')
            listing = [{'id': ident, 'version': m.get('version'), 'games': m.get('games')} for _, ident, m in mods]
            archive.writestr('mod-pack.json', json.dumps({'format': 1, 'mods': listing}, indent=2))
            archive.writestr('INSTALL.txt', '''Close the game. Extract this ZIP into the active Mods folder (each mod ID
folder must sit directly inside Mods). Back up same-ID folders before updating.
Open the game, enable the included mods for the desired game, then restart.
This is an extraction bundle: the launcher Import ZIP accepts one mod only.
No ROMs, save files or editor backups are included. Symlinked runtime libraries
are copied into the archive, so the bundle is independent of the source tree.
''')
        os.replace(staging, output)
    finally:
        if os.path.exists(staging):
            os.unlink(staging)
    return listing


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--exclude-optional-import', action='append', default=[],
                        help='omit this optional ROM/import declaration from exported manifests')
    parser.add_argument('--exclude-optional-dependency', action='append', default=[],
                        help='omit this optional mod dependency from exported manifests')
    parser.add_argument('mods', nargs='+', help='explicit mod directories; alternate voxel profiles should not be combined')
    args = parser.parse_args()
    result = build(args.output, args.mods, args.exclude_optional_import,
                   args.exclude_optional_dependency)
    print(f'Built {args.output}: ' + ', '.join(m['id'] for m in result))
