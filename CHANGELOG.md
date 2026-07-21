# Changelog

## 0.9.23

- Fixed wave markers that were visible but did not start the wave when Cyberpunk refused GPS route tracking.
- This fixes the wave 4 case where the marker could be reached but no NPCs spawned because `routeOk=false` kept the marker trigger disabled.

## 0.9.22

- Renamed the runtime mod to `Samurai Waves`.
- Added automatic mission start after loading into gameplay.
- Added retry handling for the first wave map marker route activation.
- Updated the runtime log file to `SamuraiWaves.log`.
- Updated installation and troubleshooting documentation for public release.
- Added the MIT License for the original mod code and documentation.
- Tested locally with Cyberpunk 2077 `2.31` and Cyber Engine Tweaks `1.37.1`.
- Release ZIPs should use the game-root layout:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/SamuraiWaves/
```
