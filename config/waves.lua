return function(CharacterTDBID)
    local function C(id)
        return CharacterTDBID(id)
    end

    local cautiousSearchMovementType = "Strafe"
    local cautiousSearchStepDistance = 3.0
    local alertSearchRadius = 12.0
    local alertSearchLeashDistance = 24.0
    local alertSearchStopDistance = 2.5
    local alertSearchAlwaysUseStealth = false
    local alertSearchStatusEffects = {
        "Senses.Alerted",
        "BaseStatusEffect.IgnoreWeaponSafe"
    }
    local stableHumanNavmeshCheckRadius = 1.0
    local skipEmptySpawnRetries = false

    local fallbackSpawnLines = {
        {
            edgeA = { x = -1253.4954, y = -70.098404, z = 7.7323914, w = 1 },
            edgeB = { x = -1250.2594, y = -78.46835, z = 7.7323837, w = 1 }
        },
        {
            edgeA = { x = -1243.8997, y = -72.81146, z = 7.7323914, w = 1 },
            edgeB = { x = -1241.8088, y = -78.84831, z = 7.7323914, w = 1 }
        },
        {
            edgeA = { x = -1238.3811, y = -84.537704, z = 7.7323837, w = 1 },
            edgeB = { x = -1238.1135, y = -78.18799, z = 7.7323914, w = 1 }
        },
        {
            edgeA = { x = -1244.1971, y = -104.90228, z = 7.7323914, w = 1 },
            edgeB = { x = -1241.8, y = -88.77179, z = 7.7323914, w = 1 }
        }
    }

    local optionGroups = {
        actLikeNinja = {
            holdUntilPlayerDistance = 4.0,
            passiveUntilPlayerDistance = true,
            passiveUntilPlayerAttitude = "neutral",
            holdPositionUntilPlayerDistance = true,
            holdPositionTolerance = 0.75,
            holdPositionRefreshInterval = 0.75,
            holdPositionMovementType = "Stand",
            holdPositionStopDistance = 0.25,
            silentUntilPlayerDistance = true,
            readyUntilPlayerDistance = true,
            quietReadyMode = "weaponOnly",
            lookAtPlayerUntilPlayerDistance = false,
            quietReadyRefreshInterval = 4.0,
            quietReadyStatusEffects = {
                "BaseStatusEffect.IgnoreWeaponSafe"
            },
            wakeQuietReady = false,
            suppressCombatBarks = true,
            quietWakeSuppressCombatThreat = true,
            quietWakeSuppressCombatPreset = true,
            forceMeleeAttackOnWake = true,
            despawnDefeatedNPCs = false,
            autoCombatDistance = 2.0,
            combatJoinDistance = 3.0,
            directChaseDistance = 3.0,
            disableAIMovement = true,
            disableDirectChase = true,
            forceMeleeAttack = true,
            alwaysSearchPlayer = false,
            searchAroundHomeOnly = false,
            searchPlayerRadius = 0.0,
            searchMovementType = cautiousSearchMovementType,
            searchStepDistance = 0.0,
            searchRadius = 0.0,
            searchLeashDistance = 0.0,
            searchStopDistance = 0.0,
            searchAlwaysUseStealth = false,
            searchAlertStatusEffects = {}
        },
        actLikeSamurai = {
            quietReadyStatusEffects = {
                "BaseStatusEffect.IgnoreWeaponSafe"
            },
            forceMeleeAttackOnWake = true,
            forceMeleeAttack = true,
            alwaysSearchPlayer = true,
            searchAroundHomeOnly = true,
            searchPlayerRadius = 10.0,
            searchMovementType = cautiousSearchMovementType,
            searchStepDistance = 2.0,
            searchRadius = 10.0,
            searchLeashDistance = 10.0,
            searchStopDistance = 10.0,
            searchAlwaysUseStealth = true,
            searchAlertStatusEffects = {}
        }
    }

    local playerKatanaOnly = {
        type = "katanaOnly",
        katanaItem = "Items.Preset_Katana_Wakako",
        blockQuickhacks = true,
        quickhackImmunityStat = "QuickHackImmunity",
        requireKatanaHitForDefeat = true,
        violationAction = "restartWave",
        startMessage = "Katana only for this contract. Quickhacks are blocked.",
        warningMessage = "Katana only for this contract. Quickhacks are blocked.",
        violationMessage = "Katana only. Restarting wave."
    }

    local function applyOptionGroup(wave, group)
        if type(group) == "string" then
            group = optionGroups[group]
        end

        if type(group) ~= "table" then
            return
        end

        for key, value in pairs(group) do
            if wave[key] == nil then
                wave[key] = value
            end
        end
    end

    local function applyOptionGroups(wave)
        if type(wave.optionGroups) ~= "table" then
            return
        end

        for _, group in ipairs(wave.optionGroups) do
            applyOptionGroup(wave, group)
        end
    end

    local function trim(text)
        local trimmed = string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
        return trimmed
    end

    local function stripWaveNumberPrefix(name)
        local title = trim(name)
        local stripped = string.match(title, "^[Ww][Aa][Vv][Ee]%s+%d+%s*%-%s*(.+)$")

        if stripped and stripped ~= "" then
            return trim(stripped)
        end

        stripped = string.match(title, "^[Ww][Aa][Vv][Ee]%s+%d+%s+(.+)$")

        if stripped and stripped ~= "" then
            return trim(stripped)
        end

        return title
    end

    local function makeWaveName(index, title)
        title = trim(title)

        if title == "" then
            return "Wave " .. tostring(index)
        end

        return "Wave " .. tostring(index) .. " - " .. title
    end

    local function expandWaveText(text, wave)
        if type(text) ~= "string" then
            return text
        end

        local values = {
            club = wave.club or "",
            name = wave.name or "",
            title = wave.title or ""
        }

        return string.gsub(text, "{([%w_]+)}", function(key)
            if values[key] ~= nil then
                return tostring(values[key])
            end

            return "{" .. tostring(key) .. "}"
        end)
    end

    local function prepareWave(wave, waveIndex)
        applyOptionGroups(wave)

        local title = stripWaveNumberPrefix(wave.name)
        if title == "" then
            title = stripWaveNumberPrefix(wave.club)
        end

        wave.title = title
        wave.name = makeWaveName(waveIndex, title)
        wave.startMessage = expandWaveText(wave.startMessage, wave)

        if wave.spawnPoints and #wave.spawnPoints > 0 then
            if not wave.count then
                wave.count = #wave.spawnPoints
            end

            if not wave.markerPos then
                wave.markerPos = wave.spawnPoints[1]
            end
        end

        return wave
    end

    local waves = {
        {
            name = "The Choppers Club",
            club = "CHOPPERS CLUB",
            count = 20,
            npcs = {
                C("valentinos_machete_hmelee3_machete_mb_elite"),
                C("rey_valentinos_machete_hmelee3_machete_mb_elite"),
                C("gle_valentinos_machete_hmelee3_machete_mb_elite"),
                C("maelstrom_fast_fmelee2_machete_ma_rare"),
                C("hil_maelstrom_fast_fmelee2_machete_ma_rare"),
                C("dtn_generic_fast_fmelee2_machete_ma_rare"),
                C("valentinos_machete_hmelee3_machete_mb_elite"),
                C("maelstrom_fast_fmelee2_machete_ma_rare"),
                --C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa"),
                --C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare"),
                --C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa_arr_11"),
                --C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare_arr_11"),
                --C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa_rcr_03"),
                --C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare_rcr_03"),
                --C("lch_animals_bouncer1_melee1_baton_mb")
            },
            fallbackNpc = C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa"),
            markerPos = { x = -1320.4529, y = -70.17114, z = 24.181656, w = 1 },
            spawnLine = {
                edgeA = { x = -1320.4529, y = -70.17114, z = 24.181656, w = 1 },
                edgeB = { x = -1325.9106, y = -46.9088, z = 24.181656, w = 1 }
            },
            -- minSpawnDistance = 40.0,
            lockSpawnPosition = true,
            spawnLineRows = 2,
            spawnLineRowSpacing = 1.1,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            humanNavmeshRequired = false,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 10000 },
            disableDirectChase = true,
            -- pushSpawnAway = true,
            alwaysSearchPlayer = true,
            searchAroundHomeOnly = true,
            searchMovementType = cautiousSearchMovementType,
            searchStepDistance = cautiousSearchStepDistance,
            searchRadius = alertSearchRadius,
            searchLeashDistance = alertSearchLeashDistance,
            searchStopDistance = alertSearchStopDistance,
            searchAlwaysUseStealth = alertSearchAlwaysUseStealth,
            searchAlertStatusEffects = alertSearchStatusEffects,
            disablePostSpawnCorrection = true,
            startMessage = "Members of {club} are after you!",
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        }, -- choppers
        {
            name = "Hatchet Club",
            club = "HATCHET CLUB",
            startMessage = "{club}: STAY OUT OF ARM'S REACH.",
            count = 20,
            npcs = {
                C("valentinos_machete_hmelee3_machete_mb_elite"),
                C("rey_valentinos_machete_hmelee3_machete_mb_elite"),
                C("gle_valentinos_machete_hmelee3_machete_mb_elite"),
                C("maelstrom_fast_fmelee2_machete_ma_rare"),
                C("hil_maelstrom_fast_fmelee2_machete_ma_rare"),
                C("dtn_generic_fast_fmelee2_machete_ma_rare")
            },
            npcWeaponPool = {
                "Items.Preset_Tomahawk_Default",
                "Items.Preset_Fanged_Axe_Default",
                "Items.Preset_Fanged_Axe_Neon",
                "Items.Preset_Fanged_Axe_Military"
            },
            markerPos = { x = 145.41028, y = 1056.0579, z = 203, w = 1 },
            spawnLine = {
                edgeA = { x = 147.142, y = 1051.0625, z = 203, w = 1 },
                edgeB = { x = 143.67856, y = 1061.0533, z = 203, w = 1 }
            },
            spawnLineRows = 4,
            spawnLineRowSpacing = 1.35,
            minSpawnDistance = 35.0,
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 12500 },
            alwaysSearchPlayer = false,
            searchAroundHomeOnly = true,
            searchPlayerRadius = 8.0,
            searchMovementType = cautiousSearchMovementType,
            searchStepDistance = cautiousSearchStepDistance,
            searchRadius = alertSearchRadius,
            searchLeashDistance = alertSearchLeashDistance,
            searchStopDistance = alertSearchStopDistance,
            searchAlwaysUseStealth = alertSearchAlwaysUseStealth,
            searchAlertStatusEffects = alertSearchStatusEffects,
            directChaseDistance = 6.0,
            pushSpawnAway = false,
            disablePostSpawnCorrection = true,
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        }, -- hatchets
        {
            name = "Blacksmiths Club",
            club = "BLACKSMITHS CLUB",
            startMessage = "Lookout! Meatheads are preparing an ambush.",
            count = 8,
            npcs = {
                C("animals_bouncer2_hmelee2_hammer_mba_rare"),
                C("animals_elite2_hmelee2_hammer_mba_rare"),
                C("animals_grunt2_hmelee2_hammer_wba_rare"),
                C("animals_grunt2_melee2_hammer_mb"),
                C("lch_animals_elite2_hmelee2_hammer_mba_rare")
            },
            spawnPoints = {
                --{ x = -1435.4368, y = 1302.5973, z = 27.074898, w = 1 }, -- przed windą
                --{ x = -1419.4817, y = 1292.4565, z = 27.082397, w = 1 },
                --{ x = -1452.3234, y = 1313.317, z = 119.0824, w = 1 }, -- sklep z bronią
                --{ x = -1400.0416, y = 1268.4159, z = 119.064896, w = 1 },
                --{ x = -1389.5636, y = 1283.7878, z = 123.0824, w = 1 }, -- obok mieszkania
                { x = -1450.1914, y = 1276.2333, z = 23.096855, w = 1 }, -- na zewnątrz
                { x = -1426.5479, y = 1273.4276, z = 25.090004, w = 1 }, -- na schodach
                { x = -1437.2012, y = 1253.9418, z = 23.082176, w = 1 }, -- za barkiem
                { x = -1433.2853, y = 1266.7559, z = 23.090004, w = 1 }, -- przed schodami
                { x = -1420.7039, y = 1266.945, z = 23.070534, w = 1 }, -- przy automatach
                { x = -1403.2646, y = 1275.1786, z = 23.071297, w = 1 }, -- za rogiem
                { x = -1369.2368, y = 1257.5903, z = 24.02887, w = 1 }, -- przy parkingu
                { x = -1450.492, y = 1286.0475, z = 23.096848, w = 1 } -- po drugiej stronie schodów

            },
            --spawnLine = {
            --    edgeA = { x = -1434.6975, y = 1261.6774, z = 23.071434, w = 1 },
            --    edgeB = { x = -1422.3112, y = 1263.5642, z = 23.077179, w = 1 }
            --},
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 15000 },
            disableDirectChase = true,
            alwaysSearchPlayer = true,
            searchAroundHomeOnly = true,
            searchMovementType = cautiousSearchMovementType,
            searchStepDistance = cautiousSearchStepDistance,
            searchRadius = alertSearchRadius,
            searchLeashDistance = alertSearchLeashDistance,
            searchStopDistance = alertSearchStopDistance,
            searchAlwaysUseStealth = alertSearchAlwaysUseStealth,
            searchAlertStatusEffects = alertSearchStatusEffects,
            disablePostSpawnCorrection = true,
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        }, -- meatheads
        {
            name = "Ninjitsu Club",
            club = "NINJITSU CLUB",
            count = 8,
            startMessage = "{club}: COME TO US, IF YOU DARE.",
            npcs = {
                C("arasaka_2020agent_fmelee2_katana_ma"),
                C("arasaka_2020agent_fmelee2_katana_wa"),
                C("arasaka_agent_fmelee2rare_katana_ma_rare"),
                C("arasaka_agent_fmelee2rare_katana_wa_rare"),
                C("dtn_tyger_claws_martial_fmelee2_katana_ma_rare"),
                C("dtn_tyger_claws_martial_fmelee2_katana_ma_rare"),
                C("dtn_tyger_claws_martial_fmelee2_katana_ma_rare"),
                C("dtn_tyger_claws_martial_fmelee2_katana_ma_rare")
            },
            spawnPoints = {
                { x = -893.37787, y = 1772.0991, z = 3.3923721, w = 1 },
                { x = -908.2976, y = 1734.8834, z = 1.4421616, w = 1 },
                { x = -874.4286, y = 1759.1345, z = 1.1237488, w = 1 },
                { x = -926.05927, y = 1748.5254, z = 6.601837, w = 1 },
                { x = -919.0075, y = 1730.9241, z = 1.1283951, w = 1 },
                { x = -937.006, y = 1718.437, z = 1.392868, w = 1 },
                { x = -924.77893, y = 1718.5557, z = 1.4983597, w = 1 },
                { x = -926.73755, y = 1708.9559, z = 1.0862045, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 17500 },
            optionGroups = { "actLikeNinja" },
            holdUntilPlayerDistance = 3.0,
            disablePostSpawnCorrection = true,
            playerWeaponRule = playerKatanaOnly,
        }, -- ninjitsu
        {
            name = "Samurais Club",
            club = "SAMURAIS CLUB",
            count = 9,
            startMessage = "{club}: THE BLADE KNOWS NO FEAR, DO YOU, V?",
            npcs = {
                C("dtn_tyger_claws_martial_fmelee2_katana_ma_rare"),
            },
            spawnPoints = {
                { x = -1102.7472, y = 1360.4847, z = 6.0660477, w = 1 },
                { x = -1103.1733, y = 1383.4355, z = 5.8303986, w = 1 },
                { x = -1109.3539, y = 1401.062, z = 5.4873886, w = 1 },
                { x = -1099.8566, y = 1406.1658, z = 5.4361115, w = 1 }
            },
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 20000 },
            optionGroups = { "actLikeSamurai" },
            disablePostSpawnCorrection = true,
            playerWeaponRule = playerKatanaOnly,
        }, -- samurais
        {
            name = "MaxTac Triad",
            club = "MAXTAC TRIAD",
            count = 3,
            startMessage = "{club}: STAND STILL. IT WILL BE OVER FASTER.",
            npcs = {
                C("maxtac_melee_ma_elite"),
                C("maxtac_av_mantis_wa_2nd_wave"),
            },
            spawnPoints = {
                { x = -879.2412, y = 1447.5039, z = 5.8099976, w = 1 },
                { x = -837.3224, y = 1463.671, z = 5.8099976, w = 1 },
                { x = -830.7426, y = 1430.34, z = 5.8099976, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 45000 },
            optionGroups = { "actLikeNinja" },
            holdUntilPlayerDistance = 4.0,
            disablePostSpawnCorrection = true,
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        }, -- MaxTac Triad
        {
            name = "Arasaka Four Blades",
            club = "ARASAKA FOUR BLADES",
            count = 4,
            startMessage = "{club}: KNEEL, V. THE FOUR BLADES ARRIVED.",
            npcs = {
                C("arasaka_ninja_fmelee3_mantis_ma_elite"),
                C("arasaka_ninja_fmelee3_mantis_ma_elite"),
                C("arasaka_2020agent_fmelee2_katana_ma"),
                C("arasaka_2020agent_fmelee2_katana_wa")
            },
            spawnPoints = {
                { x = -2001.0929, y = -1136.2089, z = 10.675056, w = 1 },
                { x = -2005.1034, y = -1190.5255, z = 10.629303, w = 1 },
                { x = -2024.1633, y = -1124.6962, z = 10.675056, w = 1 },
                { x = -2045.2645, y = -1140.9893, z = 21.053452, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 22500 },
            optionGroups = { "actLikeNinja" },
            holdUntilPlayerDistance = 5.0,
            disablePostSpawnCorrection = true,
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        }, -- Arasaka Four Blades
        {
            name = "2 + 1",
            club = "2 + 1",
            count = 3,
            startMessage = "{club}: CYBERPSYCHO PROTOCOL NOW APPLIES TO YOU, V.",
            npcs = {
                C("Cyberninja_Oda"),
                C("main_boss_oda"),
                C("rcr_05_cyberpsycho") -- babka z żyletą
            },
            spawnPoints = {
                --{ x = -2224.8757, y = -1019.25134, z = 40.574234, w = 1 }, -- balkonik
                { x = -2215.1501, y = -993.78656, z = 40.100006, w = 1 }, -- krawędź
                { x = -2215.864, y = -986.3336, z = 40.100006, w = 1 },
                { x = -2215.2727, y = -972.36444, z = 40.100006, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 25000 },
            --optionGroups = { "actLikeNinja" },
            holdUntilPlayerDistance = 5.0,
            disablePostSpawnCorrection = true,
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        }, -- 2 + 1
        {
            name = "new",
            club = "new",
            count = 1,
            startMessage = "{club}: CYBERPSYCHO PROTOCOL NOW APPLIES TO YOU, V.",
            npcs = {
                C("ma_std_rcr_11_cyberpsycho")
            },
            spawnPoints = {
                { x = 92.33603, y = -64.45105, z = 7.0258713, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 22500 },
            --optionGroups = { "actLikeNinja" },
            holdUntilPlayerDistance = 15.0,
            disablePostSpawnCorrection = true,
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        },
    }

--     x = 2564.4065, y = -36.28605, z = 80.81503, w = 1 } -- bar przy rocky ridge, badlands
    -- { x = 5138.684, y = -616.8569, z = 144.49898, w = 1 } -- wiatraki na badlandach
    -- { x = 473.20978, y = 1310.459, z = 230.65866, w = 1 } -- posiadłość arasaki
    -- { x = -1507.7677, y = 3073.6348, z = 20.124496, w = 1 } -- kontenerowiec maelstrom w dokach
    -- { x = -1536.8926, y = 2510.5671, z = 7.1184006, w = 1 } -- miejsce rytuału
    -- { x = -2200.7207, y = 2026.8107, z = 18, w = 1 } -- pod bud arasaki w Watson
    -- { x = -1658.9292, y = 2026.5867, z = 18.128922, w = 1 } - fabryka tigersów, watson
    -- { x = -1538.4487, y = 1197.2526, z = 57.000008, w = 1 } -- dach obok Viktora
    -- { x = -1545.5684, y = 1269.5448, z = 31.0672, w = 1 } - niższy dach obok Viktora
    -- { x = 438.26346, y = -1658.2573, z = 9.433899, w = 1 } -- pod młyńkim kołem, Santo Domingo
    -- { x = 328.19818, y = -1628.1072, z = 9.2966, w = 1 } -- restauracja, Santo Domingo
    -- { x = 626.80676, y = -2208.5515, z = 42.735657, w = 1 } -- dach przy petrochemie, santo domingo
    -- { x = -634.9795, y = 928.32837, z = 24.019714, w = 1 } -- między stopami posągu, jig jig street, kabuki
    -- { x = -689.55, y = 919.65173, z = 11.400002, w = 1 } -- kagami market, jig jig
    -- { x = -1178.0944, y = 335.4732, z = 4.68412, w = 1 } -- centrum, teren pod neonami
    -- { x = -1373.2892, y = -85.60083, z = 37.16487, w = 1 } -- alejka pod rybami, centrum
    -- { x = -1319.163, y = 164.07602, z = 6.868477, w = 1 } -- behavioral health center, centrum
    -- { x = -1945.6273, y = -2395.3657, z = 36.31846, w = 1 } -- dogtown, koło bramy
    -- { x = -2748.892, y = -1841.1753, z = 0.34627533, w = 1 } -- mini plaża przy dabelskim młynie, pacifica
    -- { x = -2563.2622, y = -2348.3555, z = 12.590836, w = 1 } -- dach przy diabelskim młynie, pacifica
    -- { x = -1186.0554, y = 1775.9146, z = 27.481201, w = 1 } -- mieszkanie w kennedy north, kabuki
    -- { x = -1179.5623, y = 1738.3096, z = 19.388016, w = 1 } -- piwnica w mieszkaniu obok, kabuki
    -- { x = -1163.3229, y = 1741.2615, z = 23.37053, w = 1 } -- garaż obok piwnicy
-- { x = -1185.7792, y = 1762.3317, z = 23.37053, w = 1 } -- lryjówka pod schodami kawałek dalej
     -- { x = -1198.2233, y = 1765.8457, z = 35.441467, w = 1 } -- dach obok balkonu, kabuki
    -- { x = -1093.0969, y = 1604.2952, z = 0.1482315, w = 1 } -- na przeciwko pierogarni
    -- { x = -1115.9191, y = 1761.162, z = 10.82708, w = 1 } -- kanał obok tańczącego robota, kabuki
    -- { x = -807.7446, y = 1819.858, z = 25.359825, w = 1 } -- przy spływie kanału, kabuki
    -- { x = -825.9462, y = 1972.3687, z = 52.261734, w = 1 } -- uszkodzona droga kabuki
    -- { x = -92.58072, y = 1942.8658, z = 100.632, w = 1 } -- kino samochodowe
    -- { x = -2700.9246, y = -1681.6901, z = -26.740189, w = 1 } -- tunel pod wodą, pacifika
    -- { x = -807.7224, y = -1811.4795, z = 8.387482, w = 1 } -- pod wiaduktem, santo domingo
    -- { x = -270.12485, y = -1393.4128, z = 8.6315155, w = 1 } - magazyn arasaki, przy głowie wilka, santo d.
    -- { x = -852.04614, y = -508.6143, z = 39.527367, w = 1 } -- na neonowym dachu kolejki, center
    -- { x = -1294.3577, y = -404.96692, z = 7.4085693, w = 1 } -- między blokami, wejście przez ogrodzenie 2 pasmówki, przy memorial park, center
    -- { x = -1514.1046, y = -413.1055, z = 7.4085693, w = 1 } -- przy przebranych glinach, przy memorial park, center






    for waveIndex, wave in ipairs(waves) do
        prepareWave(wave, waveIndex)
    end

    return {
        waves = waves,
        startMarkerPos = waves[1] and waves[1].markerPos or nil,
        spawnLines = fallbackSpawnLines
    }
end
