# Waves

Waves to mod do Cyberpunk 2077 oparty o Cyber Engine Tweaks. Dodaje sekwencję fal przeciwników, markery mapy, prowadzenie GPS między lokacjami, nagrody za pilnowane skrytki oraz hotkeye debugowe do testowania poszczególnych starć.

Mod jest zbudowany wokół ręcznie ustawianych fal. Każda fala może mieć własne rekordy NPC, linię albo punkty spawnu, pozycję markera, zachowanie szukania gracza, retry spawnu i nagrodę.

## Wymagania

- Cyberpunk 2077 na PC.
- Zainstalowany i działający Cyber Engine Tweaks.
- Włączone i przypisane hotkeye w nakładce CET.
- Save, w którym docelowe obszary miasta są dostępne.

Mod nie wymaga Redscript, ArchiveXL, TweakXL ani Native Settings UI.

## Instalacja

1. Pobierz albo sklonuj repozytorium.
2. Umieść folder moda tutaj:

```text
Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/mods/Waves
```

3. Upewnij się, że bezpośrednio w folderze moda są pliki `init.lua`, `helper.lua` oraz katalogi `config/` i `src/`.
4. Uruchom albo zrestartuj grę. Jeśli gra już działa, użyj opcji reload mods w CET.
5. Otwórz nakładkę CET i przypisz przynajmniej hotkey `Waves - start mission`.

Log działania moda zapisuje się w pliku `Waves.log` w folderze moda.

## Jak używać

1. Naciśnij hotkey przypisany do `Waves - start mission`.
2. Mod ustawi marker fali na mapie i poprosi grę o trasę GPS.
3. Jedź albo idź do zaznaczonego miejsca. Domyślnie fala startuje, gdy gracz jest w promieniu `150m` od markera.
4. Pokonaj przeciwników.
5. Po wyczyszczeniu fali mod wypłaca nagrodę ze skrytki i ustawia marker kolejnej fali.
6. Powtarzaj aż do zakończenia wszystkich fal.

Każda fala ma nagrodę skonfigurowaną w `config/waves.lua`. Nagroda jest wypłacana skryptem po wyczyszczeniu fali; to nie jest fizyczny kontener z lootem.

## Hotkeye

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

## Konfiguracja

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

## Typowe problemy

### Minimapka nie pokazuje trasy GPS

Otwórz dużą mapę raz po pojawieniu się markera fali, a potem ją zamknij. Cyberpunk 2077 często nie przekazuje customowej trasy na minimapę, dopóki duża mapa nie zainicjuje albo nie odświeży aktywnego śledzenia.

Jeśli klikniesz ręcznie inny cel na mapie, gra może zastąpić trasę Waves własnym waypointem. Otwórz dużą mapę ponownie i wybierz marker Waves albo usuń ręczny waypoint i poczekaj, aż mod odświeży trasę.

### Marker jest na mapie, ale nie ma trasy

Poczekaj sekundę lub dwie; mod cyklicznie odświeża trasę. Jeśli nadal jej nie ma, otwórz dużą mapę, wybierz marker Waves, zamknij mapę i przejdź albo przejedź kilka metrów. Gra czasem potrzebuje aktywnego route carriera, zanim minimapa przyjmie trasę.

### Marker jest, ale NPC się nie pojawiają

Sprawdź `Waves.log`. Szczególnie przydatne linie:

- `Queueing Wave ...`: fala została uruchomiona.
- `RequestUnitSpawn OK`: gra zaakceptowała request spawnu.
- `SpawnRequestFinished objects extracted: 0`: gra zaakceptowała request, ale nie zwróciła obiektu NPC.
- `Wave collapsed into unknown NPCs... restarting initialization`: NPC pojawili się na chwilę, ale stali się nieważni przed potwierdzonym pokonaniem; mod restartuje falę.
- `Wave completion blocked`: mod celowo blokuje darmową nagrodę albo przejście do następnej fali.

Jeśli problem występuje w ciasnym wnętrzu, windzie, przy ścianie, na krawędzi chodnika albo w miejscu wielopoziomowym, przesuń linię lub punkty spawnu na bardziej otwartą powierzchnię, po której NPC mogą chodzić.

### NPC spawnują się w powietrzu, ścianach albo kilka metrów obok

System spawnu Cyberpunka potrafi przesunąć, odrzucić albo snapnąć żądaną pozycję. Najbezpieczniejsze są otwarte chodniki, ulice i place. Unikaj punktów w gęstej geometrii, na schodach, w windach, przy futrynach, straganach i w bardzo wąskich przejściach.

Do strojenia fal:

- Zostaw `lockSpawnPosition = true`, jeśli ręcznie ustawione punkty mają być respektowane.
- Używaj `humanNavmeshCheckRadius`, żeby silnik znalazł pobliski punkt human navmesh.
- Unikaj `humanNavmeshRequired = true`, chyba że naprawdę chcesz anulować spawn po błędzie navmesh.
- Używaj `spawnLineRows` i `spawnLineRowSpacing`, żeby NPC nie nachodzili na siebie na gęstych liniach.
- Dodawaj `fallbackNpc`, jeśli konkretne rekordy NPC spawnują się niestabilnie.

### Fala sama się zalicza i wypłaca nagrodę

To powinno być blokowane. Jeśli wszyscy śledzeni NPC przejdą w `unknown` przed jakimkolwiek potwierdzonym pokonaniem, mod restartuje tę falę do `WAVE_UNKNOWN_RESTART_LIMIT` razy zamiast wypłacać nagrodę.

Jeśli nadal zobaczysz niechciane zaliczenie, zachowaj fragment `Waves.log` z liniami `Wave completion`, `unknown` i `defeated`.

### Hotkeye nie pojawiają się w CET

Sprawdź strukturę folderu i przeładuj mody w CET. Plik `init.lua` musi być bezpośrednio w folderze moda. Potem sprawdź `Waves.log` oraz konsolę CET pod kątem błędów ładowania Lua.

### Nadal istnieje stary plik logu

Starsze buildy pisały do `StaticShooters.log`. Aktualna wersja pisze do `Waves.log`. Stary plik można zignorować albo usunąć.

## Notatki developerskie

Lokalny folder developerski może nadal nazywać się `StaticShooters`, ale runtime'owa nazwa moda to `Waves`. Przy świeżej instalacji użyj folderu `Waves` w katalogu `mods` CET.

Domyślna gałąź repozytorium to `master`.
