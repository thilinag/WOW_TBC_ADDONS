# MountMap

A World of Warcraft TBC Anniversary (2.5.6) addon that moves your minimap to the middle of the screen while you're mounted. The map is see-through and round with faded edges, so you can spot herb, ore, and other tracked nodes without looking away from your character.

## Installation

Copy the `MountMap` folder, including its `Textures` folder, into your AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/MountMap
```

Restart the game (new texture files aren't picked up by `/reload`), and make sure MountMap is enabled in the AddOns list on the character select screen.

## What happens in game

**Mounting up.** The minimap moves to the middle of the screen, grows to 400 pixels, and turns 50% transparent. Its border, buttons, and addon icons are hidden, and clicks pass through the map to the game world. To see a node's tooltip, hold Alt and hover over it.

While mounted, the map also rotates so the direction you're facing is always up. The game's own minimap rotation setting goes back to how you had it when you dismount, and at your next login if the game closed while you were mounted.

**Dismounting.** The minimap goes back to its normal spot, size, and zoom.

Druid travel and flight forms and Shaman Ghost Wolf count as mounted. Turn that off with `/mmap forms off`.

Use `/mmap test` to preview the overlay without mounting.

## Commands

`/mmap` and `/mountmap` work the same way. Settings are shared across your characters.

| Command | What it does |
|---|---|
| `/mmap alpha 0.5` | Set the transparency, from 0.05 to 1 (1 is solid) |
| `/mmap size 400` | Set the map size in pixels |
| `/mmap offset 0 -50` | Move the map away from the screen centre (x, y) |
| `/mmap zoom 2` | Zoom level to use while mounted (0 is zoomed out), or `keep` to use the current zoom |
| `/mmap edge soft` | How far the edge fades: `soft`, `medium`, or `hard` |
| `/mmap forms on` / `off` | Treat travel forms and Ghost Wolf as mounted |
| `/mmap icons 2` | Make node icons and your arrow bigger, from 0.5 to 4 times normal size |
| `/mmap hover alt` | Key to hold for node tooltips: `alt`, `shift`, `ctrl`, `always` (map blocks clicks), or `off` |
| `/mmap taxi on` / `off` | Show the overlay on flight paths (off by default) |
| `/mmap rotate on` / `off` | Rotate the map while mounted so the direction you face is always up |
| `/mmap test` | Turn the preview on or off |
| `/mmap on` / `off` | Turn the addon on or off |
| `/mmap show` | List the current settings |
| `/mmap debug` | Print the minimap's current state and which buttons are hidden, for troubleshooting |
| `/mmap reset` | Restore the default settings |

## Limitations

- WoW only has one minimap, so this moves your real minimap instead of making a copy. While you're mounted, your normal minimap spot is empty.
- Works with ElvUI's square minimap: the square shape comes back when you dismount.
- Other addons that reshape or move the minimap (SexyMap, Minimap Button Bag, and similar) may fight with MountMap over its position.