# FindWay

An iPhone app that helps blind and low-vision people find their way around their own home.

1. **Scan your home.** Walk through your home holding the phone up. FindWay coaches you out loud ("It's dark here, turn on a light", "Slow down") and you name the spots you care about: Kitchen, Bathroom door, Front door.
2. **Get guided.** Pick a place. FindWay recognizes where you are, then guides you with spoken directions, a ping sound that comes from where you're heading (best with headphones), and vibrations. On iPhones with LiDAR it also warns you when something is close in front of you.

FindWay only guides along paths you actually walked while scanning. It never draws a straight line between rooms, because that line could go through a wall. Everything stays on your iPhone.

FindWay is an extra helper, not a replacement for a cane or guide dog.

## How the project is laid out

| Folder | What's in it |
| --- | --- |
| `FindWayCore/` | The brains, with no camera code: trail map, route finding, turn-by-turn directions, scan tips, obstacle detection, saving. Fully tested with `swift test`. |
| `FindWay/` | The iPhone app: camera (ARKit), voice, ping sound, vibrations, screens. |
| `project.yml` | Describes the Xcode project. Codemagic turns it into `FindWay.xcodeproj` with XcodeGen. |
| `codemagic.yaml` | The cloud builds. |
| `docs/TESTING.md` | Step-by-step test scripts to run at home. |

## One-time setup (Apple and Codemagic)

You've done this before for your games; it's the same steps with a new name.

1. **Apple Developer site → Certificates, Identifiers & Profiles → Identifiers → +.** Add an App ID with bundle ID `com.leoproductions.findway`. No extra capabilities needed.
2. **App Store Connect → Apps → + → New App.** Name: FindWay (if it's taken, try "FindWay Home"). Bundle ID: `com.leoproductions.findway`. SKU: `findway`.
3. **Codemagic → Add application** → pick the `findway-ios` repo → it finds `codemagic.yaml`.
4. **Codemagic → Team settings → Code signing identities → iOS provisioning profiles → Fetch profiles**, and get an **App Store** profile for `com.leoproductions.findway` (create it on the Apple site first if Codemagic doesn't list it). It must use your existing distribution certificate ("Accessible Backrooms Distribution").

## Building

- **FindWay check (tests + build)**: runs every test and compiles the app. No signing needed, so you can run it right after step 3. If it fails, send the log to Claude.
- **FindWay TestFlight**: signed build that uploads to TestFlight. Install it on your iPhone from the TestFlight app.

## Running the tests on your own computer

Any computer with Swift installed (Mac, Linux, or Windows):

```
cd FindWayCore
swift test
```
