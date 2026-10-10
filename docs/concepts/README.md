# Approved concept art

## Family Ledger mobile layouts

The Family Ledger mobile direction is approved as concept art for future design.
It carries the ivory paper, oxblood leather, forest green, burgundy, brass, and
rounded controls into portrait layouts with bottom notebook tabs.

![Approved mobile Family Ledger concepts](mobile_family_ledger.png)

- **City:** touch map with drag and pinch navigation, plus a fixed district sheet
  for inspection and orders.
- **Ledger:** finances, district selection, daily orders, and a separate Next day
  control.
- **Members:** crew selection, individual profiles, loyalty, and promotion
  decisions while time is paused.

This sheet records the approved visual and interaction direction. The map art is
illustrative; implemented district names, connections, and ownership are defined
by `game/simulation/city_layout.gd` and the world state. Mobile implementation is
a future task.

## Pixel Family Ledger

The pixel-art Family Ledger direction is approved as concept art. It keeps the
ivory paper, burgundy leather, forest-green accents, notebook tabs, and shaped
buttons, with bitmap lettering and small reusable character portraits.

![Approved pixel Family Ledger concepts](pixel_family_ledger.png)

The member flow runs from **Crew** to **Profile** to **Assignments**:

- **Crew:** browse names, ages, loyalty, and availability.
- **Profile:** inspect a member and review a promotion request.
- **Assignments:** choose a job and district, then confirm the assignment.

Skills (Earning, Management, and Negotiation) and job assignments are proposed
mechanics shown for design exploration. They are not implemented in the game.
This image records the approved visual direction rather than a game screenshot.

## Approved pixel palettes

All three palette variants are approved and retained for potential customization
or class-specific presentation. **02 Tobacco & Teal is the chosen main-game
design direction.** The runtime theme has not been replaced by these mockups.

![Approved pixel palette comparison](pixel_palette_studies.png)

| Variant | Palette | Intended use |
| --- | --- | --- |
| 01 Midnight Club | Navy, ivory, antique gold | Optional future customization or class palette |
| **02 Tobacco & Teal** | **Espresso leather, warm parchment, deep teal, copper** | **Main-game visual direction** |
| 03 Black Ink | Charcoal, grey-ivory, burgundy, pewter | Optional future customization or class palette |

The same Crew layout is repeated to compare colors. Palette selection should be
cosmetic; ownership, availability, warnings, and loyalty need explicit labels or
icons so their meaning survives color changes. Any future class mechanics remain
a separate design decision.

The [mobile-first requirements](../MOBILE_FIRST.md) record the proposed technical
and interaction foundations for this direction.
