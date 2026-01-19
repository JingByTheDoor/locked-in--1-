MASSIVE GAME DESIGN DOCUMENT (GDD)
MASTER v1.3 — LOCKED DESIGN
1) High Concept

Genre: Top-down stealth-horror action
Camera: Fully top-down (Hotline Miami–style), player rotates on the spot
Core Fantasy:
Stay quiet to survive. Panic compounds mistakes. Sound escalates danger. Enough mistakes summon the Hunter, turning scavenging into a desperate escape.

Primary Hook:
A unified sound-driven escalation system controls enemy behavior, phase transitions, and the Hunter. There are no explicit meters—only consequences.

2) Core Pillars (Locked)

Sound is the single source of danger

Stealth is rewarded; panic is punished

Escalation spreads through sound, not omniscience

Oppressive readability (vision cone, sound ripples, distortion)

Damage is survivable but costly (HP → food)

Nights test preparation, not wave combat

When the Hunter arrives, looting ends—escape only

Fair but brutal: mistakes have massive consequences

3) Glossary (Locked Terms)

Base — Safehouse between runs

Scavenging — Enter hostile maps to gather resources

Night — Base defense phase

Expected Sound — Informational audio (no escalation)

Anomalous Sound — Escalation-driving audio

Local Noise — Short-term disturbance (single hot zone)

Global Pressure — Persistent hidden escalation memory

Phase 1 — Stealth

Phase 2 — Alert

Phase 3 — Hunted

Watcher — Alarm-capable enemy

Hunter — Unkillable pursuit entity

4) Core Gameplay Loop

Base Planning

Repair doors/windows

Allocate fuel, food, ammo

Scavenging Run

Large hand-designed map

Player-ended extraction (greed vs safety)

Sound management is survival

Extraction

Instant and safe once reached

Night Phase

Defend base from breaches

Repair damage under pressure

Repeat

Difficulty increases every 2–3 nights

5) World Structure

Base → Scavenging → Night

Base consumes resources → forces scavenging

Scavenging builds preparation

Night tests preparation

Poor scavenging = catastrophic nights

6) Sound System (Single Source of Truth)
6.1 Expected Sound (Informational)

Examples

Enemy footsteps

Idle noises

Ambient loops

Rules

Generates neutral ripples

No investigation

No local or global pressure

Visual

White / gray sound waves

6.2 Anomalous Sound (Escalation Driver)

Examples

Sprinting

Door slams

Furniture breaking

Combat impacts

Bat hits (wall/object)

Gunshots

Enemy callouts / alarms

Rules

Creates danger sound waves

Triggers investigation and convergence

Adds to Local Noise

Contributes to Global Pressure

Visual

Red ripples

Loudness = radius + thickness

6.3 Enemy Callouts (Mini-Alarms)

Triggered on direct sight

Always anomalous

Killing caller does not cancel escalation

Guarantees Phase 2 pressure spike

7) Noise Telemetry (Diegetic Only)

No meters or bars.

Feedback

Screen distortion increases

Audio tension layers intensify

Peripheral pulse / vignette

Player feels danger before seeing it

8) Sound Waves (Visualization)

All sounds generate ripples

Expected = neutral

Anomalous = danger

Off-screen indicators show direction of disturbances

9) Escalation System (Formalized)
9.1 Local Noise

Single hot zone only

Medium-fast decay over time

Decays faster once enemies investigate

Multiple sounds reinforce the same zone

9.2 Global Pressure

Hidden numeric value

Has internal tiers (not shown)

Never fully resets between runs

Increases via:

Sustained anomalies

Callouts

Watcher alarms

Environmental destruction

10) Escalation Phases
Phase 1 — Stealth

Tight vision cone

Minimal distortion

No heartbeat

Enemies patrol normally

Phase 2 — Alert (Gradient)

Triggered by

Enemy callouts

Watcher alarms

Sustained anomalies

Behavior

Enemies converge toward hot zone

Player can escape only with planned routes

Combat often becomes forced

Systems

Music intensifies

Heartbeat during combat

Slightly wider vision cone for readability

Phase 3 — Hunted (Hard Failure State)

Trigger (Hybrid Rule)

Global Pressure crosses threshold

Major escalation events spike pressure:

Watcher alarm

Enemy callout

Large destruction

Another major event shortly after

Meaning
Panic compounded—not time-based failure.

Rules

Hunter spawns

Noise rules overridden

Objective = ESCAPE OR DIE

Phase ends only by extraction or death

11) Enemy Ecosystem
11.1 Guard (Standard Enemy)

Patrol

Investigate

Callout

Melee attack

11.2 Watcher (Alarmer)

Rare placement

Alarm creates massive anomaly

Huge local spike + global pressure increase

12) The Hunter (Phase 3 Only)

Unkillable

Knows last known player position

Searches intelligently

Reacts to all anomalous sounds equally

Can be delayed by:

Doors

Gunshots

Hiding is possible but risky (chance of discovery)

13) Vision & Lighting

Darkwood-style vision cone

Darkness outside cone

Slight widening in Phase 2

Base lighting depends on generator

14) Combat System
14.1 Player HP

Max HP: 100

Persistent across scavenging and night

No regeneration

14.2 Healing

Food heals at base only

14.3 Facing & Control

Player always faces cursor

Movement allowed while attacking

14.4 Melee — Bat

Wide arc

Very short windup

High lethality, high risk

Noise

Air swing: minimal

Enemy hit: unavoidable anomaly

Wall/object hit: strong anomaly

14.5 Combat Philosophy

Every kill generates noise

Multiple kills compound pressure

Forced combat occurs when routes aren’t planned

14.6 Enemy Durability

Unaware: 1 hit

Alert: 2–3 hits

14.7 Enemy Damage

Unpredictable

First enemy hit always deals 50 damage (tutorial moment)

15) Weapons

Bat

Primary weapon

Quiet only when unused

Gun

Emergency tool

Extremely loud

Instant kill

Massive escalation spike

At night: attracts more enemies

Ammo

Rare but obtainable

Gun limited by noise, not scarcity

16) Items & Carrying

Items have Rank 1–5

Higher rank:

Slower movement

Louder interactions

Larger noise radius

Food & fuel use Grades instead

17) Resources

Scrap

Wood

Fuel

Food

Ammo

18) Base Layout & Repairs

2 doors

2–3 windows

Repair Costs

Door: 5 wood + 3 scrap

Window: 3 wood + 1 scrap

Repairs during night increase vulnerability

19) Generator

Capacity: 0–100%

Fuel drains at night (1% / 5 sec)

Failure = lights out = increased danger

20) Night Phase (Defined)

Goal

Survive timer

Behavior

Some nights calm

Some nights breach-heavy

Enemies target weak points

Player Role

Defend breaches

Kill intruders

Repair damage under pressure

Noise

Irrelevant unless gun is used

Gun attracts additional enemies

Failure

Resource loss

Base damage

Cumulative pressure across nights

21) Scavenging Maps

Large, hand-designed

≥2 exits per room (usually)

≥1 hiding spot (usually)

Some intentionally unfair but readable rooms

22) Extraction

Exit signs readable outside vision cone

Instant extraction

Always safe once reached

23) Death & Recovery

Scavenging death: return to base, no time loss

Night death: retry with consequences

24) Difficulty Ramp

Increases every 2–3 nights

Primary increase: more enemies

Pressure, not smarter AI (early)

25) Tutorial & Feedback

Core systems explained once

Clear cause-and-effect messaging

Afterward: player must infer

26) MVP Scope (True MVP)

MVP Includes

1 scavenging map

Guards only

Escalation → Phase system

Hunter

Bat combat

Base + basic night placeholder

Post-MVP Features (Planned)

Full Night system

Watchers

Gun

Multiple maps

Expanded base systems