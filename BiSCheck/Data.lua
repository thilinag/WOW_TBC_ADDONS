local ADDON_NAME, ns = ...

-- Holy Paladin gear lists from the Wowhead Holy Paladin Healing BiS guides
-- for each phase (saved in resource/), in the guide's order: its BiS table
-- first, then the "other recommendations" table. label is the guide's rank
-- column; anything starting with "BiS" or "Best" counts as best in slot.
-- dup = true means you can wear two of it. Names come from the game, so
-- only IDs and sources live here.

local PHASE2 = {
    head = {
        { 30136, "Helm of the Vanquished Champion - Lady Vashj (Serpentshrine Cavern)", label = "Best" },
        { 32472, "Profession: Engineering (BoP)", label = "Optional - Crafted" },
        { 30728, "Doomwalker (World Boss)", label = "Optional - World Boss" },
        { 29061, "Prince Malchezaar (Karazhan)", label = "Optional" },
    },
    shoulder = {
        { 30138, "Pauldrons of the Vanquished Champion - Void Reaver (Tempest Keep)", label = "Best" },
        { 30097, "Leotheras the Blind (Serpentshrine Cavern)", label = "Optional" },
        { 29064, "Pauldrons of the Fallen Champion - High King Maulgar (Gruul's Lair)", label = "Optional" },
    },
    back = {
        { 29989, "Kael'thas Sunstrider", label = "Best" },
        { 28765, "Prince Malchezaar (Karazhan)", label = "Optional" },
        { 27946, "Talon King Ikiss (Sethekk Halls)", label = "Optional" },
    },
    chest = {
        { 30134, "Chestguard of the Vanquished Champion - Kael'thas Sunstrider (Tempest Keep)", label = "Best" },
        { 29062, "Chestguard of the Fallen Champion - Magtheridon (Magtheridon)", label = "Optional" },
        { 29522, "Profession: Leatherworking (BoP)", label = "Optional - Crafted" },
    },
    wrist = {
        { 30047, "Hydross the Unstable (Serpentshrine Cavern)", label = "Best" },
        { 29523, "Profession: Leatherworking (BoP)", label = "Optional - Crafted" },
        { 23539, "Profession: Blacksmithing (BoP)", label = "Optional - Crafted BoE" },
    },
    hands = {
        { 30112, "Lady Vashj (Serpentshrine Cavern)", label = "Best" },
        { 29976, "High Astromancer Solarian (Tempest Keep)", label = "Optional" },
        { 30135, "Gloves of the Vanquished Champion - Leotheras the Blind (Serpentshrine Cavern)", label = "Optional" },
    },
    waist = {
        { 30030, "Tempest Keep Trash Mobs", label = "Best" },
        { 29965, "High Astromancer Solarian (Tempest Keep)", label = "Optional" },
        { 29524, "Profession: Leatherworking (BoP)", label = "Optional - Crafted" },
    },
    legs = {
        { 29991, "Kael'thas Sunstrider (Tempest Keep)", label = "Best" },
        { 30727, "Doomwalker (World Boss)", label = "Optional - World Boss" },
        { 30137, "Leggings of the Vanquished Champion - Fathom-Lord Karathress (Serpentshrine Cavern)", label = "Optional" },
    },
    feet = {
        { 30027, "Serpentshrine Cavern Trash Mobs", label = "Best" },
        { 30737, "Doom Lord Kazzak (World Boss)", label = "Optional - World Boss" },
        { 30092, "Leotheras the Blind (Serpentshrine Cavern)", label = "Optional" },
    },
    neck = {
        { 30018, "Verdant Sphere from Kael'thas Sunstrider", label = "Best" },
        { 30726, "Doomwalker", label = "Optional - World Boss" },
        { 29374, "Vendor: 25 x Badge of Justice", label = "Optional" },
    },
    finger = {
        { 30110, "Lady Vashj (Serpentshrine Cavern)", label = "Best" },
        { 28790, "Quest: The Fall of Magtheridon (Magtheridon's Lair)", label = "Best" },
        { 28763, "Prince Malchezaar (Karazhan)", label = "Optional" },
        { 29920, "Al'ar (Tempest Keep)", label = "Optional" },
    },
    trinket = {
        { 29376, "Vendor: G'eras (41 Badges of Justice)", label = "BiS" },
        { 28727, "Shade of Aran (Karazhan)", label = "BiS" },
        { 30841, "Vendor: Nakodu - Requires Revered with Lower City", label = "Option" },
        { 28590, "Opera Event - Karazhan", label = "Option" },
    },
    mainhand = {
        { 30108, "Lady Vashj (Serpentshrine Cavern)", label = "Best" },
        { 28771, "Prince Malchezaar (Karazhan)", label = "Optional" },
        { 28522, "Maiden of Virtue", label = "Optional" },
        { 23556, "Profession: Blacksmithing", label = "Optional" },
        { 29353, "Murmur (Heroic Shadow Labyrinth)", label = "Optional" },
    },
    offhand = {
        { 29923, "Al'ar (Tempest Keep)", label = "Best - Offhand" },
        { 29458, "Magtheridon - Magtheridon's Lair", label = "Best - Shield" },
        { 29274, "Vendor: G'eras (25 Badges of Justice)", label = "Optional - Offhand" },
        { 29267, "Vendor: G'eras (33 Badges of Justice)", label = "Optional - Shield" },
    },
    relic = {
        { 28592, "Opera Event - Karazhan", label = "BiS" },
        { 28296, "Commander Sarannis (The Botanica)", label = "Optional" },
        { 25644, "Quest: The Ultimate Bloodsport", label = "Optional" },
    },
}

local PHASE3 = {
    head = {
        { 30988, "Archimonde (Hyjal Summit)", label = "BiS" },
        { 32354, "Essence of Anger (Black Temple)", label = "Option" },
        { 32241, "High Warlord Naj'entus (Black Temple)", label = "Option" },
        { 30136, "Lady Vashj (Serpentshrine Cavern)", label = "Option" },
    },
    shoulder = {
        { 30996, "Mother Shahraz (Black Temple)", label = "BiS" },
        { 30878, "Anetheron (Hyjal Summit)", label = "Option" },
        { 30138, "Void Reaver (Tempest Keep: The Eye)", label = "Option" },
    },
    back = {
        { 32524, "Illidan Stormrage (Black Temple)", label = "BiS - Haste" },
        { 34012, "Trash Mobs (Black Temple)", label = "BiS - Non-Haste" },
        { 29989, "Kael'thas Sunstrider (Tempest Keep: The Eye)", label = "Option" },
        { 32337, "Gurtogg Bloodboil (Black Temple)", label = "Option" },
    },
    chest = {
        { 30992, "Illidan Stormrage (Black Temple)", label = "BiS" },
        { 30904, "Archimonde (Hyjal Summit)", label = "Option" },
        { 30134, "Kael'thas Sunstrider (Tempest Keep: The Eye)", label = "Option" },
    },
    wrist = {
        { 30862, "Rage Winterchill (Hyjal Summit)", label = "BiS" },
        { 30869, "Rage Winterchill (Hyjal Summit)", label = "Option" },
        { 32571, "Profession: Blacksmithing - can be purchased on the Auction House", label = "Option" },
        { 30047, "Hydross the Unstable (Serpentshrine Cavern)", label = "Option" },
    },
    hands = {
        { 30112, "Lady Vashj (Serpentshrine Cavern)", label = "BiS" },
        { 30983, "Azgalor (Hyjal Summit)", label = "Option" },
        { 29976, "High Astromancer Solarian (Tempest Keep: The Eye)", label = "Option" },
        { 32328, "Teron Gorefiend (Black Temple)", label = "Option" },
    },
    waist = {
        { 30897, "Azgalor (Hyjal Summit)", label = "BiS" },
        { 30030, "Trash Mobs (Tempest Keep: The Eye)", label = "Option" },
        { 29965, "High Astromancer Solarian (Tempest Keep: The Eye)", label = "Option" },
    },
    legs = {
        { 30994, "The Illidari Council (Black Temple)", label = "BiS" },
        { 30912, "Archimonde (Hyjal Summit)", label = "Option" },
        { 32271, "Shade of Akama (Black Temple)", label = "Option" },
        { 30893, "Kaz'rogal (Hyjal Summit)", label = "Option" },
    },
    feet = {
        { 32243, "High Warlord Naj'entus (Black Temple)", label = "BiS" },
        { 30027, "Trash Mobs (Serpentshrine Cavern)", label = "Option" },
        { 32609, "Trash Mobs (Hyjal Summit)", label = "Option" },
        { 30737, "Doom Lord Kazzak (World Boss)", label = "Option - World Boss" },
    },
    neck = {
        { 32370, "Mother Shahraz (Black Temple)", label = "BiS" },
        { 30018, "Kael'thas Sunstrider (Tempest Keep: The Eye)", label = "Option" },
        { 30726, "Doomwalker (World Boss)", label = "Option - World Boss" },
        { 28609, "Nightbane (Karazhan)", label = "Option" },
    },
    finger = {
        { 32528, "Trash Mobs (Black Temple)", label = "BiS - Haste", dup = true },
        { 32238, "High Warlord Naj'entus (Black Temple)", label = "BiS - Non-Haste" },
        { 29309, "Quest: Restorer's Covenant (Scale of the Sands Exalted)", label = "BiS - Reputation" },
        { 30110, "Lady Vashj (Serpentshrine Cavern)", label = "Option" },
        { 30736, "Doom Lord Kazzak (World Boss)", label = "Option - World Boss" },
        { 28790, "Magtheridon (Magtheridon's Lair)", label = "Option" },
        { 28763, "Prince Malchezaar (Karazhan)", label = "Option" },
        { 29920, "Al'ar (Tempest Keep: The Eye)", label = "Option" },
    },
    trinket = {
        { 32496, "Illidan Stormrage (Black Temple)", label = "BiS" },
        { 29376, "Vendor: G'eras (Badges of Justice)", label = "BiS" },
        { 38288, "Coren Direbrew (Brewfest Seasonal Event)", label = "BiS" },
        { 28590, "Opera Event (Karazhan)", label = "Option" },
        { 23047, "Sapphiron (Classic - Naxxramas)", label = "Option" },
        { 30841, "Vendor: Nakodu (Lower City Revered)", label = "Option" },
        { 19395, "Flamegor, Firemaw, & Ebonroc (Classic - Blackwing Lair)", label = "Option" },
    },
    mainhand = {
        { 32500, "Illidan Stormrage (Black Temple)", label = "BiS - Highly Contested" },
        { 33743, "Vendor: Arena Points (Season 3)", label = "Option" },
        { 30918, "Kaz'rogal (Hyjal Summit)", label = "Option" },
        { 30108, "Lady Vashj (Serpentshrine Cavern)", label = "Option" },
        { 32964, "Vendor: Arena Points (Season 2)", label = "Option" },
        { 28771, "Prince Malchezaar (Karazhan)", label = "Option" },
        { 32451, "Vendor: Honor Points (Season 1)", label = "Option" },
        { 28522, "Maiden of Virtue (Karazhan)", label = "Option" },
        { 23556, "Profession: Blacksmithing - can be purchased on the Auction House", label = "Option" },
        { 29353, "Murmur (Heroic Shadow Labyrinth)", label = "Option" },
    },
    offhand = {
        { 32255, "Supremus (Black Temple)", label = "BiS - Shield" },
        { 30882, "Anetheron (Hyjal Summit)", label = "BiS - Shield" },
        { 30911, "Archimonde (Hyjal Summit)", label = "BiS - Offhand" },
        { 33735, "Vendor: Arena Points (Season 3)", label = "Option" },
        { 33309, "Vendor: Arena Points (Season 2)", label = "Option" },
        { 29458, "Magtheridon (Magtheridon's Lair)", label = "Option" },
        { 29923, "Al'ar (Tempest Keep: The Eye)", label = "Option" },
        { 29274, "Vendor: G'eras (Badges of Justice)", label = "Option" },
        { 29267, "Vendor: G'eras (Badges of Justice)", label = "Option" },
    },
    relic = {
        { 28592, "Opera Event (Karazhan)", label = "BiS - Blessing of Light" },
        { 23006, "Noth the Plaguebringer (Classic - Naxxramas)", label = "BiS - Flash of Light" },
        { 30063, "The Lurker Below (Serpentshrine Cavern)", label = "BiS - Holy Light" },
        { 28296, "Commander Sarannis (The Botanica)", label = "BiS - Holy Light" },
        { 25644, "Quest: The Ultimate Bloodsport", label = "Option - Flash of Light" },
    },
}

-- Wowhead: "nothing changes from the Phase 3 best-in-slot guide". Zul'Aman
-- and badge items only appear as options.
local PHASE4 = {
    head = {
        { 30988, "Archimonde (Hyjal Summit)", label = "BiS" },
        { 32354, "Essence of Anger (Black Temple)", label = "Option" },
        { 32241, "High Warlord Naj'entus (Black Temple)", label = "Option" },
        { 30136, "Lady Vashj (Serpentshrine Cavern)", label = "Option" },
    },
    shoulder = {
        { 30996, "Mother Shahraz (Black Temple)", label = "BiS" },
        { 30878, "Anetheron (Hyjal Summit)", label = "Option" },
        { 30138, "Void Reaver (Tempest Keep: The Eye)", label = "Option" },
    },
    back = {
        { 32524, "Illidan Stormrage (Black Temple)", label = "BiS - Haste" },
        { 34012, "Trash Mobs (Black Temple)", label = "BiS - Non-Haste" },
        { 33592, "Hex Lord Malacrass (Zul'Aman)", label = "Optional - Haste" },
        { 29989, "Kael'thas Sunstrider (Tempest Keep: The Eye)", label = "Option" },
        { 32337, "Gurtogg Bloodboil (Black Temple)", label = "Option" },
    },
    chest = {
        { 30992, "Illidan Stormrage (Black Temple)", label = "BiS" },
        { 30904, "Archimonde (Hyjal Summit)", label = "Option" },
        { 30134, "Kael'thas Sunstrider (Tempest Keep: The Eye)", label = "Option" },
    },
    wrist = {
        { 30862, "Rage Winterchill (Hyjal Summit)", label = "BiS" },
        { 30869, "Rage Winterchill (Hyjal Summit)", label = "Option" },
        { 32571, "Profession: Blacksmithing - can be purchased on the Auction House", label = "Option" },
        { 30047, "Hydross the Unstable (Serpentshrine Cavern)", label = "Option" },
    },
    hands = {
        { 30112, "Lady Vashj (Serpentshrine Cavern)", label = "BiS" },
        { 30983, "Azgalor (Hyjal Summit)", label = "Option" },
        { 29976, "High Astromancer Solarian (Tempest Keep: The Eye)", label = "Option" },
        { 32328, "Teron Gorefiend (Black Temple)", label = "Option" },
    },
    waist = {
        { 30897, "Azgalor (Hyjal Summit)", label = "BiS" },
        { 33446, "Hex Lord Malacrass (Zul'Aman)", label = "Best" },
        { 30030, "Trash Mobs (Tempest Keep: The Eye)", label = "Option" },
        { 29965, "High Astromancer Solarian (Tempest Keep: The Eye)", label = "Option" },
    },
    legs = {
        { 30994, "The Illidari Council (Black Temple)", label = "BiS" },
        { 30912, "Archimonde (Hyjal Summit)", label = "Option" },
        { 32271, "Shade of Akama (Black Temple)", label = "Option" },
        { 30893, "Kaz'rogal (Hyjal Summit)", label = "Option" },
    },
    feet = {
        { 32243, "High Warlord Naj'entus (Black Temple)", label = "BiS" },
        { 30027, "Trash Mobs (Serpentshrine Cavern)", label = "Option" },
        { 32609, "Trash Mobs (Hyjal Summit)", label = "Option" },
        { 30737, "Doom Lord Kazzak (World Boss)", label = "Option - World Boss" },
    },
    neck = {
        { 32370, "Mother Shahraz (Black Temple)", label = "BiS" },
        { 30018, "Kael'thas Sunstrider (Tempest Keep: The Eye)", label = "Option" },
        { 30726, "Doomwalker (World Boss)", label = "Option - World Boss" },
        { 28609, "Nightbane (Karazhan)", label = "Option" },
    },
    finger = {
        { 32528, "Trash Mobs (Black Temple)", label = "BiS - Haste", dup = true },
        { 32238, "High Warlord Naj'entus (Black Temple)", label = "BiS - Non-Haste" },
        { 29309, "Quest: Restorer's Covenant (Scale of the Sands Exalted)", label = "BiS - Reputation" },
        { 30110, "Lady Vashj (Serpentshrine Cavern)", label = "Option" },
        { 33498, "Zul'Aman Timed Event - 3rd Chest", label = "Optional - Haste" },
        { 30736, "Doom Lord Kazzak (World Boss)", label = "Option - World Boss" },
        { 28790, "Magtheridon (Magtheridon's Lair)", label = "Option" },
        { 28763, "Prince Malchezaar (Karazhan)", label = "Option" },
        { 29920, "Al'ar (Tempest Keep: The Eye)", label = "Option" },
    },
    trinket = {
        { 32496, "Illidan Stormrage (Black Temple)", label = "BiS" },
        { 29376, "Vendor: G'eras (Badges of Justice)", label = "BiS" },
        { 38288, "Coren Direbrew (Brewfest Seasonal Event)", label = "BiS" },
        { 28590, "Opera Event (Karazhan)", label = "Option" },
        { 23047, "Sapphiron (Classic - Naxxramas)", label = "Option" },
        { 30841, "Vendor: Nakodu (Lower City Revered)", label = "Option" },
        { 19395, "Flamegor, Firemaw, & Ebonroc (Classic - Blackwing Lair)", label = "Option" },
    },
    mainhand = {
        { 32500, "Illidan Stormrage (Black Temple)", label = "BiS - Highly Contested" },
        { 33743, "Vendor: Arena Points (Season 3)", label = "Option" },
        { 30918, "Kaz'rogal (Hyjal Summit)", label = "Option" },
        { 33468, "Zul'jin (Zul'Aman)", label = "Optional" },
        { 30108, "Lady Vashj (Serpentshrine Cavern)", label = "Option" },
        { 32964, "Vendor: Arena Points (Season 2)", label = "Option" },
        { 28771, "Prince Malchezaar (Karazhan)", label = "Option" },
        { 32451, "Vendor: Honor Points (Season 1)", label = "Option" },
        { 28522, "Maiden of Virtue (Karazhan)", label = "Option" },
        { 23556, "Profession: Blacksmithing - can be purchased on the Auction House", label = "Option" },
        { 29353, "Murmur (Heroic Shadow Labyrinth)", label = "Option" },
    },
    offhand = {
        { 32255, "Supremus (Black Temple)", label = "BiS - Shield" },
        { 30882, "Anetheron (Hyjal Summit)", label = "BiS - Shield" },
        { 30911, "Archimonde (Hyjal Summit)", label = "BiS - Offhand" },
        { 33332, "Jan'alai (Zul'Aman)", label = "Optional - Shield" },
        { 33735, "Vendor: Arena Points (Season 3)", label = "Option" },
        { 33309, "Vendor: Arena Points (Season 2)", label = "Option" },
        { 29458, "Magtheridon (Magtheridon's Lair)", label = "Option" },
        { 29923, "Al'ar (Tempest Keep: The Eye)", label = "Option" },
        { 29274, "Vendor: G'eras (Badges of Justice)", label = "Option" },
        { 29267, "Vendor: G'eras (Badges of Justice)", label = "Option" },
    },
    relic = {
        { 28592, "Opera Event (Karazhan)", label = "BiS - Blessing of Light" },
        { 23006, "Noth the Plaguebringer (Classic - Naxxramas)", label = "BiS - Flash of Light" },
        { 30063, "The Lurker Below (Serpentshrine Cavern)", label = "BiS - Holy Light" },
        { 33502, "20x Badge of Justice", label = "Optional - Holy Light" },
        { 28296, "Commander Sarannis (The Botanica)", label = "BiS - Holy Light" },
        { 25644, "Quest: The Ultimate Bloodsport", label = "Option - Flash of Light" },
    },
}

ns.PHASES = { 2, 3, 4 }
ns.LISTS = { [2] = PHASE2, [3] = PHASE3, [4] = PHASE4 }

-- Inventory slot IDs in the order the panel lists them. pair is the other
-- slot sharing the same list, so an item worn there isn't suggested twice.
ns.SLOTS = {
    { id = 1,  label = "Head",      list = "head" },
    { id = 2,  label = "Neck",      list = "neck" },
    { id = 3,  label = "Shoulder",  list = "shoulder" },
    { id = 15, label = "Back",      list = "back" },
    { id = 5,  label = "Chest",     list = "chest" },
    { id = 9,  label = "Wrist",     list = "wrist" },
    { id = 10, label = "Hands",     list = "hands" },
    { id = 6,  label = "Waist",     list = "waist" },
    { id = 7,  label = "Legs",      list = "legs" },
    { id = 8,  label = "Feet",      list = "feet" },
    { id = 11, label = "Ring 1",    list = "finger",  pair = 12 },
    { id = 12, label = "Ring 2",    list = "finger",  pair = 11 },
    { id = 13, label = "Trinket 1", list = "trinket", pair = 14 },
    { id = 14, label = "Trinket 2", list = "trinket", pair = 13 },
    { id = 16, label = "Main Hand", list = "mainhand" },
    { id = 17, label = "Off Hand",  list = "offhand" },
    { id = 18, label = "Libram",    list = "relic" },
}

-- Holy Paladin enchants by slot, recommended first, from the Wowhead Holy
-- Paladin Healer Gems & Enchants guide (saved in resource/). The comment on
-- each line is the guide's Wowhead link. The first number is the enchant ID
-- the game puts in item links, which the guide doesn't give: any enchant
-- counts as enchanted, and the ID only decides whether it's named as a
-- recommended one. /bis enchants prints the real IDs to check against.
-- needs: "enchanting" for enchanter-only ring enchants, "shield" for slots
-- that can only be enchanted when a shield is equipped.
ns.ENCHANTS = {
    [1] = {
        { 3001, "Glyph of Renewal", "Honor Hold / Thrallmar, Revered" },                 -- item=29190
    },
    [3] = {
        { 2980, "Greater Inscription of Faith", "Aldor, Exalted" },                      -- item=28887
        { 2995, "Greater Inscription of the Oracle", "Scryers, Exalted" },               -- item=28912
        { 2994, "Greater Inscription of the Orb", "Scryers, Exalted (more crit)" },      -- item=28909
        { 2982, "Greater Inscription of Discipline", "Aldor, Exalted (more crit)" },     -- item=28886
    },
    [15] = {
        { 2664, "Enchant Cloak - Major Resistance", "Enchanting" },                      -- spell=27962
        { 2662, "Enchant Cloak - Major Armor", "Enchanting" },                           -- spell=27961
        { 2621, "Enchant Cloak - Subtlety", "Enchanting" },                              -- spell=25084
    },
    [5] = {
        { 2661, "Enchant Chest - Exceptional Stats", "Enchanting" },                     -- spell=27960
        { 3150, "Enchant Chest - Restore Mana Prime", "Enchanting" },                    -- spell=33991
    },
    [9] = {
        { 369, "Enchant Bracer - Major Intellect", "Enchanting" },                       -- spell=34001
        { 2617, "Enchant Bracer - Superior Healing", "Enchanting" },                     -- spell=46500
    },
    [10] = {
        { 2322, "Enchant Gloves - Major Healing", "Enchanting" },                        -- spell=33999
    },
    [7] = {
        { 2746, "Golden Spellthread", "Tailoring" },                                     -- item=24276
        { 2745, "Silver Spellthread", "Tailoring (cheaper)" },                           -- item=24275
    },
    [8] = {
        { 2940, "Enchant Boots - Boar's Speed", "Enchanting" },                          -- spell=34008
    },
    [11] = {
        needs = "enchanting",
        { 2930, "Enchant Ring - Healing Power", "Enchanters only, Sha'tar Revered" },    -- spell=27926
    },
    [12] = {
        needs = "enchanting",
        { 2930, "Enchant Ring - Healing Power", "Enchanters only, Sha'tar Revered" },    -- spell=27926
    },
    [16] = {
        { 2666, "Enchant Weapon - Major Intellect", "Enchanting" },                      -- spell=27968
        { 2343, "Enchant Weapon - Major Healing", "Enchanting" },                        -- spell=34010
    },
    [17] = {
        needs = "shield",
        { 2654, "Enchant Shield - Intellect", "Enchanting" },                            -- spell=27945
    },
}
