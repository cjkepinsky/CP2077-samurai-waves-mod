# Waves Config

`settings.lua` contains global tuning values: timers, chase/search behavior, spawn retry limits, and default safe spawn distances.

The search settings split NPC behavior into three ranges: slow investigation toward the player area, forced combat when the player is close, and full chase after combat starts.

Set `POST_SPAWN_TELEPORT_CORRECTION_ENABLED = false` to disable all post-spawn teleport corrections while testing authored spawn locations. This does not disable despawn cleanup.

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
- `spawnLineRows` and `spawnLineRowSpacing`: optionally stagger line spawns into multiple parallel rows to avoid capsule overlap on dense waves.
- `extraSpawnPoint` and `extraSpawnFromIndex`: sends later spawns to one fixed point.
- `spawnPointStartIndex` and `spawnPointEndIndex`: limits which points from `spawnPoints` are active.
- `humanNavmeshCheckRadius`: optional pre-spawn human navmesh lookup radius. If a point is valid, the spawn request uses that navmesh point.
- `humanNavmeshRequired`: cancels the spawn when the pre-spawn human navmesh lookup fails. Leave this off for hand-placed waves where the engine's navmesh query rejects otherwise usable points.
- `searchTargetHumanNavmeshCheckRadius`: optional human navmesh lookup radius for non-combat search movement targets. If omitted, search movement reuses `humanNavmeshCheckRadius`.
- `skipEmptySpawnRetries`: skips fallback/same-position retries when the spawn system accepts a request but returns no spawned objects.
- `minTrackedForCompletion`: optional per-wave override for the minimum number of tracked NPCs required before the wave can complete and pay its stash reward. Otherwise the global completion threshold from `settings.lua` is used.
- `treasure`: optional guarded stash config. Use `rewardMoney` for the eddies granted when the wave is cleared, and optional `pos` to place the stash marker somewhere other than the middle of the spawn line.
- `playerWeaponRule`: optional player restriction for the wave. `type = "katanaOnly"` keeps only katana weapons equipped during the wave, grants/equips `katanaItem` as a fallback, and can restart the wave on a non-katana hit with `violationAction = "restartWave"`. Use `blockQuickhacks = true` to add `QuickHackImmunity` to tracked NPCs in that wave. Keep `requireKatanaHitForDefeat = true` when a tracked NPC should not count as defeated unless the mod saw a katana hit on it first.
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
- `treasure.lua`: guarded stash marker and wave-clear reward handling.
- `player_rules.lua`: per-wave player weapon restrictions.
- `hud.lua`: player-facing messages.
- `state.lua`: mutable mission/runtime state.

Useful debug hotkeys include `WavesForceWaveX`, `WavesForceAggro`, `WavesDespawnAll`, and `WavesKillAll`.
