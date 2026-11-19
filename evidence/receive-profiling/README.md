# Receive lifecycle profiling

This evidence accompanies the fix that disposes both MobX reactions in `NewReceivePage`.

## Physical-device measurements

Cake Wallet v6.5.3, upstream commit `d803aecf9`, iPhone 16 Pro, Flutter profile mode. The patched measurements used the same version and device with the two reaction disposers registered and called from `dispose()`.

Procedure: Dashboard → Receive → QR → Label address → close without saving → Dashboard, repeated three times. Each checkpoint queried the main Dart isolate allocation profile after requesting garbage collection. The target was `_NewReceivePageState`.

| Checkpoint | Original | Patched |
| --- | ---: | ---: |
| Initial dashboard | 0 | 0 |
| First visit, editor open | Not sampled | 1 |
| Dashboard after three visits and GC | 3 | 0 |
| Subsequent GC | 3 | 0 |

The original follow-up was recorded after visiting other routes. The patched repeat sample was about eight seconds after the post-return sample. These intervals are not identical. The retaining path includes `_NewReceivePageState → _Closure → ContextRef → _Closure → ReactionImpl`.

Files `iphone-original-counts.jsonl` and `iphone-original-followup.jsonl` preserve the original GC and allocation-snapshot records; frame and CPU events were omitted. `iphone-patched-counts.jsonl` is the complete patched measurement log. `receive-retaining-path.jsonl` contains the Receive state entry from the original retaining-path capture. `count.dart` is the patched-session sampling script; it reads a VM service URL from a local file and accepts checkpoint names on stdin. No wallet addresses, seeds, or VM authentication URLs are included.

These measurements establish retention in the tested sequence. They are not a whole-app leak audit or a simulator performance benchmark. The historical measurements must not be attributed to current dev.

## Current dev regression

Base: `3cd46aaee`; fix: `1471de6402233e95a6e8abfd9f2cc8f504d82448`.

`flutter test test/new-ui/pages/receive_page_lifecycle_test.dart` mounts the real Receive widget with controlled observable view models. It checks live address updates and both subscriptions across three mount/unmount cycles, then changes the observables after closing.

- Original source: fails after the first unmount because the URI observable still has observers (`test-original.log`).
- Patched source: all assertions pass (`test-patched.log`).
- Analyzer: no errors and no findings in the new test. Receive has existing unused imports and a control-body style finding (`analyze-final.log`).

## Simulator route check

The full multi-currency app built with Flutter 3.41.9 and the iOS 27.2 SDK. The automated route check passed on the iPhone 18 Pro simulator in debug mode. It created an empty Monero wallet, opened Receive, checked that the displayed address matched the wallet, opened Label address, tapped the editor close button without saving, then tapped Receive's close button. All three visits returned to the dashboard with both widgets removed from the tree.

`simulator-smoke.log` records the passing run. `receive_memory_smoke_test.dart` is the local integration check; place it in `integration_test/suites/tier0/` and run it with `flutter test integration_test/suites/tier0/receive_memory_smoke_test.dart -d <simulator-id>`. It uses the repository's onboarding and robot helpers. It is published here as supporting evidence, separate from the focused widget regression in the PR.

The repository's existing integration harness classifies and ignores known background/UI errors. This run logged a 3.5-pixel RenderFlex overflow and progress-bar semantics assertions. The route assertions passed; this is not a claim of a warning-free app or accessibility validation. No payment was sent. Debug-mode simulator execution is functional validation, not a replacement for the physical-device profiling above.

Build preparation used the pinned native sources, generated models/localizations/graphics, and generated Cake Wallet icon. MWEB, Decred and Tor were built for the simulator; Tor used the installed Xcode compiler/SDK and an ad hoc simulator signature. Those local build artifacts/configuration changes are not part of the source PR.
