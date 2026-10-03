"""Compose the preview tee shader, preserving source shorts/shoes/fabric detail."""
from pathlib import Path

here = Path(__file__).resolve().parent
source = (here.parents[1] / 'shaders/characters/character_cloth.gdshader').read_text()
vertex = 'void vertex(){'
anchor = '          // ---------------- material-class micro detail ----------------'
assert source.count(vertex) == 1 and source.count(anchor) == 1
source = source.replace(vertex, '#include "res://experiments/character-sculpt/tee_patterns.gdshaderinc"\n\n' + vertex)
override = '''          // Preview-only tee art. All other original garment parts stay intact.
          if (iwPart == 1.0) base = teeBody(p);
          else if (iwPart == 2.0) base = teeSleeve(p, uv, vCloth.z);
          else if (iwPart == 3.0) base = trim_color.rgb;

'''
(here / 'cloth.gdshader').write_text(source.replace(anchor, override + anchor))
print('PASS: eight tee designs composed over the original body material')
