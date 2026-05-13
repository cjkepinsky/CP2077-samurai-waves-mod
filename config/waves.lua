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

        if type(group) ~= "table" then return end

        for key, value in pairs(group) do
            if wave[key] == nil then
                wave[key] = value
            end
        end
    end

    local function applyOptionGroups(wave)
        if type(wave.optionGroups) ~= "table" then return end

        for _, group in ipairs(wave.optionGroups) do
            applyOptionGroup(wave, group)
        end
    end

    local function prepareWave(wave)
        applyOptionGroups(wave)

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
            name = "Wave 1 - Crickets Club",
            club = "CRICKETS CLUB",
            count = 20,
            npcs = {
                C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa"),
                C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare"),
                C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa_arr_11"),
                C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare_arr_11"),
                C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa_rcr_03"),
                C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare_rcr_03"),
                C("lch_animals_bouncer1_melee1_baton_mb")
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
            startMessage = "Members of Crickets Club are after you!",
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        },
        {
            name = "Wave 2 - Baseballs Club",
            club = "BASEBALLS CLUB",
            count = 20,
            npcs = {
                C("lch_animals_grunt1_melee1_baseball_mb"),
                C("ma_wbr_jpn_07_scavenger_baseball_ma"),
                C("nid_03_tyger_claws_biker1_melee1_baseball_ma"),
                C("nid_tyger_claws_biker1_melee1_baseball_ma"),
                C("rcr_sixthstreet_patrol2_melee2_baseball_wa"),
                C("rey_valentinos_grunt1_melee1_baseball_ma"),
                C("scavenger_grunt2_melee2_baseball_ma")
            },
            markerPos = { x = 145.41028, y = 1056.0579, z = 203, w = 1 },
            spawnLine = {
                edgeA = { x = 147.142, y = 1051.0625, z = 203, w = 1 },
                edgeB = { x = 143.67856, y = 1061.0533, z = 203, w = 1 }
            },
            extraSpawnPoint = { x = 126.34494, y = 1102.2173, z = 203.0058, w = 1 },
            extraSpawnFromIndex = 6,
            minSpawnDistance = 35.0,
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 12500 },
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
            pushSpawnAway = true,
            disablePostSpawnCorrection = true,
            startMessage = "THE BAT BOYS ARE COMING",
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        },
        {
            name = "Wave 3 - Blacksmiths Club",
            club = "BLACKSMITHS CLUB",
            count = 6,
            npcs = {
                C("animals_bouncer2_hmelee2_hammer_mba_rare"),
                C("animals_elite2_hmelee2_hammer_mba_rare"),
                C("animals_grunt2_hmelee2_hammer_wba_rare"),
                C("animals_grunt2_melee2_hammer_mb"),
                C("arasaka_sumo_hmelee2_hammer_mb_rare"),
                C("lch_animals_elite2_hmelee2_hammer_mba_rare")
            },
            spawnPoints = {
                { x = -1435.4368, y = 1302.5973, z = 27.074898, w = 1 }, -- przed windą
                { x = -1419.4817, y = 1292.4565, z = 27.082397, w = 1 },
                { x = -1452.3234, y = 1313.317, z = 119.0824, w = 1 }, -- sklep z bronią
                { x = -1400.0416, y = 1268.4159, z = 119.064896, w = 1 },
                { x = -1389.5636, y = 1283.7878, z = 123.0824, w = 1 }, -- obok mieszkania
                { x = -1450.1914, y = 1276.2333, z = 23.096855, w = 1 } -- na zewnątrz

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
            startMessage = "Lookout! Meatheads are preparing an ambush.",
            forceMeleeAttack = true,
            playerWeaponRule = playerKatanaOnly,
        },
        {
            name = "Wave 4 - Cowboys Club",
            club = "COWBOYS CLUB",
            count = 20,
            npcs = {
                C("valentinos_grunt2_ranged2_overture_ma"),
                C("valentinos_grunt2_ranged2_overture_wa"),
                C("wraiths_warrior3_ranged3_quasar_wa_rare"),
                C("animals_elite2_ranged3_burya_mba_rare")
            },
            fallbackNpc = C("valentinos_grunt2_ranged2_overture_ma"),
            spawnLine = {
                edgeA = { x = -1774.4138, y = -526.65784, z = 10.144997, w = 1 },
                edgeB = { x = -1760.3121, y = -510.6125, z = 10.144997, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 17500 },
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
            startMessage = "Few Cowboys Club members are angry at you!"
        },
        {
            name = "Wave 5 - Power People Club",
            club = "POWER PEOPLE CLUB",
            count = 20,
            npcs = {
                C("arasaka_agent_fshotgun2_tactician_ma_rare"),
                C("maelstom_strong_shotgun2_carnage_ma_rare"),
                C("arasaka_agent_fshotgun2_tactician_ma_rare"),
                C("maelstom_strong_shotgun2_carnage_ma_rare"),
                C("maelstom_strong_shotgun2_carnage_ma_rare")
            },
            fallbackNpc = C("maelstom_strong_shotgun2_carnage_ma_rare"),
            spawnLine = {
                -- edgeA = { x = -2261.3809, y = -2569.421, z = 25.301064, w = 1 },
                -- edgeB = { x = -2238.669, y = -2575.5227, z = 25.30812, w = 1 }
                edgeA = { x = -1896.2085, y = -2646.9531, z = 39.773796, w = 1 },
                edgeB = { x = -1897.711, y = -2638.749, z = 39.53881, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 20000 },
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
            startMessage = "Wake up! Power People Club members got enough ammo to shoot you."
        },
        {
            name = "Wave 6 - Hunters Club",
            club = "HUNTERS CLUB",
            count = 20,
            npcs = {
                C("cpz_maelstrom_grunt1_ranged1_lexington_wa")
            },
            spawnLine = {
                edgeA = { x = -1078.7885, y = -1528.4915, z = 25.779922, w = 1 },
                edgeB = { x = -1102.7998, y = -1514.9469, z = 25.779922, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 22500 },
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
            startMessage = "Hunters Club: Hunting season has begun, and you are the prey."
        },
        {
            name = "Wave 7 - Smart Hunters Club",
            club = "SMART HUNTERS CLUB",
            count = 14,
            npcs = {
                C("jpn_tyger_claws_gangster3_ranged3_sidewinder_ma"),
                C("kab_tyger_claws_gangster3_ranged3_sidewinder_ma"),
                C("ma_corpo_Sidewinder_Auto_Smart_Rifle_Base"),
                C("ma_gang_Sidewinder_Auto_Smart_Rifle_Base"),
                C("ma_gang_Chao_Burst_Smart_Handgun_Base")
            },
            fallbackNpc = C("jpn_tyger_claws_gangster3_ranged3_sidewinder_ma"),
            spawnLine = {
                edgeA = { x = -1612.4158, y = -1220.4342, z = 24.694534, w = 1 },
                edgeB = { x = -1603.7832, y = -1209.8744, z = 24.805511, w = 1 }
            },
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 25000 },
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
            startMessage = "These Hunters are smarter, in some way."
        },
        {
            name = "Wave 8 - Ninjitsu Club",
            club = "SAMURAIS CLUB",
            count = 8,
            startMessage = "NINJITSU CLUB: COME TO US, IF YOU DARE.",
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
            treasure = { rewardMoney = 30000 },
            optionGroups = { "actLikeNinja" },
            holdUntilPlayerDistance = 3.0,
            disablePostSpawnCorrection = true,
            playerWeaponRule = {
                type = "katanaOnly",
                katanaItem = "Items.Preset_Katana_Wakako",
                blockQuickhacks = true,
                quickhackImmunityStat = "QuickHackImmunity",
                requireKatanaHitForDefeat = true,
                violationAction = "restartWave",
                startMessage = "Katana only for this contract. Quickhacks are blocked.",
                warningMessage = "Katana only for this contract. Quickhacks are blocked.",
                violationMessage = "Katana only. Restarting wave."
            },
        },
        {
            name = "Wave 9 - Samurais Club",
            club = "SAMURAIS CLUB",
            count = 9,
            startMessage = "SAMURAIS CLUB: THE BLADE KNOWS NO FEAR, DO YOU, V?",
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
            treasure = { rewardMoney = 32500 },
             optionGroups = { "actLikeSamurai" },
            disablePostSpawnCorrection = true,
            playerWeaponRule = playerKatanaOnly,
        }
    }

    for _, wave in ipairs(waves) do
        prepareWave(wave)
    end

    return {
        waves = waves,
        startMarkerPos = waves[1] and waves[1].markerPos or nil,
        spawnLines = fallbackSpawnLines
    }
end
