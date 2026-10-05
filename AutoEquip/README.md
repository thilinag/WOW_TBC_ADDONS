# AutoEquip

A World of Warcraft TBC Anniversary (2.5.6) addon that equips your saved gear set when you enter a dungeon or raid.

## Installation

Copy the `AutoEquip` folder into your AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/AutoEquip
```

Restart the game or type `/reload`, and make sure AutoEquip is enabled in the AddOns list on the character select screen.

## Saving your instance set

1. Put on the gear you want to wear in dungeons and raids.
2. Type `/ae save`.

Every equipped slot is saved except shirt and tabard. Sets are saved per character.

## What happens in game

**Entering a dungeon or raid.** About a second after you zone in, any saved item you aren't wearing gets equipped from your bags. If a saved item isn't in your bags or on your character, AutoEquip lists it in chat.

- If you're in combat, the set equips as soon as combat ends.
- Moving between areas inside the instance, or typing `/reload` there, doesn't trigger it again.
- Leaving the instance doesn't change your gear.

## Commands

`/ae` and `/autoequip` work the same way.

| Command | What it does |
|---|---|
| `/ae save` | Save your current gear as the instance set |
| `/ae equip` | Equip the saved set now |
| `/ae show` | List the saved set and whether auto-equip is on |
| `/ae on` / `/ae off` | Turn auto-equip on or off for dungeons and raids |
| `/ae clear` | Delete the saved set |

## Limitations

- Items are matched by item ID. If you have two copies of the same item with different enchants or gems, AutoEquip may equip the wrong one.
- Logging in while already inside an instance doesn't equip the set. Type `/ae equip` instead.
