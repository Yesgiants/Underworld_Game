# Mobile-first foundations

Underworld is intended to release on mobile first. The approved visual direction
is the [pixel Family Ledger in 02 Tobacco & Teal](concepts/README.md#approved-pixel-palettes).
Midnight Club and Black Ink are retained as possible customization or class
palettes. This document records recommendations, not completed mobile support.
The launch platform order, minimum devices, and monetization are still undecided.

## Current foundation and gaps

The Godot 4.6 project already separates its turn-based simulation from the UI,
uses seeded, saved random state, migrates older saves, writes saves through a
temporary file, and uses the Compatibility renderer. Those are useful starting
points for a small mobile game.

The current viewport is 1280 x 960. The layout includes desktop-sized minimum
widths, and the map handles mouse buttons, wheel motion, and keyboard input.
Saving is manual; there is no application background/resume handler in the UI.
There are no tracked export presets. Touch-native interaction, portrait layout,
lifecycle handling, and installed-device testing remain implementation work.

## Layout and interaction

- Use portrait as the recommended phone layout. Start with a representative
  360 x 640 logical layout, then reflow for taller phones and larger screens.
  This logical layout is distinct from a sprite's native pixel resolution.
- Give City, Ledger, and Crew their own pages. Keep primary navigation reachable
  by a thumb and show district details in an expandable sheet over the map.
- Respect OS safe areas, camera cutouts, gesture navigation, and the keyboard.
  Essential controls must fit a small supported phone without being obscured.
- Target at least 48 dp touch areas on Android or 44 pt on iOS, with spacing.
  These are platform UI units, not raw physical screen pixels; verify the
  actual sizing on devices. A small pixel sprite can have a larger hit area.
- Support tap selection, one-finger panning, and two-finger pinch zoom around
  the gesture position. Dragging or pinching must never issue a district order.
  Clear active touches when a gesture is cancelled or the app is interrupted.
- Provide visible ways to zoom and inspect information. Essential functions
  must not depend on a mouse hover, wheel, right click, or keyboard shortcut.
- Android Back should close the current sheet or return to the preceding page
  before leaving the game. Prevent accidental duplicate orders and day advances.

## Simulation and interruptions

- Keep rules, economy, members, rival decisions, and randomness independent of
  screen size, frame rate, UI animation, and platform services.
- Issue explicit simulation commands from every interface. Opening a profile,
  panning, or changing a palette must not advance time or consume random state.
- Continue settling world systems per day or confirmed order instead of giving
  every member a continuously running AI loop.
- Pause the automatic day timer and audio when backgrounded. Resume paused,
  with the player's prior screen and selected district restored where possible.
- Recommend explicit day advancement and no offline world progression for the
  initial release. An offline elapsed-time simulation would need its own rules.

## Persistence

- Autosave after each completed order, day, and other confirmed world mutation;
  also attempt a save on backgrounding. Saving only on exit cannot protect
  against an OS terminating the process without a final callback.
- Retain temporary-file replacement, add a last-known-good backup, and handle
  write failures and corrupted saves without overwriting a valid older save.
- Store data in Godot's writable `user://` location. Keep explicit schema
  versions and migrations as skills, ranks, or assignments are introduced.
- Retain stable member identities and saved simulation RNG state. Keep
  interface preferences, including palette and text size, separate from rules.
- Validate interrupted saves, backup recovery, and loading an older release's
  save on a physical device. Loading should leave the world paused.

## Pixel art, palettes, and readability

- Build reusable low-resolution portraits, icons, and button pieces, with a
  limited palette and texture atlases where useful. Use nearest-neighbor
  filtering for pixel art and align it to a consistent pixel grid.
- Keep names, statistics, buttons, and event text live. The concept sheets are
  references, not full-screen images to ship as the playable interface.
- Scale art and readable text deliberately; do not force the whole phone UI
  into a tiny render buffer just to obtain a pixel effect.
- Define semantic theme colors in shared resources: paper, ink, accent,
  selection, warning, and disabled states. Avoid embedding palette-specific
  hex values across every screen.
- Palette choices must preserve labels, icons, contrast, and faction identity.
  A class-specific cosmetic palette must not accidentally redefine heat or
  ownership colors. Any gameplay effects of classes need separate rules.
- Offer larger text and test long member names. Choose fonts with the needed
  character coverage, separate localizable strings from UI construction, and
  support reduced animation and independent sound controls.

## Performance and device scope

- Define a minimum supported phone and OS range early. Measure on a modest
  physical device, not only the desktop editor or emulator.
- Use the existing Compatibility renderer as a baseline to test. Keep the
  map, sprites, and ledger inexpensive; update static screens when data changes.
- Target stable interaction, with 60 fps where practical and a 30 fps battery
  option. Measure simulation day spikes, memory, startup time, and battery use
  before assigning firm budgets.
- Test a late-game save with more members and events. Bound retained histories,
  cache reusable assets, and avoid work while the app is in the background.

## Export and release groundwork

- Produce an installed debug build for the first chosen mobile platform early.
  Add repeatable export presets and matching Godot export templates, then keep
  simulation tests running alongside the mobile build workflow.
- Android export needs its platform SDK and supported JDK. iOS distribution
  needs a macOS/Xcode signing and build workflow. Choose package identifiers
  early and store signing keys or credentials outside version control.
- Recommend offline single-player for the first release, with local saves and
  no mandatory account or server. Cloud saves can be a later, separate feature.
- Track licenses for fonts, sprites, sound, and other bundled assets. Prepare
  age ratings, store listings, privacy disclosures, and the platform's current
  submission requirements before release.
- If paid digital palettes or other purchases are introduced, plan platform
  billing, entitlement persistence, and restoring purchases. Monetization has
  not been selected; none of these systems are required for this prototype now.

## First mobile milestone

Before adding substantial new member systems, validate this complete path on a
physical phone: open the City page, pan and zoom, select a district, inspect a
member, issue an operation, advance a day, background or terminate the app, and
resume with progress intact. Test the smallest supported screen, safe areas,
drag-versus-tap behavior, Back navigation, and repeated taps. This milestone
establishes that the game can be played, interrupted, and resumed on mobile.
