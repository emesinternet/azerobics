# Azerobics

For World of Warcraft: Forever beta 1.60.1 (interface 16001).

The window opens in the center of the screen when a flight path starts if
**Start on flights** is checked. This setting is on by default. Open the window
with `/azerobics` to change it. A manual start works with this setting off.
Horde players see the orc and Horde landscape. Alliance players see the lean
night elf and Elwynn Forest at night. The night elf has visible feet in both poses.
The character is at the bottom center of the view.

Use **Horde** or **Alliance** in the header to change the character and landscape.
Drag the title area to move the window. The window stays within the screen.
This keeps the current countdown, count and movement position. A new guide uses
your character's faction unless you start it with `/azerobics a` or `/azerobics h`.

Choose **Push-ups**, **Sit-ups**, or **Jumping jacks** above the scene.
Sit-ups use a side view. Jumping jacks use a front view.
The game saves the selected exercise. A change starts a new five-second
countdown and resets the counter for the new guide. Flight totals are kept.

The five-second countdown starts each guide. The counter shows complete
animated repetitions of the selected exercise. It does not confirm that the
user did the exercise.

**Sound cues** is on by default. A short high chime marks the first pose;
a short lower chime marks the other pose. The countdown is silent. Uncheck this option to mute the cues.
The two original sounds use the game's effects channel and follow its sound
settings. Both switches are saved.

The volume slider beside the speaker icon selects 0%, 25%, 50%, 75%, or 100%. The default is 100%, which
keeps the full cue level. At 0%, cues are silent. This saved setting changes
only the cue files; the game's sound settings still control the final volume.

Click the Azerobics icon at the top left of the minimap to open or close the guide.
It uses your character's faction and also works with **Start on flights** off.
An open summary still requires **Close summary** or the window's close button.

When a guided flight ends, the window shows flight time and the number of complete
repetitions shown for each exercise during that flight. This includes guides
closed early or restarted during the flight. The summary stays open until the user
clicks **Close summary** or the window's close button. Escape and commands do
not close it. A new flight does not replace an open summary. Close the summary
before starting another guide. No exercise history is stored.

Choose one of five pace buttons: **Slow**, **Easy**, **Steady**, **Brisk**, or
**Fast**. The default is **Steady**. Every exercise uses the same movement time:
0.75 seconds each way. Only the pause between repetitions changes.
**Slow** has the longest pause; **Fast** has no pause.
The sit-up count increases at the up position. Push-ups and jumping jacks count
when the character returns to the first pose. Sit-ups start and pause down.
A pace change keeps the count and movement position. During a pause, a faster
pace can shorten the remaining wait. The game saves the selected pace, and
existing saved settings are kept.

Use the close button or Escape to stop a guide early. It stays closed during
the rest of that flight, then shows the flight summary at landing.

## Commands

- `/azerobics` — start with your character's faction.
- `/azerobics a` — start with the night elf and Alliance background.
- `/azerobics h` — start with the orc and Horde background.
- `/azerobics hide` — stop the guide.

On the ground, a manual guide runs until you close it. During a flight, it ends
at landing and shows the flight summary. It needs no flightmaster to start.

## Install

Copy the `Azerobics` folder into:

`World of Warcraft\_classic_beta_\Interface\AddOns`

The path to the main file must be:

`Interface\AddOns\Azerobics\Azerobics.toc`

Enable **Azerobics** in the game's addon list. Restart the game if it does
not see the new addon folder. Use `/reload` after changes to an existing Lua file.

The addon uses the game's own UI and needs no other addons.
Characters, masks and shadows use uncompressed 32-bit TGA textures with alpha.
Backgrounds use uncompressed 24-bit TGA textures.
Their original pixels occupy the top-left area of power-of-two texture canvases.
Texture coordinates exclude the canvas padding and the other pose in each sheet.

Both push-up poses use the same hand and foot texture layers. These layers stay in the
same position while the body changes pose. The orc's large chest covers its feet
in the down pose. The night elf's feet remain visible in both poses.

Both sit-up poses use one fixed lower body from the hips to the feet. The orc lies flat
in the down pose. The night elf has slim hands in both jumping jack poses.

Soft shadows sit below the bodies and feet. The landscape is clear near the
camera and has more blur in the distance.

For push-ups, the addon assembles the body and contact layers from the source images. The
source images alone do not have fixed hand and foot positions.
