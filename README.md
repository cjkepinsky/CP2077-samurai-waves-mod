# Samurai Waves

## English

Samurai Waves is a Cyberpunk 2077 mod built on Cyber Engine Tweaks. It adds a sequence of enemy waves, map/GPS navigation between locations, guarded stash rewards, and debug hotkeys for testing encounters.

The mod is built around authored wave locations. Each wave can define its own NPC records, spawn line or spawn points, marker position, search behavior, spawn retries, and reward.

Current version: `0.9.22`. `SamuraiWaves.log` includes the version in its log prefix, for example `[Samurai Waves v0.9.22]`, so bug reports can always be tied to a specific build.

### Requirements

- Cyberpunk 2077 on PC, with a working manual mod installation.
- Cyber Engine Tweaks installed in `Cyberpunk 2077/bin/x64/plugins/` and confirmed working in-game.
- CET must have completed its first-run setup, including the overlay keybind prompt.
- A save where the player can freely move around Night City and reach the authored wave locations.
- For the automatic map marker, load into gameplay rather than staying in the main menu.

The mod does not require Redscript, ArchiveXL, TweakXL, or Native Settings UI.

Tested locally with Cyberpunk 2077 `2.31` and Cyber Engine Tweaks `1.37.1`.

### Installation

#### Release ZIP

1. Download `SamuraiWaves-v0.9.22.zip`.
2. Extract it into the Cyberpunk 2077 game folder, the folder that contains `bin/`.
3. Confirm that the extracted files end up here:

```text
Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/mods/SamuraiWaves/init.lua
```

4. If you installed an older copy of this mod under `Waves` or `StaticShooters`, remove it or disable its `init.lua` before launching the game. CET loads every folder under `mods/`, so duplicate copies can start two runtimes at once.
5. Start the game. If the game is already running, use CET's `Reload Mods`; if the marker does not appear after a reload, fully restart the game.
6. Load a save. By default the mod starts automatically after a short delay and places the wave 1 marker on the map.

#### Manual Source Install

1. Download this repository as a ZIP or clone it with Git.
2. Create a folder named exactly `SamuraiWaves` here:

```text
Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/mods/SamuraiWaves
```

3. Copy the repository contents into that folder. The final layout must look like this:

```text
SamuraiWaves/
  init.lua
  helper.lua
  config/
  src/
```

Do not leave the files inside an extra nested folder such as `SamuraiWaves/CP2077-mod-waves-main/init.lua`.

4. Continue with steps 4-6 from the release ZIP install above.

The runtime log is written to `SamuraiWaves.log` in the mod folder.

After a successful load, `SamuraiWaves.log` should contain lines like:

```text
[Samurai Waves v0.9.22] Loaded
Starting mission | source=auto-start
Wave marker registered | wave=1
```

### How To Use

1. Load into the game. The CET runtime starts the contract automatically and places the wave 1 marker on the map.
2. The mod places a wave marker on the map and asks the game for a GPS route.
3. Go to the marked location. By default, the wave starts when the player is within `150m` of the marker.
4. Defeat the enemies.
5. The GPS marker stays active while the wave is running, so it is easier to keep orientation around the enemy location.
6. After the wave is cleared, the stash reward is paid and the next wave marker replaces the old one.
7. Repeat until all waves are cleared.

The mission also still supports the invitation bridge: native SMS, shard, or quest content can set `samurai_waves_invitation_accepted` to `1`. The CET runtime detects it, resets it, and starts the mission when auto-start is disabled or has not already run. `Samurai Waves - start mission` remains as a debug shortcut.

Each wave has a reward configured in `config/waves.lua`. The reward is granted by script after the wave is cleared; it is not a physical loot container.

Some waves can define `playerWeaponRule`. The built-in `katanaOnly` rule removes non-katana weapons from active weapon slots during that wave, equips a fallback katana if needed, and can restart the wave if the player damages a tracked NPC with anything other than a katana. With `blockQuickhacks = true`, tracked NPCs also receive quickhack immunity during the wave. With `requireKatanaHitForDefeat = true`, NPCs cannot count as defeated unless the mod saw a katana hit on them first.

### Hotkeys

Bind these in the CET overlay:

- `Samurai Waves - start mission`: starts from wave 1 and places the first marker.
- `Samurai Waves - stop mission`: stops the mission, clears markers, and despawns tracked NPCs.
- `Samurai Waves - force Wave X`: starts a specific wave for testing.
- `Samurai Waves - force aggro all`: forces spawned NPCs into hostile behavior.
- `Samurai Waves - chase player all`: reissues chase/aggro behavior.
- `Samurai Waves - despawn all NPCs`: despawns all tracked NPCs.
- `Samurai Waves - kill all spawned NPCs`: debug clear for currently tracked NPCs.
- `Samurai Waves - debug state`: writes mission and NPC state to `SamuraiWaves.log`.
- `Samurai Waves - test marker on player`: creates a marker at the player's current position.
- `Samurai Waves - show HUD countdown`: debug display for HUD timing.

### Configuration

Main configuration files:

- `config/settings.lua`: global timers, GPS refresh, spawn retry limits, search/chase behavior, and wave completion thresholds.
- `config/waves.lua`: wave list, NPC records, spawn locations, marker positions, rewards, and per-wave behavior.
- `config/README.md`: field-by-field notes for editing waves.

Useful values:

- `START_TRIGGER_DISTANCE`: distance from the marker at which a wave starts.
- `AUTO_START_ENABLED`: when `true`, starts the mission automatically after the player loads in.
- `AUTO_START_DELAY`: short delay before auto-start places the wave 1 marker.
- `INVITATION_ACCEPTED_FACT`: quest fact watched by the CET runtime. Set it to `1` from SMS/shard/quest content to start wave 1. The default fact is `samurai_waves_invitation_accepted`.
- `INVITATION_FACT_POLL_INTERVAL`: how often the runtime checks the invitation fact.
- `MARKER_ROUTE_REFRESH_INTERVAL`: how often the mod asks the game to refresh the active route.
- `PLAYER_WEAPON_RULE_INTERVAL`: how often a per-wave player weapon rule enforces equipped weapon slots.
- `WAVE_UNKNOWN_RESTART_LIMIT`: how many times a wave can restart if all tracked NPCs disappear before any confirmed defeat.
- `POST_SPAWN_TELEPORT_CORRECTION_ENABLED`: when `false`, disables post-spawn teleport corrections for all waves.
- `humanNavmeshCheckRadius`: optional human navmesh lookup before spawning.
- `humanNavmeshRequired`: when `true`, cancels a spawn if the human navmesh lookup fails.
- `skipEmptySpawnRetries`: when `false`, empty accepted spawn results are retried.
- `searchMovementType`: use `Strafe` for cautious weapon-ready searching.
- `searchAlwaysUseStealth`: keep this off unless you want crouch/kneel-style movement.

### Troubleshooting

#### The minimap does not show the GPS route

Open the full map once after the wave marker appears, then close it. Cyberpunk 2077 often does not propagate custom routes to the minimap until the full map initializes or refreshes the active tracked route.

If you manually click another destination on the map, the game can replace the Samurai Waves route with your manual waypoint. Open the full map again and select the Samurai Waves marker, or clear the manual waypoint and wait for the mod to refresh the route.

#### The map marker exists, but there is no route

Wait a second or two; the mod refreshes route tracking periodically. If the route still does not appear, open the full map, select the Samurai Waves marker, close the map, and move a few meters. The game sometimes needs an active route carrier before the minimap accepts the route.

#### The first marker does not appear

Check that the active folder is exactly `mods/SamuraiWaves/` and that `init.lua` is directly inside it. Then open `SamuraiWaves.log`.

- No `Loaded` line means CET did not load the mod folder.
- `Loaded` without `Starting mission` usually means the save has not reached gameplay yet, or `AUTO_START_ENABLED` is disabled.
- `Wave marker route not ready; pending retry` means the mod is retrying route activation. Open the full map once, close it, and wait a few seconds.

If you previously installed `Waves` or `StaticShooters`, make sure those folders are removed or their `init.lua` files are disabled.

#### The marker exists, but NPCs do not appear

Check `SamuraiWaves.log`. Useful lines:

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

If you still see an unwanted clear, keep the relevant `SamuraiWaves.log` lines around `Wave completion`, `unknown`, and `defeated`.

#### Hotkeys do not appear in CET

Check the folder structure and reload CET mods. `init.lua` must be directly inside the mod folder. Then check `SamuraiWaves.log` and the CET console for Lua load errors.

#### Old Log Files Still Exist

Older build logs can be ignored or deleted. Current builds write to `SamuraiWaves.log`.

### Development Notes

For a fresh install, use a folder named `SamuraiWaves` under CET's `mods` directory.

The default repository branch is `master`.

### License

Samurai Waves' original code and documentation are available under the MIT License. This does not grant rights to Cyberpunk 2077, Cyber Engine Tweaks, or any CD Projekt RED assets, trademarks, or intellectual property.

## Polski

Samurai Waves to mod do Cyberpunk 2077 oparty o Cyber Engine Tweaks. Dodaje sekwencję fal przeciwników, markery mapy, prowadzenie GPS między lokacjami, nagrody za pilnowane skrytki oraz hotkeye debugowe do testowania starć.

Mod jest zbudowany wokół ręcznie ustawianych fal. Każda fala może mieć własne rekordy NPC, linię albo punkty spawnu, pozycję markera, zachowanie szukania gracza, retry spawnu i nagrodę.

Aktualna wersja: `0.9.22`. `SamuraiWaves.log` zawiera wersję w prefixie logu, np. `[Samurai Waves v0.9.22]`, dzięki czemu zgłoszenia bugów można zawsze powiązać z konkretnym buildem.

### Wymagania

- Cyberpunk 2077 na PC, z działającą ręczną instalacją modów.
- Cyber Engine Tweaks zainstalowany w `Cyberpunk 2077/bin/x64/plugins/` i sprawdzony w grze.
- CET musi mieć ukończoną pierwszą konfigurację, w tym ustawiony klawisz overlayu.
- Save, w którym gracz może swobodnie poruszać się po Night City i dotrzeć do ręcznie ustawionych lokacji fal.
- Automatyczny marker pojawia się dopiero po wczytaniu rozgrywki, nie w menu głównym.

Mod nie wymaga Redscript, ArchiveXL, TweakXL ani Native Settings UI.

Lokalnie przetestowane z Cyberpunk 2077 `2.31` i Cyber Engine Tweaks `1.37.1`.

### Instalacja

#### ZIP Release

1. Pobierz `SamuraiWaves-v0.9.22.zip`.
2. Wypakuj go do folderu gry Cyberpunk 2077, czyli folderu zawierającego `bin/`.
3. Upewnij się, że pliki trafiły tutaj:

```text
Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/mods/SamuraiWaves/init.lua
```

4. Jeśli masz starszą kopię tego moda pod nazwą `Waves` albo `StaticShooters`, usuń ją albo wyłącz jej `init.lua` przed uruchomieniem gry. CET ładuje każdy folder z `mods/`, więc zdublowana instalacja może uruchomić dwa runtime'y naraz.
5. Uruchom grę. Jeśli gra już działa, użyj `Reload Mods` w CET; jeśli po reloadzie marker się nie pojawia, zrób pełny restart gry.
6. Wczytaj save. Domyślnie mod sam startuje po krótkim opóźnieniu i ustawia marker fali 1 na mapie.

#### Ręczna Instalacja Ze Źródeł

1. Pobierz repozytorium jako ZIP albo sklonuj je Gitem.
2. Utwórz folder o dokładnej nazwie `SamuraiWaves` tutaj:

```text
Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/mods/SamuraiWaves
```

3. Skopiuj zawartość repozytorium do tego folderu. Finalny układ musi wyglądać tak:

```text
SamuraiWaves/
  init.lua
  helper.lua
  config/
  src/
```

Nie zostawiaj plików w dodatkowym zagnieżdżonym folderze typu `SamuraiWaves/CP2077-mod-waves-main/init.lua`.

4. Kontynuuj od kroków 4-6 z instalacji ZIP release powyżej.

Log działania moda zapisuje się w pliku `SamuraiWaves.log` w folderze moda.

Po poprawnym załadowaniu `SamuraiWaves.log` powinien zawierać linie podobne do:

```text
[Samurai Waves v0.9.22] Loaded
Starting mission | source=auto-start
Wave marker registered | wave=1
```

### Jak Używać

1. Wczytaj grę. Runtime CET sam startuje kontrakt i ustawia marker fali 1 na mapie.
2. Mod ustawi marker fali na mapie i poprosi grę o trasę GPS.
3. Jedź albo idź do zaznaczonego miejsca. Domyślnie fala startuje, gdy gracz jest w promieniu `150m` od markera.
4. Pokonaj przeciwników.
5. Marker GPS zostaje aktywny podczas trwania fali, żeby łatwiej było orientować się wokół lokacji przeciwników.
6. Po wyczyszczeniu fali mod wypłaca nagrodę ze skrytki, a marker kolejnej fali zastępuje stary marker.
7. Powtarzaj aż do zakończenia wszystkich fal.

Most zaproszenia nadal działa przez quest fact: natywny SMS, shard albo quest może ustawić `samurai_waves_invitation_accepted` na `1`. Runtime CET wykryje to, zresetuje fact i wystartuje misję, jeśli autostart jest wyłączony albo jeszcze nie ruszył. `Samurai Waves - start mission` zostaje jako skrót debugowy.

Każda fala ma nagrodę skonfigurowaną w `config/waves.lua`. Nagroda jest wypłacana skryptem po wyczyszczeniu fali; to nie jest fizyczny kontener z lootem.

Wybrane fale mogą definiować `playerWeaponRule`. Wbudowana reguła `katanaOnly` usuwa broń niebędącą kataną z aktywnych slotów broni podczas tej fali, wyposaża gracza w awaryjną katanę, gdy trzeba, i może zrestartować falę, jeżeli gracz zada śledzonemu NPC obrażenia czymś innym niż katana. Przy `blockQuickhacks = true` śledzeni NPC dostają też odporność na quickhacki na czas fali. Przy `requireKatanaHitForDefeat = true` NPC nie zaliczy się jako pokonany, dopóki mod nie zobaczy na nim trafienia kataną.

### Hotkeye

Hotkeye przypisuje się w nakładce CET:

- `Samurai Waves - start mission`: startuje misję od fali 1 i ustawia pierwszy marker.
- `Samurai Waves - stop mission`: zatrzymuje misję, czyści markery i despawnuje śledzonych NPC.
- `Samurai Waves - force Wave X`: startuje wybraną falę do testów.
- `Samurai Waves - force aggro all`: wymusza wrogie zachowanie u zespawnowanych NPC.
- `Samurai Waves - chase player all`: ponawia zachowanie pościgu/aggro.
- `Samurai Waves - despawn all NPCs`: despawnuje wszystkich śledzonych NPC.
- `Samurai Waves - kill all spawned NPCs`: debugowe zabicie aktualnie śledzonych NPC.
- `Samurai Waves - debug state`: zapisuje stan misji i NPC do `SamuraiWaves.log`.
- `Samurai Waves - test marker on player`: tworzy marker w aktualnej pozycji gracza.
- `Samurai Waves - show HUD countdown`: debugowy podgląd komunikatów HUD.

### Konfiguracja

Główne pliki konfiguracyjne:

- `config/settings.lua`: globalne timery, odświeżanie GPS, limity retry spawnu, zachowanie szukania/pościgu i progi ukończenia fali.
- `config/waves.lua`: lista fal, rekordy NPC, lokacje spawnu, pozycje markerów, nagrody i zachowanie konkretnych fal.
- `config/README.md`: szczegółowy opis pól używanych przy edycji fal.

Przydatne ustawienia:

- `START_TRIGGER_DISTANCE`: odległość od markera, przy której fala startuje.
- `AUTO_START_ENABLED`: gdy jest `true`, startuje misję automatycznie po wczytaniu gracza.
- `AUTO_START_DELAY`: krótkie opóźnienie przed ustawieniem markera fali 1 przez autostart.
- `INVITATION_ACCEPTED_FACT`: quest fact obserwowany przez runtime CET. Ustaw go na `1` z SMS-a/sharda/questu, żeby wystartować wave 1. Domyślny fact to `samurai_waves_invitation_accepted`.
- `INVITATION_FACT_POLL_INTERVAL`: jak często runtime sprawdza quest fact zaproszenia.
- `MARKER_ROUTE_REFRESH_INTERVAL`: jak często mod próbuje odświeżyć aktywną trasę.
- `PLAYER_WEAPON_RULE_INTERVAL`: jak często reguła broni gracza wymusza aktywne sloty broni.
- `WAVE_UNKNOWN_RESTART_LIMIT`: ile razy fala może się zrestartować, jeśli wszyscy śledzeni NPC znikną przed potwierdzonym pokonaniem kogokolwiek.
- `POST_SPAWN_TELEPORT_CORRECTION_ENABLED`: jeśli jest `false`, wyłącza korekty teleportem po spawnie dla wszystkich fal.
- `humanNavmeshCheckRadius`: opcjonalne sprawdzenie human navmesh przed spawnem.
- `humanNavmeshRequired`: jeśli jest `true`, spawn zostaje anulowany, gdy sprawdzenie human navmesh się nie powiedzie.
- `skipEmptySpawnRetries`: jeśli jest `false`, puste zaakceptowane wyniki spawnu są ponawiane.
- `searchMovementType`: `Strafe` daje ostrożne, bojowe szukanie z bronią w ręku.
- `searchAlwaysUseStealth`: trzymaj wyłączone, jeśli nie chcesz ruchu w stylu kucania/klękania.

### Typowe Problemy

#### Minimapka Nie Pokazuje Trasy GPS

Otwórz dużą mapę raz po pojawieniu się markera fali, a potem ją zamknij. Cyberpunk 2077 często nie przekazuje customowej trasy na minimapę, dopóki duża mapa nie zainicjuje albo nie odświeży aktywnego śledzenia.

Jeśli klikniesz ręcznie inny cel na mapie, gra może zastąpić trasę Samurai Waves własnym waypointem. Otwórz dużą mapę ponownie i wybierz marker Samurai Waves albo usuń ręczny waypoint i poczekaj, aż mod odświeży trasę.

#### Marker Jest Na Mapie, Ale Nie Ma Trasy

Poczekaj sekundę lub dwie; mod cyklicznie odświeża trasę. Jeśli nadal jej nie ma, otwórz dużą mapę, wybierz marker Samurai Waves, zamknij mapę i przejdź albo przejedź kilka metrów. Gra czasem potrzebuje aktywnego route carriera, zanim minimapa przyjmie trasę.

#### Pierwszy Marker Się Nie Pojawia

Sprawdź, czy aktywny folder ma dokładnie ścieżkę `mods/SamuraiWaves/` i czy `init.lua` leży bezpośrednio w tym folderze. Potem otwórz `SamuraiWaves.log`.

- Brak linii `Loaded` oznacza, że CET nie załadował folderu moda.
- `Loaded` bez `Starting mission` zwykle oznacza, że save nie doszedł jeszcze do rozgrywki albo `AUTO_START_ENABLED` jest wyłączone.
- `Wave marker route not ready; pending retry` oznacza, że mod ponawia aktywację trasy. Otwórz dużą mapę raz, zamknij ją i poczekaj kilka sekund.

Jeśli wcześniej instalowałeś `Waves` albo `StaticShooters`, upewnij się, że te foldery są usunięte albo ich pliki `init.lua` są wyłączone.

#### Marker Jest, Ale NPC Się Nie Pojawiają

Sprawdź `SamuraiWaves.log`. Szczególnie przydatne linie:

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

Jeśli nadal zobaczysz niechciane zaliczenie, zachowaj fragment `SamuraiWaves.log` z liniami `Wave completion`, `unknown` i `defeated`.

#### Hotkeye Nie Pojawiają Się W CET

Sprawdź strukturę folderu i przeładuj mody w CET. Plik `init.lua` musi być bezpośrednio w folderze moda. Potem sprawdź `SamuraiWaves.log` oraz konsolę CET pod kątem błędów ładowania Lua.

#### Nadal Istnieją Stare Pliki Logu

Stare logi z wcześniejszych buildów można zignorować albo usunąć. Aktualna wersja pisze do `SamuraiWaves.log`.

### Notatki Developerskie

Przy świeżej instalacji użyj folderu `SamuraiWaves` w katalogu `mods` CET.

Domyślna gałąź repozytorium to `master`.

### Licencja

Oryginalny kod i dokumentacja Samurai Waves są dostępne na licencji MIT. Licencja nie nadaje praw do Cyberpunk 2077, Cyber Engine Tweaks ani żadnych zasobów, znaków towarowych lub własności intelektualnej CD Projekt RED.
