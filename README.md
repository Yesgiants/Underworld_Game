# Underworld_Game

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

## Repository Structure

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

**Stage:** Pre-alpha / simulation prototype

Current priorities:

- Establish the core project architecture
- Implement the simulation clock and game state
- Build the character system
- Build the organization system
- Establish automated testing
- Develop the first playable simulation loop

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
