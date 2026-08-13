# Puppeteer

Heal-assist raid frames for World of Warcraft 1.12 Vanilla (OctoWoW and compatible private servers).

Here i will just state what i added or changed - for full doc please go to https://github.com/OldManAlpha/Puppeteer

---

## Aura Filters

Puppeteer can suppress specific buffs from unit frames based on two independent lists, both managed from the **Options → Aura Filters** tab in the settings window.

### Combat Hidden Buffs

Buffs in this list are hidden from unit frames only while you are in combat. They reappear as soon as combat ends. Useful for decluttering the aura tracker during fights — for example, hiding long-duration consumable buffs or raid-wide blessings you do not need to monitor once a pull starts.

### Always Hidden Buffs

Buffs in this list are permanently hidden from unit frames at all times, in and out of combat. Useful for suppressing buffs you never want to see displayed.

### How to configure

1. Open the settings window (`/pt config` or the Puppeteer minimap button).
2. Go to the **Options** tab.
3. Click the **Aura Filters** sub-tab.
4. Click **Edit Combat Hidden Buffs** or **Edit Always Hidden Buffs**, depending on which list you want to edit.
5. In the editor that opens, type the exact name of each buff — **one name per line**. Names must match the in-game buff name exactly (case-sensitive).
6. Click **Save**. The list takes effect immediately without a reload.

### Example

**Combat Hidden Buffs:**
```
Arcane Brilliance
Mark of the Wild
Prayer of Fortitude
```

**Always Hidden Buffs:**
```
Food
Drink
```

### Notes

- Only buffs already in your tracked buff list can appear on frames. Adding a buff to either filter has no effect if it is not tracked in the first place.
- Enemy frames are unaffected — both filters apply only to friendly unit frames.
- The lists are saved per character in `WTF\Account\<account>\<realm>\<character>\SavedVariables\Puppeteer.lua`.
