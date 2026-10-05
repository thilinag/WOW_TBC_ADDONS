# PaladinPal

A World of Warcraft TBC Anniversary (2.5.6) addon for paladins. It shows flashing on-screen reminders:

- **NO AURA** whenever you don't have an aura active
- **DIVINE FAVOR** (with the spell icon) when you're in combat in a dungeon or raid and [Divine Favor](https://www.wowhead.com/tbc/spell=20216/divine-favor) is off cooldown

## Installation

Copy the `PaladinPal` folder into your AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/PaladinPal
```

Restart the game or type `/reload`. On characters that aren't paladins, the addon does nothing.

If you used AuraReminder before, delete its folder. PaladinPal doesn't carry over the old settings or warning position.

## When the aura warning shows

The warning appears when you have no aura active, and goes away as soon as you turn one on. It stays hidden when:

- you're dead or a ghost (it comes back after you resurrect, since dying drops your aura)
- you're on a flight path
- you haven't learned any auras yet

Any aura counts, including Crusader Aura. Auras from other paladins don't count, so the warning only cares about your own.

## When the Divine Favor warning shows

The warning appears when all of these are true:

- you have the Divine Favor talent
- you're in combat
- you're inside a dungeon or raid instance
- Divine Favor is off cooldown (the global cooldown is ignored)

It hides while the Divine Favor buff is on you, waiting for your next heal.

## Commands

`/pp` and `/paladinpal` work the same way.

| Command | What it does |
|---|---|
| `/pp on` / `/pp off` | Turn all reminders on or off |
| `/pp <reminder> on` / `/pp <reminder> off` | Turn one reminder on or off: `aura` or `favor` |
| `/pp unlock` | Show all warnings so you can drag them somewhere else |
| `/pp lock` | Lock the warnings in place |
| `/pp reset` | Move all warnings back to their default spots above the center of the screen |

Type `/pp` with no arguments to list the commands and reminder names. Settings and positions are saved per character.
