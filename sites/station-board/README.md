# New York station board canvas

Interactive 3D study of 496 MTA station entries, including Staten Island Railway. Drag any board to tilt all boards together; scroll to explore. Arrow keys on a focused board also adjust the shared angle.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000 --directory sites/station-board/dist
```

Open http://localhost:8000. No installation or build step is required.

## Source

- `dist/app.js`: current 3D scene, materials, station label generation, and synchronized interactions.
- `dist/index.html`: current page structure and styles.
- `dist/stations.json`: compact station names and routes used by the canvas.
- `dist/assets/three.min.js`: bundled Three.js 0.158.0 (MIT license).
- `dist/SOURCE.md`: MTA data source and retrieval date.
- `stations-raw.json`: original MTA data snapshot.
- `board-fragment.html` and `scene-setup.js`: earlier single-board prototype and scene setup reference; the current application runs from `dist/`.
- `.openai/hosting.json`: Sites deployment configuration.

Starting settings: horizontal angle 1°, vertical angle 2°, light direction −35°, light height 46°, roughness 62%, texture depth 41%. Controls are hidden.

Hosted version: https://station-board-material-study.bruce-6996.chatgpt.site
