# MotorMind

SwiftUI + SwiftData iPhone app (iOS 17+) for the Congressional App Challenge.

## Tabs
- **Practice** – 10-second finger-tapping test (left or right hand), saved to SwiftData.
- **Brain Lab** – reaction-time test: wait for teal, then tap. Shows best and recent average.
- **Progress** – Swift Charts of every result, best/average tiles, recent sessions, clear history.
- **Learn** – short articles on motor learning, neuroplasticity, reaction time and practice tips.

## Run it
Requires a Mac with **Xcode 16 or newer**.

1. Double-click `MotorMind.xcodeproj`.
2. At the top of Xcode, pick an iPhone simulator (e.g. iPhone 16).
3. Press **⌘R**.

Or from Terminal in this folder:

```sh
xcodebuild -project MotorMind.xcodeproj -scheme MotorMind \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

To run on a real iPhone, select the MotorMind target → Signing & Capabilities,
pick your Team, and change the bundle ID from `com.example.MotorMind` to something unique.

## Files
| File | What it does |
|---|---|
| `MotorMindApp.swift` | App entry, SwiftData container, dark mode + teal tint |
| `ContentView.swift` | Tab bar |
| `Theme.swift` | Colors, big button styles, card, navy screen style |
| `Models.swift` | `ActivityResult` SwiftData model |
| `PracticeView.swift` | Finger-tapping test |
| `BrainLabView.swift` | Reaction-time test |
| `ProgressDashboardView.swift` | Charts and history |
| `LearnView.swift` | Learn articles |
