# Adit

## Station board canvas

The [station board canvas](sites/station-board/README.md) is an interactive 3D study of 496 MTA station signs. Open Layer previews it directly from `sites/station-board/dist`; no installation or build is required. Drag a sign to tilt all signs together, or scroll to explore the collection.

## iPhone app

A native iPhone app for remixing subway ads during a commute. The opening station is Grand Central–42 Street. Artwork, drafts, votes, bookmarks and published reframes live on the device.

<p>
  <img src="Research/Simulator/Station.png" width="23%" alt="Grand Central station wall">
  <img src="Research/Simulator/Queued.png" width="23%" alt="A region queued in the editor">
  <img src="Research/Simulator/Published.png" width="23%" alt="Completed Friend reframe">
  <img src="Research/Simulator/Explore.png" width="23%" alt="Explore gallery">
</p>

[Watch the upward ad transition](Research/Simulator/Rolling.mp4). The floating navigation capsule supports tapping and dragging between destinations, with native Liquid Glass on iOS 26.

## Run

Open **Adit.xcodeproj** in Xcode, select the **Adit** scheme, choose an iPhone simulator and press **⌘R**. The deployment target is iOS 17. The project includes its assets and has no package dependencies. To install on a physical iPhone, select your development team in Signing & Capabilities and choose the connected phone as the run destination.

On a Mac with Xcode installed, `bash scripts/run-ios-simulator.sh` builds, installs, and launches Adit in an available iPhone simulator. It prefers an already booted iPhone, and accepts a simulator UDID as an optional argument. Existing app data is retained.

The station wall and finished-post screen use the weathered boards from the station canvas, with the saved seed 24 wear settings. Tap the station sign to browse all 496 MTA entries, including Staten Island Railway; search by station, route, line or borough. Each board is bundled for offline use with its original route badges.

Tilt an iPhone to reveal the raised edges of station signs and poster frames. In Simulator, drag a sign or frame to preview the perspective. Reduce Motion keeps the surfaces still.

## Try the original journey

1. Tap the Friend poster with the orange **596** badge. Swipe between the campaign formats and select **Reframe**.
2. With **AI brush** selected, draw a circle on the pendant and enter “Joe Goldberg.” Send the request. The train indicator and striped selection show its progress.
3. Select **Brush** to cross out a line. Choose **Add text**, enter “YOU,” and place it on the poster. Drag the layer into position. Use the layer controls to resize, rotate, edit or delete it.
4. Open **Asset library** for original campaign art and remix material. Tap an asset to place it. Undo and redo are available during the editing session.
5. Choose **Finish** after the request resolves. Share exports a flattened image. **Reframe** returns the finished print to the wall.
6. Leave the editor with the back arrow to save a draft. Reopen it from **Artist profile → Drafts**. Explore has two award votes per poster and a bookmark that adds it to **Saved**.

The station sign opens the searchable board selector, live 6-train timing and an optional notification demonstration. Tapping a nearby-ad invitation opens the campaign picker. An explicit tap on the notification demonstration requests iOS permission.

## Local services

The default ride lasts 16 seconds. Live timing is supported for the original three 6-train stops; other stations use the offline preview. Enable **Use live 6-train arrivals** from the station sign to follow the next southbound train. Adit reads the MTA GTFS-realtime feed, matches two consecutive stop predictions on the same trip, and stores the departure and arrival with each queued region. Missing or stale predictions use the offline preview. [MTA developer resources](https://www.mta.info/developers)

The standard prompt button works offline with original artwork, illustrated motifs and typographic stamps. Supported devices also show an **Image Playground** wand next to the prompt. It takes the circled region and prompt into Apple's generator and saves the accepted image with the composition. This path requires Image Playground support on the device. The simulator uses the offline renderer.

The seeded profile and feed represent the design examples. Drafts, new posts, awards and bookmarks are local. Geolocation, remote push, accounts and multi-user synchronization require additional integrations.

## Test

Choose **Product → Test** (**⌘U**) on an iPhone simulator. The UI test target uses its own library. It exercises publication, persistence across relaunch, drawing history, pending generation, text placement, votes, bookmarks, station changes, asset placement and draft deletion. Screenshots are attached to the test result.

The checked-in Xcode project runs as supplied. If changing target structure, regenerate it from **project.yml** with XcodeGen.

## Design record

- [Source-to-feature inventory](Research/Reconstruction.md) lists all 88 supplied Figma objects in canvas order.
- [Frame inventory](Research/FrameInventory.json) contains source text, children, dimensions and coordinates.
- [Build plan and recording study](Research/BuildPlan.md) records the acceptance criteria and timed sequences.
- [Coverage audit](Research/Coverage.md) records the implementation status and adaptations.

## Updating native station boards

The web canvas and native asset exporter share `sites/station-board/dist/board-texture.js` and `weathering.js`. The app uses native image assets with the procedural height-map finish baked under the default light, plus a subtle motion-responsive SwiftUI surface; it does not load a web view. Existing station strings in saved drafts remain compatible.

With the Open Layer preview running, open it in `agent-browser`, obtain the browser address with `agent-browser get cdp-url`, then run:

```sh
node scripts/export-station-boards.mjs '<CDP websocket URL>' '<preview URL>/'
```

The exporter writes the 496 asset images from the saved wear defaults and refreshes the station records in `Adit/StationBoards.swift`. Avoid navigating the export browser until it finishes. `Adit/StationBoards.swift` contains the matching station catalog. A UI journey test covers a station outside the original set, search, selection persistence, and opening the editor; run it in Xcode on an iPhone simulator.
