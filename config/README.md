# Waves Config

`settings.lua` contains global tuning values: timers, chase/search behavior, spawn retry limits, and default safe spawn distances.

The search settings split NPC behavior into three ranges: slow investigation toward the player area, forced combat when the player is close, and full chase after combat starts.

Set `POST_SPAWN_TELEPORT_CORRECTION_ENABLED = false` to disable all post-spawn teleport corrections while testing authored spawn locations. This does not disable despawn cleanup.

`SPAWN_REQUEST_MAX_DISTANCE` delays actual NPC spawn requests until the player is close enough to each configured spawn point. This prevents the game from accepting a spawn request in an unloaded area and returning zero spawned objects.

Invitation settings live in `settings.lua`. Native SMS, shard, or quest content should set `INVITATION_ACCEPTED_FACT` to `1`; the CET runtime polls that fact with `INVITATION_FACT_POLL_INTERVAL` and starts the mission from wave 1.

`waves.lua` contains gameplay data only:

- `fallbackSpawnLines`: emergency spawn lines used only when a wave does not define its own location.
- `waves`: the ordered wave list. Each wave keeps its own NPC records, marker position, spawn line or exact spawn points, reward, and behavior in one readable block.

To add a wave, append a new entry to `waves`. Prefer inline `npcs = { C("...") }` and inline `spawnPoints` or `spawnLine` inside that wave, so the whole encounter can be edited in one place.

Reusable option groups live near the top of `waves.lua` in `optionGroups`. A wave can apply them with `optionGroups = { "actLikeNinja" }`. Groups are applied before the wave's own fields, so direct wave settings can override preset defaults.

Useful wave fields:

- `name`: human-readable wave title only, without a hardcoded `Wave N -` prefix. The runtime displays it as `Wave <list position> - <name>`.
- `club`: human-readable group label for the wave. Use `{club}` inside `startMessage` when the HUD text should include the group name.
- `startMessage`: optional HUD text shown when the wave starts. Supports `{club}`, `{name}`, and `{title}` placeholders.
- `count`: number of NPCs to request.
- `npcs`: list of Character records to rotate through.
- `npcWeaponPool`, `npcPrimaryWeaponPool`, or `npcWeapon`: optional primary weapon override for spawned NPCs. The runtime clones the selected `Character.*` record and swaps its primary equipment item, so you can reuse a melee NPC template with weapons such as `Items.Preset_Tomahawk_Default` or `Items.Preset_Fanged_Axe_Default`.
- `fallbackNpc`: safer replacement record if a spawn request fails.
- `markerPos`: explicit marker location. If omitted, the first spawn point or start of the spawn line is used.
- `spawnPoints`: exact spawn positions.
- `spawnLine`: distributes NPCs between `edgeA` and `edgeB`.
- `spawnLineRows` and `spawnLineRowSpacing`: optionally stagger line spawns into multiple parallel rows to avoid capsule overlap on dense waves.
- `extraSpawnPoint` and `extraSpawnFromIndex`: sends later spawns to one fixed point.
- `spawnPointStartIndex` and `spawnPointEndIndex`: limits which points from `spawnPoints` are active.
- `spawnRequestMaxDistance` or `spawnActivationDistance`: optional per-wave override for how close the player must be before a queued NPC spawn request is sent to the engine. Use `0` to disable the distance gate for a wave.
- `humanNavmeshCheckRadius`: optional pre-spawn human navmesh lookup radius. If a point is valid, the spawn request uses that navmesh point.
- `humanNavmeshRequired`: cancels the spawn when the pre-spawn human navmesh lookup fails. Leave this off for hand-placed waves where the engine's navmesh query rejects otherwise usable points.
- `searchTargetHumanNavmeshCheckRadius`: optional human navmesh lookup radius for non-combat search movement targets. If omitted, search movement reuses `humanNavmeshCheckRadius`.
- `skipEmptySpawnRetries`: skips fallback/same-position retries when the spawn system accepts a request but returns no spawned objects.
- `minTrackedForCompletion`: optional per-wave override for the minimum number of tracked NPCs required before the wave can complete and pay its stash reward. Otherwise the global completion threshold from `settings.lua` is used.
- `treasure`: optional guarded stash config. Use `rewardMoney` for the eddies granted when the wave is cleared, and optional `pos` to place the stash marker somewhere other than the middle of the spawn line.
- `playerWeaponRule`: optional player restriction for the wave. `type = "katanaOnly"` keeps only katana weapons equipped during the wave, grants/equips `katanaItem` as a fallback, and can restart the wave on a non-katana hit with `violationAction = "restartWave"`. Use `blockQuickhacks = true` to add `QuickHackImmunity` to tracked NPCs in that wave. Keep `requireKatanaHitForDefeat = true` when a tracked NPC should not count as defeated unless the mod saw a katana hit on it first.
- `optionGroups`: optional reusable behavior presets. Current built-in group: `actLikeNinja`, used for quiet ambush NPCs that stay passive/held until the player comes very close.
- `minSpawnDistance`, `enforceMinSpawnDistance`, `pushSpawnAway`: protect against spawning too close to the player.
- `alwaysSearchPlayer`: makes non-combat search movement advance toward the player even outside the global search radius.
- `searchAroundHomeOnly`: makes non-combat search movement investigate near the spawn/home area instead of using the player's exact position.
- `searchMovementType`, `searchStepDistance`, `searchRadius`, `searchLeashDistance`, `searchStopDistance`, `searchAlwaysUseStealth`, `searchAlertStatusEffects`: tune local alert-search movement and visual alert state. Use `Strafe` for tactical weapon-ready searching; keep `searchAlwaysUseStealth` off unless you want crouch/kneel-style movement.
- `forceMeleeAttack`: tells the runtime to use melee attack commands once combat starts.
- `holdUntilPlayerDistance`: keeps spawned NPCs passive and suppresses mod-driven awareness/search/combat commands until the player is within this distance.
- `passiveUntilPlayerDistance`, `passiveUntilPlayerAttitude`: keeps held NPCs neutral or friendly to the player before release, so they do not join combat when another NPC in the same wave wakes up.
- `holdPositionUntilPlayerDistance`, `holdPositionTolerance`, `holdPositionRefreshInterval`, `holdPositionMovementType`, `holdPositionStopDistance`: optional leash for held NPCs. If native AI starts moving them before release, the runtime reissues a quiet move-home command.
- `silentUntilPlayerDistance`: when used with `holdUntilPlayerDistance`, suppresses the mod's bark-prone early prime/awareness refreshes before release.
- `readyUntilPlayerDistance`: keeps held NPCs quietly ready before release. By default this sets hostile attitude, switches to the primary weapon, and optionally looks at the player without applying the normal aggressive reaction preset.
- `quietReadyMode`: optional quiet-ready strategy. Use `"weaponOnly"` to only switch to the primary weapon and apply quiet-ready status effects before release, avoiding hostile attitude and look-at commands that can trigger barks.
- `lookAtPlayerUntilPlayerDistance`, `quietReadyRefreshInterval`, `quietReadyStatusEffects`, `wakeQuietReady`: optional tuning for quiet-ready ambush behavior.
- `suppressCombatBarks`: makes hold-release combat avoid the reaction/stim calls most likely to trigger NPC chatter while still setting combat target and melee attack.
- `quietWakeSuppressCombatThreat`, `quietWakeSuppressCombatPreset`: optional stronger bark suppression for hold-release combat.
- `forceMeleeAttackOnWake`: sends one forced combat + melee attack burst when a held NPC is released by player proximity.
- `despawnDefeatedNPCs`: removes defeated NPCs as soon as the runtime confirms their defeat. The runtime checks both the normal wave-completion loop and `NPCPuppet.OnHit`, then repeats a few short post-hit checks in case the engine marks the NPC defeated one frame later. Useful for stealth/ambush waves where remaining NPCs should not react to bodies. This is CET-side instant cleanup, not a native redscript hook that disables the game's body-recognition stimulus itself.
- `autoCombatDistance`, `combatJoinDistance`, `directChaseDistance`: optional per-wave overrides for combat/chase thresholds.
- `disableAIMovement`: prevents the mod from issuing regular movement/search/chase commands for that wave. Native combat behavior can still move the NPC after combat starts.

Before returning the config, `waves.lua` prepares each wave:

- `name` is rebuilt from the wave's current list position, so reordering waves automatically renumbers the displayed title.
- `startMessage` placeholders are expanded after `name` is rebuilt.
- If `count` is omitted, it defaults to the number of spawn points.
- If `markerPos` is omitted, it defaults to the first spawn point.
- If `count` is higher than the number of spawn points, the runtime reuses points in order instead of stacking every extra NPC on the last point.

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
