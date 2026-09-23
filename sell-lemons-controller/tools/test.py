import argparse,subprocess,json,tempfile,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--luau-dir',type=Path,required=True);args=ap.parse_args()
suffix='.exe' if (args.luau_dir/'luau.exe').exists() else ''
compiler=args.luau_dir/('luau-compile'+suffix)
runtime=args.luau_dir/('luau'+suffix)
# The integration fixture must load the same modules in the same order as the
# shipped bundle, or core/runtime dependency bugs can disappear in the harness.
manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
integration=(ROOT/'tests/integration.spec.luau').read_text(encoding='utf-8')
loaded=re.findall(r"do local initialize=require\('\.\./([^']+)'\)",integration)
assert [p+'.luau' for p in loaded]==manifest['entry'],'Integration initialization order differs from the bundle'
files=sorted((ROOT/'src').rglob('*.luau'))+sorted((ROOT/'loader').glob('*.lua'))+sorted((ROOT/'dist').glob('*.lua'))
for p in files:
    r=subprocess.run([str(compiler),str(p),'--text'],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    if r.returncode:raise RuntimeError(f'{p}: {r.stderr.decode("utf-8",errors="replace")}')
print('Compiled',len(files),'files')
for p in sorted((ROOT/'tests').glob('*.spec.luau')):
    subprocess.run([str(runtime),str(p)],check=True,cwd=ROOT)
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau',prefix='loader-generated-',dir=ROOT/'tests',encoding='utf-8',delete=False) as f:
    f.write('local loaderFactory=function()\n'+(ROOT/'loader/private-loader.lua').read_text(encoding='utf-8')+'\nend\n')
    f.write("require('./loader-cases')(loaderFactory,require('./mock-engine'))\n")
    generated=Path(f.name)
try:
    subprocess.run([str(runtime),str(generated)],check=True,cwd=ROOT)
finally:
    generated.unlink()
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau',prefix='public-loader-generated-',dir=ROOT/'tests',encoding='utf-8',delete=False) as f:
    f.write('local loader=function()\n'+(ROOT/'loader/one-line.lua').read_text(encoding='utf-8')+'\nend\n')
    f.write("require('./public-loader-cases')(loader)\n")
    generated=Path(f.name)
try:
    subprocess.run([str(runtime),str(generated)],check=True,cwd=ROOT)
finally:
    generated.unlink()
