# Aganha!

🇧🇷 [Leia em português](README.pt-BR.md)

**Aganha!** is the Brazilian **"morto-vivo"** (dead-or-alive) game, rebuilt as a camera-powered app for iPhone and iPad. A character on screen shouts "VIVO!" (alive: stand up) or "MORTO!" (dead: crouch) and waves their arms, sometimes making the *opposite* gesture to trick the players. Up to 6 kids stand in front of the device, and the front camera detects who crouched and who stayed standing, eliminating anyone who got it wrong. The last player standing wins.

- **Made for families:** parents, grandparents and kids aged 3–10, designed for the App Store Kids category.
- **Private by design:** all computer vision runs on-device. No image is ever saved or sent anywhere. No ads, no accounts, no network.
- **Built for a distance:** the device sits against a wall or on the floor, so the game is voice-driven, with spoken instructions and positioning help.
- **Stack:** Swift 6, SwiftUI, Vision (human body pose) and AVFoundation. Requires iOS/iPadOS 17+.

## Status

**Phase 0 — technical spike.** The current app is a one-screen prototype that proves on-device posture recognition: camera preview, skeleton overlay, per-person standing/crouching labels, a live tuning panel and skeleton-only fixture recording. The game itself comes in Phase 1.

## Architecture

Local Swift packages, with a thin app target that only composes them:

| Package | Role |
|---|---|
| `AganhaCore` | Pure Swift game models and rules (no camera, no UIKit) |
| `AganhaVision` | Camera, Vision pose detection, slot tracking, posture classifier, replay buffer |
| `AganhaAudio` | Voice clips and sound effects |
| `AganhaUI` | SwiftUI screens and components |
| `AganhaStore` | StoreKit 2 (later phase) |

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for details.

## Building

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig   # set your DEVELOPMENT_TEAM
make project   # generate Agacha.xcodeproj
make test      # run the Core and Vision unit tests
make build     # build for iOS
make lint      # SwiftLint
```

Then open `Agacha.xcodeproj` and run on a device (the camera is not available in the Simulator).

## Using it

For reliable detection, **the whole body of every player must be visible**: lean the device against a wall (ideally on the floor, slightly tilted up) and step back until everyone is in frame from head to toe. See [`docs/SETUP-GUIDE.md`](docs/SETUP-GUIDE.md).

## Documentation

- [`docs/DECISIONS.md`](docs/DECISIONS.md): design and engineering decisions
- [`docs/PRIVACY.md`](docs/PRIVACY.md): privacy statement
- [`docs/AUDIO-SCRIPT.md`](docs/AUDIO-SCRIPT.md): voice recording script (pt-BR)
- [`docs/PHASE0-CHECKLIST.md`](docs/PHASE0-CHECKLIST.md): field-test checklist

## License

No license has been chosen yet. All rights reserved until one is added.
