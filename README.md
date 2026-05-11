# Waves

## English

Waves is a Cyberpunk 2077 mod built on Cyber Engine Tweaks. It adds a sequence of enemy waves, map/GPS navigation between locations, guarded stash rewards, and debug hotkeys for testing encounters.

The mod is built around authored wave locations. Each wave can define its own NPC records, spawn line or spawn points, marker position, search behavior, spawn retries, and reward.

Current version: `0.9.0`. `Waves.log` includes the version in its log prefix, for example `[Waves v0.9.0]`, so bug reports can always be tied to a specific build.

### Requirements

- Cyberpunk 2077 on PC.
- Cyber Engine Tweaks installed and working.
- CET hotkeys enabled and bound in the CET overlay.
- A save where the target areas are accessible.

The mod does not require Redscript, ArchiveXL, TweakXL, or Native Settings UI.

### Installation

1. Download or clone this repository.
2. Put the mod folder here:

```text
Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/mods/Waves
```

3. Make sure `init.lua`, `helper.lua`, `config/`, and `src/` are directly inside the mod folder.
4. Start or restart the game. If the game is already running, use CET's reload mods option.
5. Open the CET overlay and bind at least `Waves - start mission`.

The runtime log is written to `Waves.log` in the mod folder.

### How To Use

1. Press the hotkey bound to `Waves - start mission`.
2. The mod places a wave marker on the map and asks the game for a GPS route.
3. Go to the marked location. By default, the wave starts when the player is within `150m` of the marker.
4. Defeat the enemies.
5. After the wave is cleared, the stash reward is paid and the next wave marker is placed.
6. Repeat until all waves are cleared.

Each wave has a reward configured in `config/waves.lua`. The reward is granted by script after the wave is cleared; it is not a physical loot container.

### Hotkeys

Bind these in the CET overlay:

- `Waves - start mission`: starts from wave 1 and places the first marker.
- `Waves - stop mission`: stops the mission, clears markers, and despawns tracked NPCs.
- `Waves - force Wave X`: starts a specific wave for testing.
- `Waves - force aggro all`: forces spawned NPCs into hostile behavior.
- `Waves - chase player all`: reissues chase/aggro behavior.
- `Waves - despawn all NPCs`: despawns all tracked NPCs.
- `Waves - kill all spawned NPCs`: debug clear for currently tracked NPCs.
- `Waves - debug state`: writes mission and NPC state to `Waves.log`.
- `Waves - test marker on player`: creates a marker at the player's current position.
- `Waves - show HUD countdown`: debug display for HUD timing.

### Configuration

Main configuration files:

- `config/settings.lua`: global timers, GPS refresh, spawn retry limits, search/chase behavior, and wave completion thresholds.
- `config/waves.lua`: wave list, NPC records, spawn locations, marker positions, rewards, and per-wave behavior.
- `config/README.md`: field-by-field notes for editing waves.

Useful values:

- `START_TRIGGER_DISTANCE`: distance from the marker at which a wave starts.
- `MARKER_ROUTE_REFRESH_INTERVAL`: how often the mod asks the game to refresh the active route.
- `WAVE_UNKNOWN_RESTART_LIMIT`: how many times a wave can restart if all tracked NPCs disappear before any confirmed defeat.
- `humanNavmeshCheckRadius`: optional human navmesh lookup before spawning.
- `humanNavmeshRequired`: when `true`, cancels a spawn if the human navmesh lookup fails.
- `skipEmptySpawnRetries`: when `false`, empty accepted spawn results are retried.
- `searchMovementType`: use `Strafe` for cautious weapon-ready searching.
- `searchAlwaysUseStealth`: keep this off unless you want crouch/kneel-style movement.

### Troubleshooting

#### The minimap does not show the GPS route

Open the full map once after the wave marker appears, then close it. Cyberpunk 2077 often does not propagate custom routes to the minimap until the full map initializes or refreshes the active tracked route.

If you manually click another destination on the map, the game can replace the Waves route with your manual waypoint. Open the full map again and select the Waves marker, or clear the manual waypoint and wait for the mod to refresh the route.

#### The map marker exists, but there is no route

Wait a second or two; the mod refreshes route tracking periodically. If the route still does not appear, open the full map, select the Waves marker, close the map, and move a few meters. The game sometimes needs an active route carrier before the minimap accepts the route.

#### The marker exists, but NPCs do not appear

Check `Waves.log`. Useful lines:

- `Queueing Wave ...`: the wave started.
- `RequestUnitSpawn OK`: the game accepted a spawn request.
- `SpawnRequestFinished objects extracted: 0`: the game accepted a request but returned no NPC object.
- `Wave collapsed into unknown NPCs... restarting initialization`: NPCs appeared briefly, then became invalid before any confirmed defeat, so the mod restarted the wave.
- `Wave completion blocked`: the mod intentionally blocked a free reward or next-wave advance.

If this happens in a tight interior, elevator, wall edge, sidewalk edge, or multi-level area, move the spawn line or points to a more open human-walkable surface.

#### NPCs spawn in the air, in walls, or several meters away

Cyberpunk's spawn system can move, reject, or snap requested positions. Open sidewalks, streets, and plazas are the safest locations. Avoid dense geometry, stairs, elevators, doorframes, market stalls, and very narrow passages.

Wave tuning tips:

- Keep `lockSpawnPosition = true` if authored points should be respected.
- Use `humanNavmeshCheckRadius` so the engine can find a nearby human navmesh point.
- Avoid `humanNavmeshRequired = true` unless you really want a failed navmesh check to cancel the spawn.
- Use `spawnLineRows` and `spawnLineRowSpacing` to prevent dense line spawns from overlapping.
- Add `fallbackNpc` if specific NPC records spawn unreliably.

#### A wave clears itself and pays the reward

This should be guarded against. If all tracked NPCs become `unknown` before any confirmed defeat, the mod restarts that wave up to `WAVE_UNKNOWN_RESTART_LIMIT` times instead of paying the reward.

If you still see an unwanted clear, keep the relevant `Waves.log` lines around `Wave completion`, `unknown`, and `defeated`.

#### Hotkeys do not appear in CET

Check the folder structure and reload CET mods. `init.lua` must be directly inside the mod folder. Then check `Waves.log` and the CET console for Lua load errors.

#### The old log file still exists

Older builds wrote to `StaticShooters.log`. Current builds write to `Waves.log`. The old file can be ignored or deleted.

### Development Notes

The local development folder may still be named `StaticShooters`, but the runtime mod name is `Waves`. For a fresh install, use a folder named `Waves` under CET's `mods` directory.

The default repository branch is `master`.

## Polski

Waves to mod do Cyberpunk 2077 oparty o Cyber Engine Tweaks. Dodaje sekwencję fal przeciwników, markery mapy, prowadzenie GPS między lokacjami, nagrody za pilnowane skrytki oraz hotkeye debugowe do testowania starć.

Mod jest zbudowany wokół ręcznie ustawianych fal. Każda fala może mieć własne rekordy NPC, linię albo punkty spawnu, pozycję markera, zachowanie szukania gracza, retry spawnu i nagrodę.

Aktualna wersja: `0.9.0`. `Waves.log` zawiera wersję w prefixie logu, np. `[Waves v0.9.0]`, dzięki czemu zgłoszenia bugów można zawsze powiązać z konkretnym buildem.

### Wymagania

- Cyberpunk 2077 na PC.
- Zainstalowany i działający Cyber Engine Tweaks.
- Włączone i przypisane hotkeye w nakładce CET.
- Save, w którym docelowe obszary miasta są dostępne.

Mod nie wymaga Redscript, ArchiveXL, TweakXL ani Native Settings UI.

### Instalacja

1. Pobierz albo sklonuj repozytorium.
2. Umieść folder moda tutaj:

```text
Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/mods/Waves
```

3. Upewnij się, że bezpośrednio w folderze moda są pliki `init.lua`, `helper.lua` oraz katalogi `config/` i `src/`.
4. Uruchom albo zrestartuj grę. Jeśli gra już działa, użyj opcji reload mods w CET.
5. Otwórz nakładkę CET i przypisz przynajmniej hotkey `Waves - start mission`.

Log działania moda zapisuje się w pliku `Waves.log` w folderze moda.

### Jak Używać

1. Naciśnij hotkey przypisany do `Waves - start mission`.
2. Mod ustawi marker fali na mapie i poprosi grę o trasę GPS.
3. Jedź albo idź do zaznaczonego miejsca. Domyślnie fala startuje, gdy gracz jest w promieniu `150m` od markera.
4. Pokonaj przeciwników.
5. Po wyczyszczeniu fali mod wypłaca nagrodę ze skrytki i ustawia marker kolejnej fali.
6. Powtarzaj aż do zakończenia wszystkich fal.

Każda fala ma nagrodę skonfigurowaną w `config/waves.lua`. Nagroda jest wypłacana skryptem po wyczyszczeniu fali; to nie jest fizyczny kontener z lootem.

### Hotkeye

Hotkeye przypisuje się w nakładce CET:

- `Waves - start mission`: startuje misję od fali 1 i ustawia pierwszy marker.
- `Waves - stop mission`: zatrzymuje misję, czyści markery i despawnuje śledzonych NPC.
- `Waves - force Wave X`: startuje wybraną falę do testów.
- `Waves - force aggro all`: wymusza wrogie zachowanie u zespawnowanych NPC.
- `Waves - chase player all`: ponawia zachowanie pościgu/aggro.
- `Waves - despawn all NPCs`: despawnuje wszystkich śledzonych NPC.
- `Waves - kill all spawned NPCs`: debugowe zabicie aktualnie śledzonych NPC.
- `Waves - debug state`: zapisuje stan misji i NPC do `Waves.log`.
- `Waves - test marker on player`: tworzy marker w aktualnej pozycji gracza.
- `Waves - show HUD countdown`: debugowy podgląd komunikatów HUD.

### Konfiguracja

Główne pliki konfiguracyjne:

- `config/settings.lua`: globalne timery, odświeżanie GPS, limity retry spawnu, zachowanie szukania/pościgu i progi ukończenia fali.
- `config/waves.lua`: lista fal, rekordy NPC, lokacje spawnu, pozycje markerów, nagrody i zachowanie konkretnych fal.
- `config/README.md`: szczegółowy opis pól używanych przy edycji fal.

Przydatne ustawienia:

- `START_TRIGGER_DISTANCE`: odległość od markera, przy której fala startuje.
- `MARKER_ROUTE_REFRESH_INTERVAL`: jak często mod próbuje odświeżyć aktywną trasę.
- `WAVE_UNKNOWN_RESTART_LIMIT`: ile razy fala może się zrestartować, jeśli wszyscy śledzeni NPC znikną przed potwierdzonym pokonaniem kogokolwiek.
- `humanNavmeshCheckRadius`: opcjonalne sprawdzenie human navmesh przed spawnem.
- `humanNavmeshRequired`: jeśli jest `true`, spawn zostaje anulowany, gdy sprawdzenie human navmesh się nie powiedzie.
- `skipEmptySpawnRetries`: jeśli jest `false`, puste zaakceptowane wyniki spawnu są ponawiane.
- `searchMovementType`: `Strafe` daje ostrożne, bojowe szukanie z bronią w ręku.
- `searchAlwaysUseStealth`: trzymaj wyłączone, jeśli nie chcesz ruchu w stylu kucania/klękania.

### Typowe Problemy

#### Minimapka Nie Pokazuje Trasy GPS

Otwórz dużą mapę raz po pojawieniu się markera fali, a potem ją zamknij. Cyberpunk 2077 często nie przekazuje customowej trasy na minimapę, dopóki duża mapa nie zainicjuje albo nie odświeży aktywnego śledzenia.

Jeśli klikniesz ręcznie inny cel na mapie, gra może zastąpić trasę Waves własnym waypointem. Otwórz dużą mapę ponownie i wybierz marker Waves albo usuń ręczny waypoint i poczekaj, aż mod odświeży trasę.

#### Marker Jest Na Mapie, Ale Nie Ma Trasy

Poczekaj sekundę lub dwie; mod cyklicznie odświeża trasę. Jeśli nadal jej nie ma, otwórz dużą mapę, wybierz marker Waves, zamknij mapę i przejdź albo przejedź kilka metrów. Gra czasem potrzebuje aktywnego route carriera, zanim minimapa przyjmie trasę.

#### Marker Jest, Ale NPC Się Nie Pojawiają

Sprawdź `Waves.log`. Szczególnie przydatne linie:

- `Queueing Wave ...`: fala została uruchomiona.
- `RequestUnitSpawn OK`: gra zaakceptowała request spawnu.
- `SpawnRequestFinished objects extracted: 0`: gra zaakceptowała request, ale nie zwróciła obiektu NPC.
- `Wave collapsed into unknown NPCs... restarting initialization`: NPC pojawili się na chwilę, ale stali się nieważni przed potwierdzonym pokonaniem; mod restartuje falę.
- `Wave completion blocked`: mod celowo blokuje darmową nagrodę albo przejście do następnej fali.

Jeśli problem występuje w ciasnym wnętrzu, windzie, przy ścianie, na krawędzi chodnika albo w miejscu wielopoziomowym, przesuń linię lub punkty spawnu na bardziej otwartą powierzchnię, po której NPC mogą chodzić.

#### NPC Spawnują Się W Powietrzu, Ścianach Albo Kilka Metrów Obok

System spawnu Cyberpunka potrafi przesunąć, odrzucić albo snapnąć żądaną pozycję. Najbezpieczniejsze są otwarte chodniki, ulice i place. Unikaj punktów w gęstej geometrii, na schodach, w windach, przy futrynach, straganach i w bardzo wąskich przejściach.

Do strojenia fal:

- Zostaw `lockSpawnPosition = true`, jeśli ręcznie ustawione punkty mają być respektowane.
- Używaj `humanNavmeshCheckRadius`, żeby silnik znalazł pobliski punkt human navmesh.
- Unikaj `humanNavmeshRequired = true`, chyba że naprawdę chcesz anulować spawn po błędzie navmesh.
- Używaj `spawnLineRows` i `spawnLineRowSpacing`, żeby NPC nie nachodzili na siebie na gęstych liniach.
- Dodawaj `fallbackNpc`, jeśli konkretne rekordy NPC spawnują się niestabilnie.

#### Fala Sama Się Zalicza I Wypłaca Nagrodę

To powinno być blokowane. Jeśli wszyscy śledzeni NPC przejdą w `unknown` przed jakimkolwiek potwierdzonym pokonaniem, mod restartuje tę falę do `WAVE_UNKNOWN_RESTART_LIMIT` razy zamiast wypłacać nagrodę.

Jeśli nadal zobaczysz niechciane zaliczenie, zachowaj fragment `Waves.log` z liniami `Wave completion`, `unknown` i `defeated`.

#### Hotkeye Nie Pojawiają Się W CET

Sprawdź strukturę folderu i przeładuj mody w CET. Plik `init.lua` musi być bezpośrednio w folderze moda. Potem sprawdź `Waves.log` oraz konsolę CET pod kątem błędów ładowania Lua.

#### Nadal Istnieje Stary Plik Logu

Starsze buildy pisały do `StaticShooters.log`. Aktualna wersja pisze do `Waves.log`. Stary plik można zignorować albo usunąć.

### Notatki Developerskie

Lokalny folder developerski może nadal nazywać się `StaticShooters`, ale runtime'owa nazwa moda to `Waves`. Przy świeżej instalacji użyj folderu `Waves` w katalogu `mods` CET.

Domyślna gałąź repozytorium to `master`.
