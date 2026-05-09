# StaticShooters Config

`settings.lua` contains global tuning values: timers, chase/search behavior, spawn retry limits, and default safe spawn distances.

The search settings split NPC behavior into three ranges: slow investigation toward the player area, forced combat when the player is close, and full chase after combat starts.

`waves.lua` contains gameplay data only:

- `npcs`: reusable NPC record groups.
- `spawnLines`: fallback spawn lines used by waves that do not define their own locations.
- `locations`: named points, point lists, and line segments for specific waves.
- `waves`: the ordered wave list. The next wave marker is created from each wave location.

To add a wave, add any new NPC records to `npcs`, add a named location to `locations`, then append a new entry to `waves`.

Useful wave fields:

- `count`: number of NPCs to request.
- `npcs`: list of Character records to rotate through.
- `fallbackNpc`: safer replacement record if a spawn request fails.
- `markerPos`: explicit marker location. If omitted, the first spawn point or start of the spawn line is used.
- `spawnPoints`: exact spawn positions.
- `spawnLine`: distributes NPCs between `edgeA` and `edgeB`.
- `extraSpawnPoint` and `extraSpawnFromIndex`: sends later spawns to one fixed point.
- `spawnPointStartIndex` and `spawnPointEndIndex`: limits which points from `spawnPoints` are active.
- `minSpawnDistance`, `enforceMinSpawnDistance`, `pushSpawnAway`: protect against spawning too close to the player.
- `alwaysSearchPlayer`: makes non-combat search movement advance toward the player even outside the global search radius.
- `searchAroundHomeOnly`: makes non-combat search movement investigate near the spawn/home area instead of using the player's exact position.
- `searchMovementType`, `searchStepDistance`, `searchRadius`, `searchLeashDistance`, `searchStopDistance`, `searchAlwaysUseStealth`, `searchAlertStatusEffects`: tune local alert-search movement and visual alert state. Use `Strafe` for tactical weapon-ready searching; keep `searchAlwaysUseStealth` off unless you want crouch/kneel-style movement.
- `forceMeleeAttack`: tells the runtime to use melee attack commands once combat starts.

Runtime code lives in `../src/`:

- `mission_controller.lua`: high-level mission flow, hotkeys, CET events.
- `spawn_planner.lua`: chooses marker/spawn positions and safe fallbacks.
- `spawner.lua`: talks to `PreventionSpawnSystem`, tracks NPCs, retries bad spawns.
- `ai.lua`: hostile/search/chase behavior and defeated-state checks.
- `markers.lua`: map marker and GPS route handling.
- `hud.lua`: player-facing messages.
- `state.lua`: mutable mission/runtime state.

Useful debug hotkeys include `RunVRunForceWaveX`, `RunVRunForceAggro`, `RunVRunDespawnAll`, and `RunVRunKillAll`.
