# NOOR — Procedural Islamic Geometry & Heritage Architecture

**An interactive 3D procedural computer graphics application built with Godot 4 and GDScript.**

CSE 400 final-year computer graphics project · Sylhet International University, Sylhet, Bangladesh

---

## 1. Project Overview

NOOR is an interactive 3D application that demonstrates how Islamic geometric art is
constructed mathematically and how those constructions can be applied to
heritage-inspired architecture. It combines four things in one program:

1. **A procedural geometry laboratory** — every pattern (stars, rosettes,
   polygons, tessellations, a simplified girih-inspired network) is generated at
   runtime from mathematical parameters that the user can change with live
   surrounding controls.
2. **A 3D transformation studio** — any generated 2D pattern can be extruded,
   chamfered, given materials, rotated (with the transformation matrix shown
   live), measured and exported as PNG or OBJ.
3. **An explorable architectural environment** — a courtyard with arcades, a
   domed prayer hall, four minarets, a grand entrance portal, a fountain and
   patterned inlays, **all generated procedurally at startup** (there are no
   pre-made 3D models in this project).
4. **An educational mathematics mode** — ten interactive 2D demonstrations of
   the mathematics behind the patterns, with live values for every formula.

Every major geometric element is produced by the project's own code from sine
and cosine, angles, polar/cartesian coordinates, rotation matrices and
symmetry operations. The user can interact with, modify and understand the
generated geometry — nothing is a static image or a hand-modelled asset.

---

## 2. Problem Statement

Islamic geometric patterns are an important part of Islamic artistic and
architectural heritage, characterised by symmetry, repetition, polygons, stars
and tessellation. However, most digital presentations of these patterns are
static images or manually modelled decorations: they do not show *how* the
geometry is constructed, how mathematical parameters change the result, or how
2D patterns become 3D architectural elements. Students of computer graphics
also struggle to connect mathematical geometry, procedural modelling,
transformations and real-time rendering using static examples alone.

**NOOR** addresses this by generating patterns through mathematical algorithms,
exposing every parameter interactively, transforming the results into 3D
geometry, and embedding them in an interior-consistent architectural
environment that the user can walk through and inspect.

---

## 3. Objectives

1. Build a real-time 3D Islamic heritage-inspired environment in Godot.
2. Implement procedural generation for stars, polygons, rosettes,
   tessellations and a girih-inspired network.
3. Demonstrate rotational, reflection and radial symmetry explicitly in code
   and in the learning mode.
4. Convert 2D patterns into 3D meshes (flat decals and extruded relief).
5. Generate architectural components procedurally (arches, columns, dome,
   drum, minarets, walls, fountain, panels).
6. Apply user-generated patterns to architectural surfaces.
7. Implement orbit and first-person camera systems with object interaction.
8. Provide a polished parameter-driven GUI with live updates.
9. Demonstrate transformations, materials, lighting, shading and real-time
   rendering concepts.
10. Explain the mathematics of the generated geometry with live numbers.

---

## 4. Technology Stack

| Component | Choice |
|---|---|
| Engine | Godot 4.x (developed and tested on **Godot 4.7.2 stable**) |
| Language | GDScript (typed where practical) |
| Renderer | Forward+ (Vulkan); the project only uses features that also degrade gracefully |
| Platform | Windows desktop (renders on integrated Intel GPUs at ~20–30 fps, faster on discrete GPUs) |
| Geometry | 100% procedural — `SurfaceTool`/`ArrayMesh` built at runtime |
| UI | Godot `Control` nodes with a fully code-built theme (no external assets) |
| Shaders | One custom shader: the fountain water (`shaders/water.gdshader`) |

No third-party assets, models, textures or themes are used. All icons (slider
grabbers, checkmarks, arrows), all materials and all geometry are generated in
code, so the project is fully self-contained.

---

## 5. System Architecture

```
                        +-----------------------------+
                        |       main.tscn / main.gd    |
                        |   (root scene, theme, fade,  |
                        |    screen manager, toasts)   |
                        +--------------+--------------+
                                       | screen_requested(id)
        +---------------+--------------+--------------+----------------+
        |               |              |              |                |
   main_menu        world_screen     lab_screen    studio_screen   learning / settings
        |               |              |              |                |
        |        ArchitectureGenerator  PatternEngine  PatternEngine    GeometryCanvas
        |               |              |              |                |
        |        interactive proxies  MeshBuilder    MeshBuilder     MathUtils
        |               |              |              |                |
        +-------+-------+--------------+--------------+----------------+
                |
        +-------+-----------------------------------------------------+
        |                       Autoload singletons                    |
        |  AppState (settings, input map, time of day)                 |
        |  PatternLibrary (pattern configs, panels, saved patterns)    |
        |  DevCapture (developer test/capture tooling)                 |
        +--------------------------------------------------------------+
```

**Layering rule:** geometry mathematics never knows about UI, rendering or
scenes. `MathUtils` → generators → `PatternEngine`/`ArchitectureGenerator` →
`MeshBuilder` → screens. Communication between screens goes through
`PatternLibrary` signals, so applying a pattern rebuilds only the affected
panel.

### Geometry generation workflow

```
 PatternConfig (all parameters)
        |
        v
 PatternEngine.generate()
        |            generator dispatch by pattern type
        v
 StarGenerator / PolygonGenerator / RosetteGenerator /
 TessellationGenerator / GirihGenerator
        |            all return PatternGeometry:
        |            fills[] + accents[] + segments[] + guides[]
        v
 MeshBuilder.build_pattern_layers()
        |            per layer: fan triangulation + extrusion (+chamfer)
        v
 3 x ArrayMesh (fill / accent / line) with explicit normals
        |
        +--> PatternViewport (live 3D preview, orbit camera)
        +--> PatternPanel (architectural inlay, fitted + framed)
        +--> PatternViewport.export_flat() (transparent 2D PNG)
        +--> MeshExporter.export_obj() (Wavefront OBJ)
```

### User interaction workflow (laboratory ⇄ architecture)

```
 Explorer: click a patterned panel        Laboratory: adjust parameters
        |                                         |
        v                                         v
 Info panel: "Edit Pattern"  ------>  PatternLibrary.lab_config loaded
        |                                         |
        |                                live rebuild + live formulas
        |                                         v
        |                              "Apply to Panel" pressed
        |                                         |
        v                                         v
 PatternLibrary.assign_panel() ---> signal panel_changed(panel_id)
        |                                         |
        v                                         v
 only that PatternPanel rebuilds  (architecture is never regenerated)
```

---

## 6. Project Directory Structure

```
NOOR/
├── project.godot                # Godot project configuration (autoloads, window, rendering)
├── icon.svg                     # Procedurally drawn application icon (SVG)
├── README.md
├── scenes/
│   ├── main/main.tscn           # Root scene (screen manager)
│   ├── screens/                 # One scene per screen (menu, world, lab, studio, learning, settings)
│   └── geometry/pattern_viewport.tscn   # Reusable 3D preview rig (SubViewport + orbit camera)
├── scripts/
│   ├── core/                    # app_state, pattern_library, pattern_config, main, dev_capture,
│   │                            # godot_compat, selftest
│   ├── geometry/                # math_utils, pattern_geometry, symmetry_manager, generators,
│   │                            # pattern_engine, mesh_builder, mesh_exporter
│   ├── architecture/            # arch/column/dome/minaret/decoration generators,
│   │                            # pattern_panel, architecture_generator (assembly)
│   ├── materials/               # material_library (materials + colour palettes)
│   ├── interaction/             # interactive_object (hit proxies), object_information (database)
│   ├── camera/                  # orbit_camera, first_person_controller
│   └── ui/                      # screens, theme, helpers, canvases, info panel
└── shaders/water.gdshader       # Fountain water (vertex displacement + ripple normals)
```

45 GDScript files, ~8,200 lines. Roughly 42,000 triangles of patterns and
90,000 triangles of architecture are generated per session.

---

## 7. Procedural Geometry Algorithms

All formulas below are exactly what the code implements
(`scripts/geometry/`).

### 7.1 Regular polygons (`MathUtils.polygon_vertices`)

Vertices at equal angular intervals:

```
θ = 2π / n
P_k = (R·cos(φ + k·θ), R·sin(φ + k·θ)),  k = 0 … n−1
```

Derived quantities used by the learning mode: side `s = 2R·sin(π/n)`,
apothem `a = R·cos(π/n)`, interior angle `(n−2)·180°/n`, interior angle sum
`(n−2)·180°`.

### 7.2 n-point stars (`MathUtils.star_vertices`)

2n alternating vertices — outer points at radius `R`, valleys at radius `r`
half an angular step between them:

```
outer_k = (R·cos(φ + kθ), R·sin(φ + kθ))
inner_k = (r·cos(φ + (k+½)θ), r·sin(φ + (k+½)θ))
```

`r/R` is the *inner radius ratio* slider. The star pattern fills this polygon
with the accent colour, draws its outline as extruded ribbons, adds concentric
line-only rings (alternate rings rotated by θ/2 for the classic interlocked
reading), a sunburst of radial lines and accent bosses on the rim.

### 7.3 Star polygons {n/k} (`MathUtils.star_polygon_circuits`)

Connect vertex `i` to vertex `i+k (mod n)` until the path closes. If
`gcd(n,k) > 1` the figure splits into `gcd(n,k)` closed circuits — the
mathematical reason some stars are drawn "woven" from several strokes. Used by
the learning mode's Star Polygons topic.

### 7.4 Rosette (`RosetteGenerator`)

The signature motif, built in layers:

* petal kites on the symmetry axes: `(r_in·0.82) → (R·0.97)` with half-width
  `0.46·θ` at radius `0.52R`;
* two interlocking n-point stars at radius `0.97R`, one rotated by θ/2;
* nested petal rings at `0.45ⁿ` scale for the repetition parameter;
* accent bosses on the disc rim, count = symmetry slider.

Only the outermost petal ring receives an accent fill; deeper layers are line
work — this guarantees no two opaque accent polygons ever overlap (which would
cause z-fighting).

### 7.5 Symmetry operations (`SymmetryManager`)

```
rotate(p, α):            p' = (x·cosα − y·sinα, x·sinα + y·cosα)
reflect across x-axis:   p' = (x, −y)
reflect across axis α:   p' = rotate(reflect(rotate(p, −α)), α)
radial replication:      N copies at angles α + k·2π/N
wedge replication:       design in [0, 2π/N], then rotate + mirror N times
```

The *wedge method* is the historical drafting technique (design one wedge,
replicate by rotation and reflection) and is used by the rosette accent field,
the girih medallion and demonstrated live in the learning mode.

### 7.6 Tessellations (`TessellationGenerator`)

* **Square**: cells on a square lattice; each cell is filled (checkerboard of
  fill/accent), carries an inscribed star plus its half-step twin and a centre
  diamond; cell outlines are deduplicated so shared edges are drawn once.
* **Hexagonal**: axial lattice `x = 1.5·t·q`, `y = √3·t·(r + q/2)`; three
  colours cycle across cells; each cell carries a hexagram and inner hexagon.
* **Triangular**: alternating up/down triangles (offset by half a side per
  row) in fill/accent colours, each decorated with its medial triangle
  (midpoint connections) and centre spokes.

The clip test keeps every cell whose centre lies within the outer radius, so
the tile field reads as a medallion.

### 7.7 Girih-inspired network (`GirihGenerator`) — *simplified*

**Documented limitation:** this is a simplified procedural construction, *not*
the historical girih tile-drafting method (which assembles decorated decagons,
pentagons, hexagons, bowties and rhombs and then interlocks them). NOOR
generates the classic *outcome* computationally: n-fold stars on a square
lattice, two parallel strap polygons per neighbour (each strap follows a star
edge into the gap, so straps share edges with the stars instead of
overlapping), diamond tiles at cell centres, and an optional centred medallion
whose fold count is the symmetry slider.

### 7.8 From 2D to 3D (`MeshBuilder`)

* **Extrusion**: each closed polygon is triangulated by a fan from its polygon
  centroid (valid because every generated outline is star-shaped with respect
  to its centre), duplicated at `z = 0` and `z = depth`, and the walls are
  emitted as quads. A bevel inserts two inset loops near the caps, where the
  inset is a uniform scale toward the centroid (a documented approximation of
  a true polygon inset).
* **Lines** are ribbons: each segment becomes a quad of the configured
  thickness, and junction dots are placed wherever two or more segment
  endpoints meet, so corners never show gaps.
* **Layer stacking** places fills at `z ∈ [0, d]`, accents above them and
  lines above those, each separated by a 4 mm-scale gap so no two surfaces are
  ever coplanar (preventing z-fighting).
* **Winding/normals**: a single helper (`MeshBuilder.add_triangle`) orders
  every triangle so Godot's front-face convention matches the requested
  outward normal, and vertex normals are set explicitly. The convention was
  empirically verified by the self test (see §12).
* **Revolution**: profiles `(radius, y)` are revolved for domes, drums,
  columns, finials, rings and the fountain. Curved surfaces use analytic
  per-vertex normals derived from the profile tangent — no smoothing
  algorithms needed.
* **Vectorisation**: deduped segments, cached column/dome/arch meshes, shared
  materials and `MultiMeshInstance3D` for crenellations and balustrades
  (hundreds of copies in one draw call).

---

## 8. Mathematical Concepts Demonstrated

| Concept | Where it is demonstrated |
|---|---|
| 2D geometry, polygons and stars | Laboratory (all pattern types), Learning topics 4, 9 |
| Polar ↔ cartesian coordinates | `MathUtils`, Learning topic 7, every formula block |
| Rotational symmetry | Laboratory symmetry slider, Learning topic 1 |
| Reflection symmetry | Wedge drafting, Learning topic 2 |
| Radial symmetry | Rosette, radial arrangement, Learning topic 3 |
| Star polygons {n/k} and gcd circuits | Learning topic 5 |
| Tessellation & the 360° vertex rule | All tessellations, Learning topic 6 |
| 2D transformation matrices | Studio rotation matrix, Learning topic 8 |
| 3D modelling & mesh generation | Everything in the explorer; Studio extrusion |
| Surface of revolution | Dome, drum, columns, minarets, fountain |
| Arch curves (two-centred, horseshoe) | `ArchGenerator`, Learning/Explorer info panels |
| Materials & shading (PBR) | `MaterialLibrary`, all scenes |
| Lighting (directional + point, shadows) | Explorer day/night presets |
| Camera systems (orbit + first person) | Explorer (`C` toggles) |
| Ray casting for interaction | `InteractiveObject` proxies + `intersect_ray` |
| Real-time rendering | Every parameter change rebuilds geometry live (~2–30 ms) |
| Shader-based animation | Fountain water vertex displacement |

---

## 9. Main Features

* **Main menu** with a live rotating 12-fold rosette rendered behind it and
  ornamental borders drawn with the 2D canvas API.
* **Geometry Laboratory** — pattern type dropdown, 11 live parameters, colour
  palettes + custom colours, fill/line/guide layer toggles, generate /
  randomize (seeded, deterministic) / reset, save & load configurations
  (JSON), PNG export of the 3D preview and transparent flat PNG export,
  "Send to 3D Studio", "Apply to Panel", live construction formulas, live
  statistics (shape counts, triangles, generation time, seed) and a
  construction-guide overlay (vertices, symmetry axes, construction circles).
* **3D Transformation Studio** — extrusion depth, chamfer (bevel), scale,
  interactive rotation about X/Y/Z with the **live transformation matrix**
  displayed, 9 material choices or the palette, 3 preview environments,
  wireframe, auto-rotate, measured area / extruded volume / bounds, PNG and
  OBJ export.
* **Architecture Explorer** — orbit camera (drag, pan, zoom, focus presets,
  double-click frame) and first-person walker (WASD, Shift run, Space jump,
  mouse look, Escape releases the cursor), hover highlighting, click-to-inspect
  information panels with construction, mathematics and a **live pattern
  preview** (with Edit Pattern), 6 time-of-day lighting presets with glowing
  lanterns at dusk/night, and one-click pattern editing of every inlaid panel.
* **Mathematics & Learning** — ten animated 2D demonstrations, each with
  controllable parameters, live formulas, and "Open in Geometry Laboratory".
* **Settings** — shadows, SSAO, glow, reflections, MSAA, VSync, time-of-day
  preset with sun-colour swatch, first-person and orbit control preferences,
  restore defaults, GPU/engine information.
* **Global** — smooth screen fade transitions, toast notifications, F12
  screenshot, consistent code-built UI theme, quality settings applied live
  everywhere.

The procedural architecture contains: a 44×44 m courtyard with marble floor,
inlay bands and a 17×17 m floor medallion; a fountain with shader water; two
seven-bay arcades on stepped stylobates with columns sharing one cached mesh,
patterned wall panels, crenellated roofs and hanging lanterns; a domed prayer
hall on a terrace (four-iwan plan, mihrab niche, interior dome shell,
chandelier, floor medallion) with a 16-sided drum carrying a blind-arch
arcature and a ribbed onion dome with finial; a grand entrance portal with two
towers, open wooden doors with gold studs and a pattern panel above the arch;
a walled forecourt; and four minarets with balconies, balustrades, lanterns and
onion caps.

---

## 10. Installation

Requirements: **Windows desktop** and **Godot 4.x** (a 4.7 build was used).
No other dependencies.

1. Install Godot 4 from <https://godotengine.org/download> (standard build).
2. Copy this project folder anywhere.
3. Open `project.godot` with the Godot editor (or run it directly — see below).

## 11. How to Run

**Easiest — double-click `run_noor.bat`** in the project folder. It finds your
Godot 4 installation automatically and launches NOOR.

**From the editor:** open `project.godot` with Godot and press **F5**.

**From the command line** (replace the Godot executable path with yours):

```bash
Godot_v4.7.2-stable_win64.exe --path "path/to/NOOR"
```

The batch file can also pass arguments through to Godot, e.g.
`run_noor.bat --headless --quit-after 3600 -- --selftest`.

The application opens on the main menu. Saved patterns, exported images and
screenshots are written to the user data folder
(`%APPDATA%\Godot\app_userdata\NOOR...` — screens in `exports/`,
`screenshots/` and `patterns/`); the laboratory and settings screens show the
exact paths when exporting.

### Developer tooling (optional)

The project ships with its own headless test harness and capture tooling:

```bash
# run the full self test suite (119 checks) and print a report
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --selftest

# drive the real UI with synthesized clicks and key presses
# (menu navigation, object panel, camera toggle, drag orbit, wheel zoom)
Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-uitest

# export one flat transparent PNG per pattern type into a folder
Godot_v4.7.2-stable_win64_console.exe --path . -- --flat-export=C:/tmp/flat

# open a screen directly, set the lighting preset, select an object, capture a screenshot
Godot_v4.7.2-stable_win64_console.exe --path . -- --screen=world --cam=dome --time=5 \
    --dev-select=dome --capture=C:/tmp/shot.png --capture-after=140
```

`--cam` presets: `overview`, `fountain`, `dome`, `gate`, `medallion`,
`minaret`, `arcade_west`. `--time` is 0–5 (Dawn…Night). `--dev-mode=first_person`
starts in the walker. `--dev-lab-export` exercises the laboratory's PNG
exports.

## 12. Screenshots

Verified captures live in `docs/screenshots/` (all taken from the running
application — no mock-ups):

| File | Shows |
|---|---|
| `01_main_menu.png` | Main menu over the live rotating rosette |
| `02_geometry_laboratory.png` | Laboratory with live formulas and statistics |
| `03_transformation_studio.png` | Studio with measurements and the live matrix |
| `04_mathematics_learning.png` | Rotational symmetry demonstration |
| `05_settings.png` | Graphics / lighting / control settings |
| `06_architecture_overview.png` | Courtyard overview (afternoon) |
| `07_architecture_dusk.png` | Dusk lighting with glowing lanterns |
| `08_first_person_view.png` | First-person view of the hall façade |
| `09_object_information.png` | Information panel with live pattern preview |
| `10_night_fountain.png` | Night close-up of the fountain inlay |
| `11..14_pattern_*.png` | Transparent flat exports of star / rosette / tessellation / girih patterns |

## 13. Controls

| Context | Input | Action |
|---|---|---|
| Anywhere | F12 | Save a screenshot |
| Menu / panels | Escape | Back to the menu (world screen: close panels instead) |
| Explorer (orbit) | Left-drag | Orbit · Right-drag / middle-drag: pan |
| Explorer (orbit) | Wheel | Zoom · right double-click: frame object |
| Explorer (orbit) | Left-click | Inspect object (information panel) |
| Explorer | C | Toggle orbit ⇄ first person |
| Explorer | T | Cycle time of day · H: help |
| Explorer (first person) | W A S D / Shift / Space | Walk / run / jump |
| Explorer (first person) | Mouse / left click | Look / inspect crosshair target |
| Explorer (first person) | Escape | Release the mouse cursor |
| Laboratory | any control | Geometry rebuilds live (~90 ms debounce) |

Verified workflows (all exercised during development):

1. **Generate a pattern** — pick "Star (n-point)", change rotation, inner
   radius, repetition; export a PNG.
2. **2D → 3D** — "Send to 3D Studio", raise the extrusion, add a bevel,
   choose Bronze, rotate, export OBJ.
3. **Pattern → architecture** — in the explorer click the floor medallion or a
   wall panel → "Edit Pattern" → adjust → "Apply to Panel": only that panel
   rebuilds, the architecture is untouched.
4. **Learn the mathematics** — "Mathematics & Learning" → rotational symmetry
   → change N → read the live angle values → "Open in Geometry Laboratory".

---

## 14. Testing

`-- --selftest` runs **119 automated checks** (headless, CPU-only) covering:

* the Godot front-face winding convention probe (normals are verified against
  the engine's actual behaviour, not assumed);
* polygon/star/polar/reflection/star-polygon mathematics;
* all 10 pattern types at preset, minimum and maximum parameters — validity,
  finiteness, bounds, determinism, and generation timing;
* mesh building for every pattern type (extruded and flat), normal lengths,
  triangle counts; boxes, smooth and faceted revolutions;
* every architectural component (three arch curve families, arched walls,
  bands, columns, domes, ribs, minarets, fountain, panels) and the **full
  architecture assembly** (≥15 top-level groups, >40 collision entries, >30
  interaction proxies, 5 pattern panels, 14 lantern lights, 90k triangles);
* pattern configuration JSON round-trips, saved-pattern save/load/delete;
* loading every script and scene, and **constructing every screen** in the
  tree to catch broken node paths without rendering.

`-- --dev-uitest` drives the real UI with synthesized mouse and key events and
verifies 18 click-level behaviours: every main-menu entry opens its screen and
returns, clicking the 3D world opens an information panel (Escape closes it),
`C` toggles first person, left-drag orbits the camera, the mouse wheel zooms,
and the laboratory ⇄ studio navigation works.

Additionally, every screen was verified visually on a real GPU during
development via the capture tooling (menu, all 10 flat pattern exports,
laboratory, studio, learning, settings, explorer from 4 camera presets and
6 lighting presets, first-person view, information panel with live preview,
night lantern lighting).

**Honest status:** the application has been verified on this project's
development machine (Intel UHD 620 integrated GPU / Windows). Frame rates of
~20–30 fps were measured at 720p with default quality on integrated graphics;
discrete GPUs run comfortably faster. Only one machine/GPU configuration was
tested.

## 15. Known Limitations

* **Girih patterns are simplified.** The star-and-cross network is a procedural
  approximation of the girih family, not the historical tile-drafting method
  (see §7.7). This is stated in the UI as well.
* **Architecture is an interpretation**, not a reconstruction of any specific
  monument; several traditions (courtyard arcades, onion domes, minarets) are
  combined into one consistent design language.
* **Chamfer/inset approximation:** bevels inset polygons by uniform scaling
  toward the centroid, which is exact for circles but approximate for long thin
  polygons.
* **Line crossings z-fight in principle.** Line ribbons are coplanar by design;
  where lines cross (e.g. the interlocking rosette stars) the crossing patch is
  drawn twice at the same depth. In practice the overlap is sub-millimetre
  scaled and has not produced visible artefacts in testing, but it is a known
  geometric overlap rather than a modelled intersection.
* **Architectural panels are shallow inlays:** pattern relief on building
  surfaces is clamped (≤0.05 pattern units) so it stays physically plausible;
  the studio shows the full relief.
* **No audio.** The application is visual-only; no sound assets are used.
* **Performance on integrated GPUs:** shadows + SSAO + MSAA together cost
  visible frame rate on Intel UHD-class hardware; the settings screen exposes
  every option to trade quality for speed.
* **Collision is deliberately simple** (boxes, cylinders and ramps over the
  major solids). Small decorative parts have no collision, and the stylobate
  steps use invisible ramps so walking feels smooth.
* **Panels' fit is proportional:** the pattern is scaled to fit each panel's
  rectangle; extremely stretched aspect ratios change line thicknesses
  proportionally (line thickness is set in pattern units).

## 16. Future Improvements

* Implement true historical girih tile drafting (decagon/pentagon/hexagon tile
  set with interlacing) as an optional advanced mode.
* Curved-surface pattern application (bending pattern strips around drums and
  domes) for richer decoration.
* Pattern-aware architectural materials (inlaying the generated pattern
  directly into tile textures for distant surfaces).
* Volumetric light shafts, baked lightmaps and a proper day/night cycle
  animation with moving sun.
* More architectural components (muqarnas cornices, iwan stalactites,
  minbar, screens) and additional plan layouts (chahar-bagh garden courtyard).
* Pattern history/undo, richer pattern gallery, and SVG vector export in
  addition to PNG.
* Mobile/handheld build and touch camera controls.
* Localisation of the interface (Bangla/English).

---

## 17. Academic Context

This project was developed as the final-year CSE 400 computer graphics project
at Sylhet International University. It demonstrates the practical application
of mathematical geometry, procedural mesh generation, 3D modelling,
transformations, materials, lighting, shading, camera systems and interactive
computer graphics using a modern game engine — with every geometric element
generated by the project's own algorithms.

*Engine APIs follow the installed Godot 4.x version; the project was developed
and verified against Godot 4.7.2 stable.*
