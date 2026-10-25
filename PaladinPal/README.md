# PaladinPal

A World of Warcraft TBC Anniversary (2.5.6) addon for paladins. It shows flashing on-screen reminders:

- **NO AURA** whenever you don't have an aura active
- **CRUSADER AURA** (with the spell icon) when you're in a dungeon or raid with [Crusader Aura](https://www.wowhead.com/tbc/spell=32223/crusader-aura) on and you're not mounted
- **DIVINE FAVOR** (with the spell icon) when you're in combat in a dungeon or raid and [Divine Favor](https://www.wowhead.com/tbc/spell=20216/divine-favor) is off cooldown
- **DIVINE ILLUMINATION** (with the spell icon) under the same rules for [Divine Illumination](https://www.wowhead.com/tbc/spell=31842/divine-illumination)
- **JUDGEMENT OF WISDOM** (with the spell icon) when you're in combat and your enemy target doesn't have [Judgement of Wisdom](https://www.wowhead.com/tbc/spell=27164/judgement-of-wisdom) on it

- **MISSING BLESSINGS**, a movable list of group members missing a blessing assigned in [PallyPower](https://www.curseforge.com/wow/addons/pally-power), with the paladin who should cast it

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

## When the Crusader Aura warning shows

Crusader Aura only speeds up mounted movement, so in a dungeon or raid it's usually left on by mistake. The warning appears when all of these are true:

- you're inside a dungeon or raid instance
- your active aura is Crusader Aura
- you're not mounted or on a flight path
- you're alive

It hides while you're mounted, since that's when the aura is useful, and flashes as soon as you get off. Turn it off with `/pp crusader off`.

## When the Divine Favor and Divine Illumination warnings show

Each warning appears when all of these are true:

- you have the talent
- you're in combat
- you're inside a dungeon or raid instance
- the spell is off cooldown (the global cooldown is ignored)

Each one hides while its buff is on you: Divine Favor until your next heal, Divine Illumination for its duration.

## When the Judgement of Wisdom warning shows

The warning appears anywhere, not just in instances, when all of these are true:

- you've learned Seal of Wisdom (any rank), so you can judge it
- you're in combat
- you have a living enemy targeted
- your target doesn't have Judgement of Wisdom on it

Judgement of Wisdom from any paladin counts, since only one can be on a target at a time. If you don't use it, turn it off with `/pp wisdom off`.

### Range to target

If your target is too far away to judge (Judgement reaches 10 yards), the icon turns red and the distance appears under the warning, for example **TOO FAR: 10-28 yd** or **TOO FAR: 30+ yd**. It disappears once you're within 10 yards.

The game doesn't give addons an exact distance to enemies, so the distance is a range worked out from which of your spells can reach the target: Judgement (10 yards), Holy Shock (20), follow distance (28), and Hammer of Wrath, Avenger's Shield and Exorcism (30, Exorcism only on undead and demons). The more of these you know, the narrower the range. Turn it off with `/pp range off`.

## Missing blessings list

This needs PallyPower installed and enabled, since it reads PallyPower's blessing assignments. Solo or in a group, the list shows one row per missing blessing:

| Column | Shows |
|---|---|
| Icon and player | Who is missing the blessing, in their class colour |
| Blessing | Which blessing they're missing, for example Kings |
| Paladin | Who's assigned to cast it. Your own assignments say **you** in red and come first |

When you're solo, it checks you against your own PallyPower assignment for paladins. A player's single-target assignment in PallyPower counts over the one for their class. Every paladin in the group with PallyPower assignments is checked, and the normal or greater version from anyone counts. The list leaves out:

- players who are offline, dead, or too far away to see
- Salvation on players marked as main tank
- Blessing of Sacrifice, since it only lasts 30 seconds

It shows up to 15 rows, then "+N more". It updates every second and hides when nobody is missing anything. By default it also hides while you're in combat. Turn on **Also in combat** in the settings, or type `/pp blessingcombat on`, to keep it up during fights. Move it the same way as the warnings; it grows downward from its top-left corner.

## Settings

Type `/pp` on its own, or go to **Options > AddOns > PaladinPal**, to turn each reminder and the distance display on or off. **Unlock and move** closes the options window and shows every warning so you can drag them; type `/pp lock` (or click **Lock** in the settings) when you're done. **Reset positions** puts them back above the center of the screen.

## Commands

`/pp` and `/paladinpal` work the same way.

| Command | What it does |
|---|---|
| `/pp` | Open the settings |
| `/pp on` / `/pp off` | Turn all reminders on or off |
| `/pp <reminder> on` / `/pp <reminder> off` | Turn one reminder on or off: `aura`, `crusader`, `favor`, `illumination`, `wisdom` or `blessings` |
| `/pp range on` / `/pp range off` | Show or hide the distance under the Judgement of Wisdom warning |
| `/pp blessingcombat on` / `/pp blessingcombat off` | Keep the missing blessings list up in combat, or hide it there |
| `/pp move <x> <y>` | Move all warnings by that many pixels. Positive `y` is up, negative is down; positive `x` is right. For example, `/pp move 0 50` moves everything 50 pixels up |
| `/pp move <reminder> <x> <y>` | Move one warning, for example `/pp move wisdom 0 -20` |
| `/pp unlock` | Show all warnings, with a sample distance, so you can drag them somewhere else |
| `/pp lock` | Lock the warnings in place |
| `/pp reset` | Move all warnings back to their default spots above the center of the screen |

Type `/pp help` to list the commands and reminder names. Settings and positions are saved per character.