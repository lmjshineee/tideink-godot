# Third-party notices

The current avatars, faces, outfits, hair, ears, rig and weapons are derived from the original INKWAVE web project. Export-local shoulder, shorts and head cage corrections and the source-derived character materials are retained from preview.5. The subsequent face experiments have been removed. The original source attribution is retained; this standalone Godot project does not distribute the web application or its JavaScript conversion tools.

Modeling workflow references: [Julien Kaspar, Head Retopology of Snow](https://julienkaspar.artstation.com/blog/M3LL/head-retopology-of-snow) and [Kiel Figgins, Painting Weights and Skinning](https://www.3dfiggins.com/writeups/paintingWeights/). Only workflow guidance was consulted; no models, images or tutorial code from these sources are included.

The Godot demo includes font files from the original INKWAVE project:

- Rubik: SIL Open Font License 1.1. License text: [licenses/Rubik-OFL.txt](licenses/Rubik-OFL.txt). [Source](https://github.com/googlefonts/rubik).
- Titan One: SIL Open Font License 1.1. License text: [licenses/TitanOne-OFL.txt](licenses/TitanOne-OFL.txt). [Source](https://github.com/google/fonts/tree/main/ofl/titanone).

Historical asset conversion used vendored Three.js modules. These modules and JavaScript exporters are no longer included in the current working tree. Copyright 2010-2026 Three.js authors, MIT license. License text: [licenses/Three.js-MIT.txt](licenses/Three.js-MIT.txt). [Source](https://github.com/mrdoob/three.js).

The retained Godot resources were originally derived from [caoxing9/inkwave-game](https://github.com/caoxing9/inkwave-game) from this workspace source baseline (`deb8ef1` for character/map files) to reproduce generated maps, original skinned characters, navigation, scene visuals, weapon parameters and icons. The current project maintains local Godot assets; original web files and build/server configuration have been removed.

Original audio builders/scores (`public/game/src/audio/audio.js`, `music.js`, and configuration) and full-body character actions are also derived from that same local web-source reference. Audio is synthesized offline by those builders; no external music or sound library was added. Generated asset provenance and hashes live in `assets/audio/manifest.json` and `assets/characters/actions.json`.

The preview.11 main menu reuses the local web project logo markup and navigation/weapon SVGs (`public/game/src/ui/menus.js`, `public/game/styles/ui.css`, and icon modules). Coral Market, Prism Gallery, Viaduct and mirrored cover variants were produced by an earlier local layout adapter and material/prop builders; their baked Godot resources remain in assets/maps and assets/scenery. Nintendo Splatoon references were consulted for gameplay/stage structure only; no Nintendo models, textures, music or code are included.

Preview.14 increases analytic head, ear and rounded surface sampling through a historical export-local sampling adapter, which is no longer included. It changes tessellation, retaining the source shape functions and prior anatomy correction. Dualie, heavy and rapid weapons and their SVG icons derive from the project's source shooter/blaster meshes and icons. Modular Harbor and Terrace Garden are original layouts composed in the local arena adapter; new fields use Godot primitive meshes. No additional external model, texture, audio or Nintendo asset is included. The new font below is bundled for reliable Chinese UI.

- Noto Sans SC: SIL Open Font License 1.1. [Official Google Fonts source](https://github.com/google/fonts/tree/main/ofl/notosanssc), [license](licenses/NotoSansSC-OFL.txt). Bundled unmodified variable TTF as the Chinese fallback; source URL and SHA256 in `assets/fonts/noto-provenance.json`.

Current asset integrity is recorded in `assets/integrity.json`. Older source paths/hashes inside asset JSONs are provenance only and are not resolved by runtime, checks or export.
