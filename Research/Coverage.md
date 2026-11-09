# Source coverage

Read the individual Figma references in Reconstruction.md alongside this audit. The numbers below use the same canvas order. Title animation, pitch commentary and section dividers establish context for the app.

| References | Product requirement | Implementation and remaining differences |
|---|---|---|
| 1–7 | Transit identity and creative-expression theme | The opening uses original map artwork and the adit mark. The original presentation's letter-by-letter choreography belongs to the pitch. |
| 8–18 | Let ordinary commuters respond to familiar ads in short sessions | Bundled campaigns open offline, drafts save during editing, and the user can revisit a published response from the station wall. |
| 19–26 | Introduce Adit and let the rider choose an ad | Animated intro, station sign, staggered framed posters, counts and a bottom carousel with the campaign name and Reframe action. |
| 27–30 | Select the headline and pendant, then transform them while preserving the original visual | Region selection, prompt, pending stripes, portrait replacement, brush and editable text layers. New text can cover printed copy with a paper backing. The base ad is a bitmap. Compatible devices can generate an image from the selected region and prompt through Image Playground. Automatic text segmentation and seamless inpainting are unimplemented. |
| 31–39 | Support multiple art directions and spread work back into the city | Source campaign imagery, remixable variations, local wall publication and image sharing. Station placement is a digital gallery. |
| 40–48 | Nearby notification to station wall to picker | A user-triggered local notification demonstrates the invitation. Station choice is manual. No real proximity detection or remote notification service. |
| 49–54 | Circle, request, draw, type, finish and return | SwiftUI gestures update normalized layers. Jobs persist deadlines while the user edits. Finished art is editable again from the wall. Export uses the same compositing surface. |
| 55–64 | Keep the four-tool editor small and thumb accessible | AI brush, library, type and freehand brush share one bottom strip. The native keyboard, asset shelf and swatches expand on demand. |
| 65–69 | Help the user align edits and reuse art direction | Center snapping, campaign swatches, original artwork, movable/resizable/rotatable stickers, serif and sans type. Brand font files were unavailable. The freehand selection uses its bounding ellipse. |
| 70–78 | Handle underground connectivity and evoke subway signage | Offline documents, a persistent local request lifecycle, train progress, two-line station sign, route bullet, metal frames and tiled wall. Station settings can enable live southbound 6-train forecasts. The default 16-second clock and offline artwork processor reproduce the workflow without connectivity. |
| 79–85 | Retain riders through exploration, reaction and recognition | Hall of fame, Hall of cray, Most remixed, Latest Adits, exclusive award votes, profile counts, saves and draft recovery. Curated winners come from the source examples. A shared ranking service and concurrent riders are outside the local build. |
| 86–88 | Return art to the original public context | The final framed print can be shared or returned to the station wall. End-card team portraits are presentation material. |

## Source decisions

The later four-phone study supplied the wall, feed and artist-profile layout. The portfolio recordings clarified the carousel, offset poster arrangement, asset completion, color changes and shrinking return animation. Several boards are intermediate presentation transitions. Two smaller supporting objects are a dark rectangle named Friend ad and lettering named Feed Opening.

Original posters came from Figma image fills. Where standalone poster data was absent, poster content was recovered from the supplied visual studies or the local portfolio recordings. App chrome, controls, labels, frames, count badges, progress and editable content are native. Small portions of some perspective-corrected poster crops retain photographic softness or parts of the original edge treatment.

The seeded account begins with the original profile's historical counts. The two visible sample prints and local user work populate its gallery. Authentication, a full historical archive and public moderation are unavailable. New art and reactions remain on the device.

The 11 distinct embedded Figma streams could not be verified in full. The file exposes fill hashes and first frames, while the export request hit the Figma connector limit. The seven local recordings were independently available. BuildPlan.md records their durations and reviewed sequences. Frame-exact timing parity for the unexported streams remains unverified.

## Interaction fidelity

- **Launch and discovery** use the original wordmark and route graphic, followed by separately animated posters. The title card fades. The hand-authored train-line drawing in the pitch is only partially reproduced.
- **Poster selection** preserves a swipeable campaign carousel, reframe counts, rounded sheet and primary action. The three destinations share a Liquid Glass capsule with a sliding selection. Tabs retain their scroll position, and the capsule supports taps and drags. Earlier iOS versions use an ultra-thin material fallback.
- **Editing** preserves the centered print, campaign palette, four tools, circled prompt region and pending stripes. The strip above the canvas includes explicit history and exit controls. The Friend text tool can clear its original headline before placing new type. Other raster text stays part of the base artwork.
- **The train queue** persists each region and its deadline. The offline renderer can reproduce the demonstrated Joe portrait. Eligible devices expose Apple's Image Playground as a separate prompt action. A selected generated image is copied into application support, reused in the library and included in exports. Its image-generation UI needs validation on a supported physical phone.
- **Publication** renders the editable document into its station frame. Matched geometry links the result and the latest wall print. The design's precise easing, color pulses and every intermediate frame could not be compared against the unavailable embedded streams.
- **Recognition** supports the two reaction choices shown in the feed, saves, editing the artist name, published prints and resumable drafts. The experimental full-height reaction animation in the under-construction section remains partial.

## Transit validation

A native Swift check read the actual MTA feed and matched a southbound 6 trip through Grand Central and 33 St. Empty, malformed and truncated inputs were rejected. The decoder checks the feed timestamp, the route, both stop IDs, chronological order and whether the predicted arrival is still ahead. The editor uses the locally retained deadline when connectivity changes in transit. [MTA GTFS-realtime subway reference](https://www.mta.info/document/134521)

## Final simulator verification

Xcode 27.2 built the app and UI test bundle for arm64. All three XCTest journeys passed on the local iPhone 17 Pro simulator running iOS 26.4.1. The final run completed with zero failures.

| Journey | Verified outcome |
|---|---|
| Brand assets and draft recovery | Place a necklace, resize and rotate it, save, relaunch, resume the draft, delete it and reach the empty state. |
| Community and profile | Open Explore, vote and retract, bookmark a print, open Saved, rename the artist and change stations. |
| Wall to publication | Open Friend, reject an empty prompt, queue the Joe portrait, draw and undo/redo, replace the headline with YOU, resume the draft, publish and relaunch. The wall retains the new print and its count of 597. |

The final images under [Simulator](Simulator) are screenshots from those test runs. Comparison against the design study led to corrections to the station caption layout, reframe glyph, train silhouette, profile artwork and complete erasure of the printed headline during replacement. Live MTA decoding was checked separately against the agency feed. Physical-device Image Playground, remote community synchronization and frame-accurate parity with unexported videos were outside the verified simulator paths.

## Motion and performance refinement

Automatic ad changes now slide upward through the fixed metal frame. The outgoing print moves off the top as the next enters from the bottom. Rotation pauses during poster selection and editing, and respects Reduce Motion. The bottom navigation uses native Liquid Glass on iOS 26, with a moving capsule selection and drag navigation.

The editor clock refreshes once per second instead of every 180 milliseconds. Unchanged artwork is reused while pending-request deadlines continue to update. Clock and transit polling pause in the background. Native tab containers retain scroll position across navigation.

The second verification round passed all four XCTest journeys on the iPhone 17 Pro simulator. The added journey verifies that poster bounds stay fixed during rotation, Explore preserves its scroll position, the pill supports drag navigation, and rapid tab switches remain usable. The round also corrected duplicate native tab-bar targets, poster hit bounds during motion, and the draft deletion test's confirmation-sheet targeting. Draft controls now have a 44-point delete target.

A final simulator recording was sampled through several ad changes. [Rolling.mp4](Simulator/Rolling.mp4) shows the upward transition inside stationary frames. The final glass navigation and restored tiled surface are visible in [Station.png](Simulator/Station.png). Performance changes were checked in the simulator. Physical-device frame-rate and energy profiling remain unmeasured.
