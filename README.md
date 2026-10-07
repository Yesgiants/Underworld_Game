# Underworld_Game

## Play the prototype

The first playable prototype is a small Godot management game: a clickable city
map, organization statistics, daily orders, and an event feed. The city simulates
rival decisions, business income, payroll, market demand, loyalty, and police
pressure each day, including when the player issues no orders.

Requires the standard **Godot 4.6.3** editor; no .NET build, plugins, or external
services are required.

```bash
cd Underworld_Game
godot --path .
```

Alternatively, import `project.godot` into Godot and press **F6** on the main scene
or **F5** to run the project. For the prepared cloud environment:

```bash
cd /workspace/Underworld_Game
source /workspace/.underworld-dev/env.sh
godot --editor --path .
```

Graphical play needs a desktop/display. Simulation and interface tests also run
headlessly.

### How to play

- Select a district on the city map. Gold is Navarro, purple is Romano, teal is
  Moretti, and outlined gray districts are independent.
- Issue up to **two orders per day**. Orders apply immediately. Hover over a
  button for its requirements and consequences.
- **Run operation** earns cash and raises heat. **Open business** increases daily
  revenue. **Recruit member** strengthens the organization but increases payroll.
- **Claim district** expands into adjacent territory. Independent claims succeed;
  rival challenges depend on relative members and influence. The $6,000 cost is
  spent even if a challenge fails. Existing businesses transfer with a district.
- **Lay low** reduces heat. At 65 heat or above, police may investigate, seize cash,
  and reduce loyalty. Red dots on the map mark high local surveillance; that
  district statistic is currently informational, while organization heat drives
  investigations.
- Review promotion requests to manage loyalty. Each promotion costs $1,200 and
  grants 6 loyalty; declining loses 5. Member decisions do not use daily orders.
- Click **Next day** (or Space when no button has focus) to settle accounts and let
  rivals act. **Run time** advances a day every 2.5 seconds; click again to pause.
- **Save** and **Load** keep one local save under Godot's `user://` directory,
  including the random state. Loading pauses time. **New city** asks before
  discarding unsaved progress and preserves your saved game.

This is an open-ended sandbox, with no victory condition yet. The simulation is
turn based; automatic time is a convenience for advancing the same daily steps.
Members are currently an organization count with shared loyalty and named
promotion events, rather than individual simulated NPCs. Rival AI uses the same
action costs, ownership, adjacency, and heat rules as the player, with one order
per rival each day. Rivals that lose all territory cannot currently return.

### Validate the prototype

```bash
godot --headless --path . --editor --import
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/ui_smoke.gd
```

The simulation tests exercise autonomous world progression, orders and costs,
income and payroll, police responses, promotions, deterministic replay, local
save/load, and rejection of malformed saves. The UI smoke test exercises district
selection, actions, HUD updates, time controls, promotion decisions, and layout.

The implementation lives in `game/simulation/world_state.gd` (world rules),
`game/ui/city_map.gd` (map drawing and selection), and `game/ui/main.gd` (interface).

- Underworld

  **Underworld** is a systems-driven crime organization strategy/RPG currently in early prototype development.

  The long-term goal is to create a living criminal underworld in which the player exists both as an individual character and as a member or leader of an organization. Criminal factions, businesses, law enforcement, NPCs, territory, relationships, and the economy are intended to operate as interconnected simulation systems rather than primarily through scripted events.

  The project is currently focused on proving the underlying simulation before expanding into full character movement, combat, detailed graphics, or large-scale world content.
  ## Prototype Goal
  The first major milestone is **Underworld Simulation Prototype 0.1**.

  The purpose of Prototype 0.1 is to answer one question:
  > Can managing and growing a criminal organization be compelling when rival factions, NPCs, businesses, and law enforcement react dynamically to the player's actions?
  The prototype will initially use a small simulated area with simple graphics and a management-focused interface.
  ---- Another important question is, can the world and NPCs operate independently without player input?
  ## Prototype 0.1 Scope
  Planned systems include:
  - Player-controlled criminal organization
  - Rival criminal organizations
  - Simulated characters and organization members
  - Character traits, skills, loyalty, ambition, and relationships
  - Businesses and revenue
  - Legal and illegal economic activity
  - Organization finances
  - Territory and influence
  - Faction relationships
  - Utility-based NPC and faction decision-making
  - Crime and heat
  - Police attention and investigations
  - Dynamic events
- Time progression
- Save/load system
- Basic management interface
- Simplified city map

The initial prototype will deliberately avoid large amounts of content and visual polish so development can focus on the simulation.

## Design Principles

### Systems Over Scripts

Where practical, events should emerge from interacting systems rather than predetermined storylines.

A member may betray an organization because of ambition, poor relationships, fear, financial incentives, or other simulated conditions rather than because a scripted mission requires betrayal.

### The World Exists Without the Player

Organizations, characters, businesses, and law enforcement should continue pursuing their own goals regardless of player involvement.

The player participates in the world rather than being the sole cause of activity within it.

### Shared Rules

Player organizations and AI organizations should operate under the same underlying rules whenever practical.

AI factions should earn money, recruit members, compete for territory, suffer losses, and attract law-enforcement attention through the same systems available to the player.

### Explainable Simulation

Important AI and simulation decisions should be understandable and debuggable.

Core gameplay behavior should primarily use deterministic systems, weighted decision-making, and utility AI rather than relying on external language models during normal gameplay.

### Emergent Stories

Character traits, relationships, faction goals, economic pressures, territory disputes, and law-enforcement activity should combine to create unscripted stories.

The simulation should create situations rather than simply select from predetermined narratives.

## Planned Architecture

The project is being developed around modular simulation systems.

```text
GameState
│
├── SimulationClock
├── World
│   ├── Districts
│   ├── Properties
│   └── Businesses
│
├── Population
│   └── Characters
│
├── Organizations
│   ├── Player Organizations
│   ├── Criminal Factions
│   └── Law Enforcement
│
├── EconomySystem
├── RelationshipSystem
├── TerritorySystem
├── CrimeSystem
├── HeatSystem
├── InvestigationSystem
├── DecisionSystem
├── EventSystem
└── SaveSystem
```

Systems should remain as independent as practical and communicate through clearly defined interfaces, events, or signals.

## Development Philosophy

Underworld is being developed from the simulation outward.

The planned development order is roughly:

1. Core game state and simulation clock
2. Characters
3. Organizations
4. Relationships
5. Businesses and economy
6. Activities and jobs
7. Territory and influence
8. Character and faction AI
9. Crime and heat
10. Law-enforcement investigations
11. Dynamic events
12. Save/load
13. Management UI
14. City map
15. Player character systems
16. World interaction
17. Combat
18. Expanded content and presentation

Visual polish will come after the underlying systems demonstrate compelling gameplay.

## Technology

Current planned technology:

- **Engine:** Godot
- **Language:** GDScript
- **Version Control:** Git / GitHub
- **Development Assistance:** AI-assisted software development and testing

AI development tools may assist with implementation, testing, debugging, documentation, and architecture, but gameplay simulation is intended to remain locally controlled and reproducible.

## Planned Repository Structure

```text
underworld/
│
├── README.md
├── docs/
│   ├── GAME_VISION.md
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md
│   ├── SYSTEMS.md
│   ├── DESIGN_RULES.md
│   └── CHANGELOG.md
│
├── game/
│   ├── simulation/
│   │   ├── characters/
│   │   ├── organizations/
│   │   ├── economy/
│   │   ├── relationships/
│   │   ├── territory/
│   │   └── law_enforcement/
│   │
│   ├── world/
│   ├── ui/
│   ├── data/
│   └── tests/
│
└── project.godot
```

The directory structure will evolve as development progresses.

## Current Status

**Stage:** Playable pre-alpha management simulation prototype

Current priorities:

- Expand members into individual simulated characters
- Add deeper organization relationships and competing goals
- Improve economic balance through playtesting
- Expand activities, investigations, and emergent events
- Keep the world simulation deterministic and covered by automated tests

## Long-Term Vision

The eventual goal is a much larger crime-focused grand strategy/RPG combining:

- Individual character progression
- Criminal organization management
- Rival gangs and organized crime factions
- Legal businesses and fronts
- Illegal enterprises and rackets
- Dynamic relationships and diplomacy
- Territory competition
- Local, state, and federal law enforcement
- Investigations and organized-crime cases
- Population and economic simulation
- Character-level and organization-level progression
- Combat and conflict
- A persistent, reactive world

These are long-term goals and should not be interpreted as features currently implemented.

## Project Status

Underworld is an experimental independent game-development project currently under active prototyping.

Expect major systems, architecture, mechanics, and scope to change as the simulation is tested.
