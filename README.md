# Agacha!

🇧🇷 [Leia em português](README.pt-BR.md)

**Agacha!** is the Brazilian children's game *morto-vivo* ("dead or alive"), rebuilt as a camera-judged game for iPhone and iPad. A character on screen shouts **"VIVO!"** (alive: stand up) or **"MORTO!"** (dead: crouch) and waves their arms, sometimes making the *opposite* gesture to trick the players. Up to 6 kids stand in front of the device; the front camera detects who crouched and who stayed standing and eliminates whoever got it wrong. If you are already in the right position, you stay. The last player standing wins.

- **Made for families.** Parents, grandparents and kids aged 3–10. Designed for the App Store **Kids** category.
- **Private by design.** All computer vision runs on-device with Apple Vision. No image is ever saved or sent anywhere. No ads, no accounts, no network: it works in airplane mode.
- **Built for a distance.** The device leans against a wall or sits on the floor, so the game is voice-driven, with spoken commands and positioning help.
- **Fair by design.** Every elimination shows a 0.8 s skeleton replay, and an "Unfair!" button repeats the round without eliminating anyone. Referee tolerance is adjustable.

## Status

The iOS/iPadOS app is feature-complete and being prepared for App Store review. <!-- adjust: "in TestFlight" / "in review" / "live on the App Store since …" -->

What works today:

- Multi-person body-pose detection and posture classification (standing / crouching / unknown) with per-player calibration and hysteresis, 30 fps on an iPad mini 6.
- Player slots with colors and names, slot tracking across frames, "extra person" handling.
- Full game loop: countdown, command, judging window, elimination, podium.
- Difficulty levels (*Tranquilo*, *Sapeca*, *Furacão*), contrary-gesture tricks, "stay" commands, deterministic command director with seeded replay for tests.
- Command sets: *Vivo / Morto* (classic), *Em pé / Agacha* (schools and small kids), *Up / Down* (English).
- Accessibility: arms mode (raise/lower arms instead of crouching), visual-only mode, haptics and screen flash.
- Characters with their own voice and trick style; provisional system TTS, with the audio pipeline ready for studio-recorded clips.
- Child profiles, statistics, local Family Cup, achievements, 4-step tutorial.
- Parents area with parental gate, purchase restore and "delete all data"; StoreKit 2 "Family Pack" non-consumable with Family Sharing.
- pt-BR and en-US string catalogs.

See [ROADMAP.md](ROADMAP.md) for what comes next.

## Architecture

Local Swift packages with a thin app target that only composes them. The game rules never touch the camera, and the vision layer never knows the rules, so the same core runs on any platform with a front camera.

| Package | Role |
|---|---|
| `AganhaCore` | Pure Swift game models and rules: state machine, command director, judge, scoring. No camera, no UIKit. Fully unit-tested. |
| `AganhaVision` | AVFoundation camera session, Vision body-pose detection, slot tracker, posture classifier, skeleton-only replay buffer. |
| `AganhaAudio` | Voice clips, system TTS fallback and sound effects with low-latency playback. |
| `AganhaUI` | SwiftUI screens, components and theme. |
| `AganhaStore` | StoreKit 2 purchases, parental gate, restore. |

Package names still use the project's working title, *Aganha*. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Requirements

- iOS / iPadOS 17 or later, a device with a front camera (the Simulator has no camera).
- Xcode 26, [XcodeGen](https://github.com/yonaskolb/XcodeGen) and [SwiftLint](https://github.com/realm/SwiftLint) (`brew install xcodegen swiftlint`).

## Building

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig   # set your DEVELOPMENT_TEAM
make project   # generate Agacha.xcodeproj with XcodeGen
make test      # Core and Vision unit tests (skeleton fixtures, no camera needed)
make build     # build for iOS
make lint      # SwiftLint
```

Then open `Agacha.xcodeproj` and run on a device.

## Using it

For reliable detection the whole body of every player must be visible: lean the device against a wall (ideally on the floor, slightly tilted up) and step back until everyone is in frame from head to toe, about 2–3 m away. Good light helps. See [docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md).

## Privacy

Camera frames are processed on the device, frame by frame, and discarded. Nothing is recorded, uploaded or shared. The app has no network code, no analytics and no third-party SDKs. Replays are built from skeleton joints, never from images. The App Store privacy label is "Data Not Collected". Full statement: [docs/PRIVACY.md](docs/PRIVACY.md).

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): packages, game loop, posture classifier and tracker
- [docs/DECISIONS.md](docs/DECISIONS.md): design and engineering decisions
- [docs/PRIVACY.md](docs/PRIVACY.md): privacy statement
- [docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md): positioning the device and the players
- [docs/AUDIO-SCRIPT.md](docs/AUDIO-SCRIPT.md): voice recording script (pt-BR)
- [docs/PHASE0-CHECKLIST.md](docs/PHASE0-CHECKLIST.md): field-test checklist
- [ROADMAP.md](ROADMAP.md): planned work

## Contributing

Issues and pull requests are welcome, especially around posture detection on different devices and lighting, accessibility, and ports to other platforms. Please keep the privacy rules above: nothing in this project may store or transmit camera images.

## License

The source code is released under the [MIT License](LICENSE).

**"Agacha!"**, the game's characters (Tia Lu, Vovô Chico and the others), their names, artwork, voice recordings, app icon and store listings are **not** covered by this license. They remain the property of the author and may not be used to publish derived apps under the same or a confusingly similar name or identity. Build on the code freely; make your own brand.

Proprietary assets (character art, Rive animations, recorded voices) are kept out of this repository.
