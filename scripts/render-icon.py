"""Rasteriza el SVG original con resvg, sin modificarlo."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build' / 'icon-tools'))
try:
    import resvg_py
except ImportError:
    raise SystemExit(
        'Instala el renderizador con: python -m pip install '
        '--target build/icon-tools -r scripts/requirements-icons.txt'
    )

if __name__ == '__main__':
    source, destination = map(Path, sys.argv[1:3])
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(resvg_py.svg_to_bytes(
        svg_path=str(source.resolve()), width=2048, height=2048,
    ))
