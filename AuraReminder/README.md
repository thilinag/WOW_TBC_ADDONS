# AuraReminder

A World of Warcraft TBC Anniversary (2.5.6) addon for paladins. It shows a flashing **NO AURA** warning on screen whenever you don't have an aura active.

## Installation

Copy the `AuraReminder` folder into your AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/AuraReminder
```

Restart the game or type `/reload`. On characters that aren't paladins, the addon does nothing.

## When the warning shows

The warning appears when you have no aura active, and goes away as soon as you turn one on. It stays hidden when:

- you're dead or a ghost (it comes back after you resurrect, since dying drops your aura)
- you're on a flight path
- you haven't learned any auras yet

Any aura counts, including Crusader Aura. Auras from other paladins don't count, so the warning only cares about your own.

## Commands

`/ar` and `/aurareminder` work the same way.

| Command | What it does |
|---|---|
| `/ar on` / `/ar off` | Turn the reminder on or off |
| `/ar unlock` | Show the warning so you can drag it somewhere else |
| `/ar lock` | Lock the warning in place |
| `/ar reset` | Move the warning back to its default spot above the center of the screen |

Settings and position are saved per character.
