# SKILL//ISSUE

**A fast-paced circular reflex game for Android, built independently in Godot 4 using GDScript.**

SKILL//ISSUE is a minimalist arcade game built around a simple idea: **your previous movements become the obstacles you have to survive.**

The player continuously orbits an arena and can switch between an inner and outer lane. Each completed lap records the player's movements, which are then replayed by an **Echo**. As the run continues, more Echoes are introduced and the arena becomes increasingly difficult to navigate.

The project was designed, developed, tested and iterated on as an independent game-development project.

---

## Gameplay

The controls are deliberately simple:

* The player automatically orbits the arena.
* Tap to switch between the inner and outer lanes.
* Complete laps to increase your score.
* Previous movement patterns return as Echoes.
* Avoid colliding with an Echo for as long as possible.

The challenge comes from planning around decisions you made several laps earlier rather than reacting only to randomly generated obstacles.

---

## Technical Overview

**Engine:** Godot 4.7
**Language:** GDScript
**Primary platform:** Android
**Version control:** Git / GitHub

The project has been used to develop experience with:

* Object-oriented scripting
* Godot's node and scene architecture
* Signals and event-driven communication
* Runtime scene instantiation
* Mobile touch input
* Collision detection
* Player-state management
* Recorded movement data
* Persistent save data
* UI systems
* Particle and visual effects
* Audio implementation
* Android exporting and deployment
* Git branching and version control
* Debugging and iterative development

---

## Core Systems

### Player Controller

The player is implemented as an `Area2D` and continuously moves around the arena using angular movement.

The controller manages:

* Inner and outer orbit radii
* Lane switching
* Angular speed
* Lap tracking
* Movement recording
* Input locking
* Collision interaction
* Sound and visual feedback

Player movement during each lap is recorded so that it can later be recreated by the Echo system.

---

### Echo System

Each completed lap can generate an Echo that recreates a previous player path.

The Echo system:

* Stores previously recorded movement
* Replays lane switches
* Moves independently around the arena
* Uses a phase offset to create separation from the player
* Warns the player before some lane changes
* Detects collisions with the player

This means the player is effectively creating their own future hazards.

---

### Arena Controller

The arena acts as the central game-state controller.

It is responsible for systems including:

* Score progression
* Echo spawning
* Lap handling
* Game-over state
* Restart handling
* UI updates
* Arena positioning
* Visual progression
* Hazard feedback
* Player/Echo communication

Much of the communication between systems is handled using Godot signals rather than tightly coupling individual scripts.

---

## Difficulty & Player Feedback

A significant part of development has involved balancing difficulty and making dangerous situations readable.

Examples include:

* Pre-switch warning effects on Echoes
* Hazard highlighting
* Lane-switch particle effects
* Ring glow effects
* Visual feedback when completing laps
* Game-over overlays
* Progressive visual escalation
* Input protection around restart states

The early difficulty was deliberately adjusted following testing so that players have more opportunity to understand the Echo mechanic before the game becomes highly demanding.

---

## Persistence

SKILL//ISSUE includes a local save system for persistent information such as the player's best score.

The save system is handled separately from the gameplay controller so that persistence logic is not tied directly to the arena.

---

## Android Development

The project has been developed and tested directly on Android hardware.

This has involved working with:

* Android builds from Godot
* APK and AAB exports
* Device debugging
* ADB
* Mobile input testing
* Responsive UI behaviour
* Release signing
* Google Play Console testing

The project has also been used to begin implementing groundwork for Google Play Games leaderboard functionality.

---

## AI-Assisted Development

AI tools have been used throughout development as part of the engineering workflow.

Rather than using AI as a replacement for understanding the project, I use it primarily to:

* Discuss possible approaches before implementing a system
* Break larger problems into manageable steps
* Explain unfamiliar programming concepts
* Review code and identify potential causes of bugs
* Accelerate debugging
* Suggest alternative implementations
* Help refactor or restructure code
* Learn more about Godot and GDScript while actively building
* Compare possible solutions before deciding which approach fits the project

AI-generated suggestions are tested and integrated manually within the project.

A large part of the development process involves identifying when an AI suggestion **doesn't** fit the existing architecture, debugging the resulting behaviour, and adapting the implementation accordingly.

Using AI in this way has allowed me to build increasingly complex systems while simultaneously improving my own understanding of programming and software development.

---

## Development Approach

SKILL//ISSUE has been developed iteratively rather than from a finished tutorial or template.

My typical workflow is:

1. Define the behaviour or problem.
2. Break the feature into smaller systems.
3. Research or discuss potential approaches.
4. Implement the feature in GDScript.
5. Test it in the Godot editor.
6. Deploy to an Android device where appropriate.
7. Identify bugs or usability problems.
8. Refactor or rebalance the implementation.
9. Commit working changes through Git.

This process has been particularly useful for learning how changes to one system can affect seemingly unrelated parts of a project.

---

## Project Structure

Some of the main scripts include:

```text
OrbitPlayer.gd
    Player movement, lane switching and lap recording.

OrbitEcho.gd
    Playback of recorded player paths and collision behaviour.

arena.gd
    Main arena state, scoring, Echo management and game flow.

SaveManager.gd
    Persistent local save data.

Pause_Menu.gd
    Pause and interface behaviour.
```

The project uses multiple scenes and scripts rather than keeping all gameplay logic inside a single controller.

---

## Current Status

SKILL//ISSUE is currently being developed and tested as an Android release.

Current areas of development include:

* Gameplay balancing
* Visual polish
* Player feedback
* Mobile optimisation
* Google Play integration
* Retention and progression systems

---

## What I Learned

This project began as a relatively simple arcade-game concept but has become one of my main practical software-development learning projects.

Working on SKILL//ISSUE has given me experience solving problems involving:

* State management
* Timing
* Input handling
* Data recording and playback
* Event-driven architecture
* Debugging interactions between systems
* Mobile deployment
* Version control
* Refactoring
* Designing systems that need to remain understandable as a project grows

It has also helped move me from simply following programming examples toward being able to reason about how different systems should interact.

---

## Screenshots

*Screenshots / gameplay GIFs will be added here.*

```text
docs/screenshots/gameplay.png
docs/screenshots/echo_system.png
docs/screenshots/game_over.png
```

---

## Repository

This repository contains the source code for SKILL//ISSUE.

Sensitive signing credentials, generated Godot files and private configuration files are intentionally excluded from version control.

---

## Developer

**Ben Carr**

GitHub: [b-cxrr](https://github.com/b-cxrr)

Independent developer currently building experience in software engineering, GDScript, Godot and AI-assisted development.
