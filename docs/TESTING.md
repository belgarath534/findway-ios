# FindWay home test scripts

Do these with VoiceOver on, holding the phone at chest height, back camera facing forward.
Headphones (AirPods work great) make the ping sound much easier to follow.
Write down anything that felt wrong, confusing, too chatty, or too quiet, and tell Claude.

## Test 1: First scan (one room to another)

1. Open FindWay. You should hear "Welcome to FindWay". Activate **Scan my home**.
2. **Expect:** "Scanning started..." within a couple of seconds.
3. Stand in your bedroom doorway. Slowly turn left and right for about 5 seconds.
4. Activate **Mark this spot**, type or dictate `Bedroom`, then activate **Save**.
5. **Expect:** "Saved Bedroom. Keep walking..." and a buzz.
6. Walk slowly to the kitchen, pointing the camera ahead.
7. Mark the spot `Kitchen`.
8. Activate **Finish and save**.
9. **Expect:** "Saved. Your home has 2 places." and you're back on the first screen.

**Pass if:** both places were saved and the first screen says your home has 2 places.

## Test 2: The coach

During a scan:

1. Walk or swing the phone fast. **Expect:** "Slow down..."
2. Point the camera right up against a blank wall. **Expect:** "I can't see enough detail..."
3. Turn off the lights (if it's safe). **Expect:** "It looks dark here. Turn on a light..."
4. Activate **Repeat tip**. **Expect:** the current tip again.

**Pass if:** each tip came within about 5 seconds, and none of them repeated nonstop.

## Test 3: Guided trip

1. Go back to the bedroom doorway. Activate **Take me somewhere**, then **Kitchen**.
2. **Expect:** "Going to Kitchen. Look around slowly..."
3. Slowly turn around. **Expect** within about 10 seconds: "Found you. Kitchen is about N steps away..."
4. Follow the directions and the ping. When you face the right way you should feel a light tap.
5. **Expect:** "You've arrived at Kitchen." and a buzz when you get there.

**Pass if:** you reached the kitchen and the step counts felt about right.
Also note: how many seconds "Found you" took, and whether "Turn left/right" matched reality.

## Test 4: Obstacle warning (iPhone with LiDAR)

1. Start a trip, then hold the phone about half a meter from a closed door or a chair.
2. **Expect:** "Careful, something ahead..." and a strong buzz.
3. Move the phone away. The warning should stop.

## Test 5: Coming back later

1. Close FindWay completely (swipe it away in the app switcher).
2. Open it again. **Expect:** "Your home has 2 saved places."
3. Run Test 3 again from a different spot you walked through.

## Test 6: Things that should fail politely

- Start a trip from a room you never scanned. **Expect:** "Still looking..." and then, after about 40 seconds, advice to turn on a light or move to a scanned room.
- Mark two places with the same name. **Expect:** "You already have a place called..."
- Press **Finish and save** before marking any place. **Expect:** "Mark at least one place before saving..."
