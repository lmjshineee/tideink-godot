# Third-party notices

The current avatars, faces, outfits, hair, ears, rig and weapons are derived from the original INKWAVE web project. Export-local shoulder, shorts and head cage corrections and the source-derived character materials are retained from preview.5. The subsequent face experiments have been removed. The source web files remain unmodified.

Modeling workflow references: [Julien Kaspar, Head Retopology of Snow](https://julienkaspar.artstation.com/blog/M3LL/head-retopology-of-snow) and [Kiel Figgins, Painting Weights and Skinning](https://www.3dfiggins.com/writeups/paintingWeights/). Only workflow guidance was consulted; no models, images or tutorial code from these sources are included.

The Godot demo includes font files from the original INKWAVE project:

- Rubik: SIL Open Font License 1.1. License text: [licenses/Rubik-OFL.txt](licenses/Rubik-OFL.txt). [Source](https://github.com/googlefonts/rubik).
- Titan One: SIL Open Font License 1.1. License text: [licenses/TitanOne-OFL.txt](licenses/TitanOne-OFL.txt). [Source](https://github.com/google/fonts/tree/main/ofl/titanone).

The small web-source reference needed by the data exporters contains vendored Three.js modules. Copyright 2010-2026 Three.js authors, MIT license. License text: [licenses/Three.js-MIT.txt](licenses/Three.js-MIT.txt). [Source](https://github.com/mrdoob/three.js).

Other web-source reference files were copied from [caoxing9/inkwave-game](https://github.com/caoxing9/inkwave-game) from this workspace source baseline (`deb8ef1` for character/map files) to reproduce generated maps, original skinned characters, navigation, scene visuals, weapon parameters and icons. The original repository is not copied wholesale.

Original audio builders/scores (`public/game/src/audio/audio.js`, `music.js`, and configuration) and full-body character actions are also derived from that same local web-source reference. Audio is synthesized offline by those builders; no external music or sound library was added. Generated asset provenance and hashes live in `assets/audio/manifest.json` and `assets/characters/actions.json`.

The preview.11 main menu reuses the local web project logo markup and navigation/weapon SVGs (`public/game/src/ui/menus.js`, `public/game/styles/ui.css`, and icon modules). Coral Market, Prism Gallery, Viaduct and mirrored cover variants are original layouts in `tools/lib/arena_layouts.mjs`, reusing the web project material/prop builders. Nintendo Splatoon references were consulted for gameplay/stage structure only; no Nintendo models, textures, music or code are included.

Preview.14 increases analytic head, ear and rounded surface sampling through an export-local adapter (`tools/lib/character_quality.mjs`). It changes tessellation, retaining the source shape functions and prior anatomy correction. Dualie, heavy and rapid weapons and their SVG icons derive from the project's source shooter/blaster meshes and icons. Modular Harbor and Terrace Garden are original layouts composed in the local arena adapter; new fields use Godot primitive meshes. No additional external model, texture, audio or Nintendo asset is included. The new font below is bundled for reliable Chinese UI.

- Noto Sans SC: SIL Open Font License 1.1. [Official Google Fonts source](https://github.com/google/fonts/tree/main/ofl/notosanssc), [license](licenses/NotoSansSC-OFL.txt). Bundled unmodified variable TTF as the Chinese fallback; source URL and SHA256 in `assets/fonts/noto-provenance.json`.
