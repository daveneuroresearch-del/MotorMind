# MotorMind


## About
MotorMind is an IOS application made with Swift. It is based of an EEG research based on reading brain signals, such as mundane movements of the limbs. The original prototype and final products were run on Xcode's virtual machine (Ipad Duo), but can be easily run on an iphone.


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




<img width="959" height="554" alt="Screenshot 2026-11-18 at 4 59 59 PM" src="https://github.com/user-attachments/assets/1ba6526a-691a-47e1-9377-179d4b086178" />
<br>
<br>
<br>
<img width="959" height="554" alt="Screenshot 2026-11-18 at 4 58 58 PM" src="https://github.com/user-attachments/assets/b0eb4686-ef24-4180-82b6-46be1533b48f" />
<br>
<br>
<br>
<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/b5725edf-eb5a-4c1c-8f37-5b3df3235356" />


