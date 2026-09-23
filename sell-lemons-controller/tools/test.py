import argparse,subprocess,json,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--luau-dir',type=Path,required=True);args=ap.parse_args()
suffix='.exe' if (args.luau_dir/'luau.exe').exists() else ''
compiler=args.luau_dir/('luau-compile'+suffix)
runtime=args.luau_dir/('luau'+suffix)
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
