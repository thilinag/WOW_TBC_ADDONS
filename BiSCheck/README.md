# BiSCheck

A World of Warcraft TBC Anniversary (2.5.6) addon for Holy Paladins. It adds a panel to the right of the character screen that compares what you're wearing with the guide's ranked gear list and shows, for every slot:

- **your next upgrade**: the closest item ranked above the one you're wearing (or **BiS** in green when you're wearing an item the guide calls BiS)
- **where your item ranks**, for example `3/6`. A `-` means your item isn't on the list, so the next upgrade shown is the lowest-ranked item on it
- **whether the slot is enchanted**: a green tick or a red cross

The top of the panel shows how many slots are BiS and how many enchants are missing.

## Installation

Copy the `BiSCheck` folder into your AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/BiSCheck
```

Restart the game or type `/reload`. On characters that aren't paladins, the addon does nothing.

## Using the panel

Open your character screen (`C`). The panel opens next to the Character tab and hides on the other tabs. Click **BiS** at the top right of the character screen, or the panel's close button, to show or hide it.

Hover over a row to see:

- what you have equipped and its rank
- the guide's full list for that slot in its order, with the guide's label for each item (such as `BiS - Haste` or `Option - World Boss`), where it drops, your item marked `>` and the next upgrade marked `+`
- the enchant on the item, and the recommended enchant if it's missing or different

Shift-click a row to link the next upgrade in chat.

### To-do page

Click **To-do** under the panel's title to see where to go for your upgrades. For every slot that isn't BiS yet, it lists the next upgrade (`+`) and the BiS item (`*`), grouped by where they come from: Black Temple, Hyjal Summit, Zul'Aman, Badges of Justice, PvP, Crafting, Reputation and so on. The places with the most items for you come first, and each item shows its boss or vendor and which slot it's for. An item that two slots want, like a ring, is listed once.

It updates as you change gear: equip an upgrade and it moves on to the next one, and a slot drops off the list once it's BiS. It also follows the phase you've picked. Hover an item for its tooltip and full source, and shift-click it to link it in chat. **Upgrades** switches back, and the panel remembers which page you were on.

Rings and trinkets share a list. An item you're wearing in one slot isn't suggested for the other, except Blessed Band of Karabor, which the guide says to wear two of.

## Gear lists

Pick the phase with the **P2**, **P3** and **P4** buttons at the top of the panel (the selected one stays lit), or with `/bis phase 2`, `3` or `4`. It's saved per character and starts on Phase 4.

Each phase uses Wowhead's Holy Paladin Healing BiS guide for that phase, saved in [`resource/`](../resource/): the slot's BiS table in the guide's order, followed by its "other recommendations" table.

- **Phase 2**: Serpentshrine Cavern, Tempest Keep, Magtheridon and Karazhan
- **Phase 3**: Hyjal Summit and Black Temple
- **Phase 4**: Wowhead says nothing changes from Phase 3, so the BiS items are the same. Zul'Aman and the new badge gear appear as options, such as Girdle of Stromgarde's Hope and Cloak of Ancient Rituals

Some slots have more than one BiS item, for example a haste and a non-haste cloak, two shields and an off-hand, or a libram for each healing style. Wearing any of them counts as BiS. Phase 2 labels its top items "Best" instead of "BiS", and those count too.

To change a list, edit `Data.lua`. Each list is in the guide's order and only holds item IDs, sources and the guide's label; names and icons come from the game.

## Enchants

The recommendations come from Wowhead's TBC Holy Paladin Healer Gems & Enchants guide, saved in [`resource/`](../resource/). A slot counts as enchanted if it has any enchant. If it's one the guide recommends, the tooltip names it. Otherwise the tooltip shows the enchant ID and what to use instead.

| Slot | Recommended (alternatives after "or") |
|---|---|
| Head | Glyph of Renewal (Honor Hold / Thrallmar, Revered) |
| Shoulder | Greater Inscription of Faith (Aldor, Exalted), or Greater Inscription of the Oracle (Scryers). For more crit: Greater Inscription of the Orb or of Discipline |
| Back | Major Resistance, or Major Armor, or Subtlety |
| Chest | Exceptional Stats, or Restore Mana Prime |
| Wrist | Major Intellect, or Superior Healing |
| Hands | Major Healing |
| Legs | Golden Spellthread, or Silver Spellthread |
| Feet | Boar's Speed |
| Rings | Healing Power (Sha'tar Revered; only checked if you're an enchanter) |
| Main Hand | Major Intellect, or Major Healing |
| Off Hand | Intellect (only checked when it's a shield) |

Neck, waist, trinkets and libram aren't checked.

If a recommended enchant shows as "a different one", type `/bis enchants` to print the enchant ID on each item and fix that ID in `Data.lua`.

## Commands

`/bis` and `/bischeck` work the same way.

| Command | What it does |
|---|---|
| `/bis` | Show or hide the panel (opens the character screen if needed) |
| `/bis phase 2` / `3` / `4` | Compare against that phase's BiS list |
| `/bis enchants` | Print the enchant ID on each equipped item |
| `/bis help` | List the commands |

Settings are saved per character.
