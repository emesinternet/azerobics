# Azerobics

Turn flight time into an exercise break in WoW Forever beta 1.60.1.

Copy the `Azerobics` folder into `Interface\AddOns`, then enable it in the
game's addon list. Azerobics needs no other addons.

## Start

The guide opens when a flight starts if **Start on flights** is checked.
Use the minimap button or `/azerobics` to open it on the ground.
Drag the title area to move the window.

Choose **Push-ups**, **Sit-ups**, **Jumping jacks**, or **Squats**.
Sit-ups and squats use a side view. Push-ups and jumping jacks use a front view.
Each guide starts with a silent five-second countdown.

## Choose your character

Use the three dropdowns above the image to choose a background, race, and sex.
The races are:
Human, Dwarf, Gnome, Night Elf, Orc, Tauren, Troll, Undead, or Skyborne.
All three dropdowns default to **Auto**, which uses your current character's
faction, race, and sex. You can select a fixed choice or return to Auto at any time.
The game saves your choice. All races use a similar amount of space in the view.

The first dropdown changes only the landscape.
Alliance uses Elwynn Forest at night. A character or landscape change keeps
the current count and movement position.

## Pace and sound

Choose an exercise below the image. Use the bottom row to choose **Slow**,
**Easy**, **Steady**, **Brisk**, or **Fast**. The default is **Steady**.
Movement speed stays the same. Only the pause between repetitions changes.
**Fast** has no pause.
Sit-ups start and pause in the down position. Their count increases in the up
position. The other exercises count when the character returns to the first pose.
A pace change keeps the count and movement position.

Clear **Sound cues** to mute the guide. The slider beside the speaker icon
sets cue volume from 0% to 100%. The game's sound settings also control the
final volume. The game saves these settings.

## When you land

The summary shows flight time and repetitions for each exercise used during
the flight. Exercise changes and guides closed early keep their flight totals.
Click **Close summary** or the window's close button to close it.
The summary stays open until you click. No exercise history is stored.

The counter follows the displayed poses. It cannot confirm that you did an exercise.

## Commands

- `/azerobics` - start with your saved background choice (Auto uses your faction).
- `/azerobics a` - start with the Alliance background.
- `/azerobics h` - start with the Horde background.
- `/azerobics hide` - stop the guide.

Commands keep your selected character. On the ground, the guide runs until
you close it. During a flight, it ends at landing and shows the summary.
Escape stops an active guide, but does not close the summary.
