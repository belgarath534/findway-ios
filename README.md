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

## Codemagic workflows (all on the free M2 Mac mini)

1. **FindWay setup**: one time. Registers the bundle ID `com.leoproductions.findway` with Apple and makes the "FindWay App Store" signing profile.
2. **FindWay check**: runs every test and builds the app without signing. Use it to catch mistakes.
3. **FindWay TestFlight**: fills in the App Store and TestFlight text, signs the app and uploads it to TestFlight.
4. **FindWay store listing**: only refills the App Store and TestFlight text.

You only do one thing by hand: in App Store Connect, create the app (New App, name FindWay, bundle ID `com.leoproductions.findway`, SKU `findway`).

The App Store text lives in `store/en-US/`. Change it there and run "FindWay store listing" again.

## Running the tests on your own computer

Any computer with Swift installed (Mac, Linux, or Windows):

```
cd FindWayCore
swift test
```
