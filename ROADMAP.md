# Roadmap

Planned work, roughly in order. Estimates are for one developer working with an AI coding assistant.

## Next (App Store launch)

- [ ] Studio-recorded voice clips for Tia Lu and Vovô Chico (pt-BR), wired through `AganhaAudio`; TTS stays as fallback for dynamic names. *(≈6 h)*
- [ ] Rive character animations (idle, arms up, arms down, trick, celebrate) replacing the SwiftUI placeholders. *(≈10 h)*
- [ ] Field-test pass on iPhone (portrait) and iPad (landscape, Center Stage) in low light; tune `PostureTuning` presets. *(≈6 h)*
- [ ] App Store assets: screenshots in pt-BR and en-US, preview video, Kids-category review checklist. *(≈6 h)*

## Soon

- [ ] en-US localization review and voice clips. *(≈4 h)*
- [ ] Skeleton-fixture test suite: record 1/3/5-player fixtures, add regression tests for the classifier and tracker with accuracy thresholds. *(≈8 h)*
- [ ] Performance budget test: fail CI if Vision averages > 25 ms/frame on an A15 device. *(≈3 h)*
- [ ] "Best moments" video export (adult-gated, watermark, local Photos only). *(≈8 h)*
- [ ] Seasonal character pack pipeline (data-driven characters, no code changes per character). *(≈6 h)*

## Later

- [ ] **macOS** target (Mac Catalyst or native SwiftUI), webcam and AirPlay to TV. *(≈12 h)*
- [ ] **Apple TV** target with Continuity Camera (iPhone as camera, TV as stage). *(≈16 h)*
- [ ] **Class mode** for schools and parties: groups of up to 6 rotating, no-elimination variant, lesson report PDF. *(≈12 h)*
- [ ] **Web app** (TypeScript, MediaPipe Pose) sharing the game rules through a ported `AganhaCore`. *(≈40 h)*
- [ ] **Windows** build on top of the web app (PWA / Microsoft Store packaging). *(≈8 h)*
- [ ] Optional nationwide ranking via CloudKit (nickname + state only, opt-in in the parents area). *(≈10 h)*

## Ideas (not committed)

- Two-device mode: one phone as camera, another as the stage.
- Third-party character packs with a review process.
- "Coach" mode that reports reaction-time progress per child over weeks.
