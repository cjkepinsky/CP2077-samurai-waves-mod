return function(CharacterTDBID)
    local function C(id)
        return CharacterTDBID(id)
    end

    local npcs = {
        crickets = {
            C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa"),
            C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare"),
            C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa_arr_11"),
            C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare_arr_11"),
            C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa_rcr_03"),
            C("gang_retaliation_enemies_sixthstreet_menace1_fmelee2_baton_wa_rare_rcr_03"),
            C("lch_animals_bouncer1_melee1_baton_mb")
        },

        baseballs = {
            C("lch_animals_grunt1_melee1_baseball_mb"),
            C("ma_wbr_jpn_07_scavenger_baseball_ma"),
            C("nid_03_tyger_claws_biker1_melee1_baseball_ma"),
            C("nid_tyger_claws_biker1_melee1_baseball_ma"),
            C("rcr_sixthstreet_patrol2_melee2_baseball_wa"),
            C("rey_valentinos_grunt1_melee1_baseball_ma"),
            C("scavenger_grunt2_melee2_baseball_ma")
        },

        blacksmiths = {
            C("animals_bouncer2_hmelee2_hammer_mba_rare"),
            C("animals_elite2_hmelee2_hammer_mba_rare"),
            C("animals_grunt2_hmelee2_hammer_wba_rare"),
            C("animals_grunt2_melee2_hammer_mb"),
            C("arasaka_sumo_hmelee2_hammer_mb_rare"),
            C("lch_animals_elite2_hmelee2_hammer_mba_rare")
        },

        cowboys = {
            C("valentinos_grunt2_ranged2_overture_ma"),
            C("valentinos_grunt2_ranged2_overture_wa"),
            C("wraiths_warrior3_ranged3_quasar_wa_rare"),
            C("animals_elite2_ranged3_burya_mba_rare")
        },

        powerPeople = {
            C("arasaka_agent_fshotgun2_tactician_ma_rare"),
            C("maelstom_strong_shotgun2_carnage_ma_rare"),
            C("arasaka_agent_fshotgun2_tactician_ma_rare"),
            C("maelstom_strong_shotgun2_carnage_ma_rare"),
            C("maelstom_strong_shotgun2_carnage_ma_rare")
        },

        hunters = {
            C("cpz_maelstrom_grunt1_ranged1_lexington_wa")
        },

        smartHunters = {
            C("jpn_tyger_claws_gangster3_ranged3_sidewinder_ma"),
            C("kab_tyger_claws_gangster3_ranged3_sidewinder_ma"),
            C("ma_corpo_Sidewinder_Auto_Smart_Rifle_Base"),
            C("ma_gang_Sidewinder_Auto_Smart_Rifle_Base"),
            C("ma_gang_Chao_Burst_Smart_Handgun_Base")
        },

        samurais = {
            C("afterlife_rare_fmelee3_katana_wa_elite"),
            C("arasaka_2020agent_fmelee2_katana_ma"),
            C("arasaka_2020agent_fmelee2_katana_wa"),
            C("arasaka_agent_fmelee2rare_katana_ma_rare"),
            C("arasaka_agent_fmelee2rare_katana_wa_rare"),
            C("bls_se_security_blackmasked3_fmelee3_katana_mb_elite"),
            C("dtn_security_blackmasked3_fmelee3_katana_mb_elite"),
            C("dtn_tyger_claws_martial_fmelee2_katana_ma_rare")
        }
    }

    local spawnLines = {
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

    local locations = {
        start = { x = -1320.4529, y = -70.17114, z = 24.181656, w = 1 },

        cricketsLine = {
            edgeA = { x = -1320.4529, y = -70.17114, z = 24.181656, w = 1 },
            edgeB = {  x = -1325.9106, y = -46.9088, z = 24.181656, w = 1 }
        },

        baseballsLine = {
            edgeA = { x = 147.142, y = 1051.0625, z = 203, w = 1 },
            edgeB = { x = 143.67856, y = 1061.0533, z = 203, w = 1 }
        },

        baseballsMarker = {
            x = 145.41028, y = 1056.0579, z = 203, w = 1
        },

        baseballsExtraPoint = {
            x = 126.34494, y = 1102.2173, z = 203.0058, w = 1
        },

        blacksmithsPoints = {
            { x = -1438.8439, y = 1273.345, z = 22.853622, w = 1 },
            { x = -1438.6404, y = 1253.7946, z = 23.076706, w = 1 },
            { x = -1421.7432, y = 1269.845, z = 23.070534, w = 1 },
            { x = -1406.8617, y = 1267.2096, z = 23.071297, w = 1 },
            { x = -1415.0918, y = 1246.7423, z = 23.070526, w = 1 },
            { x = -1424.6438, y = 1236.9045, z = 23.070496, w = 1 },
            { x = -1444.5741, y = 1222.8276, z = 23.060959, w = 1 },
            { x = -1431.5874, y = 1281.905, z = 27.082397, w = 1 },
            { x = -1424.626, y = 1279.3002, z = 27.074898, w = 1 },
            { x = -1428.5059, y = 1263.4852, z = 23.102287, w = 1 }
        },

        blacksmithsLine = {
            edgeA = { x = -1434.6975, y = 1261.6774, z = 23.071434, w = 1 },
            edgeB = { x = -1422.3112, y = 1263.5642, z = 23.077179, w = 1 }
        },

        cowboysLine = {
            edgeA = { x = -1774.4138, y = -526.65784, z = 10.144997, w = 1 },
            edgeB = { x = -1760.3121, y = -510.6125, z = 10.144997, w = 1 }
        },

        powerPeopleLine = {
--            edgeA = { x = -2261.3809, y = -2569.421, z = 25.301064, w = 1 },
--            edgeB = { x = -2238.669, y = -2575.5227, z = 25.30812, w = 1 }
            edgeA = { x = -1896.2085, y = -2646.9531, z = 39.773796, w = 1 },
            edgeB = {  x = -1897.711, y = -2638.749, z = 39.53881, w = 1 }
        },

        huntersPoints = {
            { x = -1091.0159, y = -1533.174, z = 30.596428, w = 1 },
            { x = -1105.5188, y = -1522.3916, z = 30.619904, w = 1 },
            { x = -1083.9703, y = -1498.1985, z = 35.07171, w = 1 },
            { x = -1071.7524, y = -1502.3453, z = 34.914818, w = 1 },
            { x = -1067.577, y = -1517.5997, z = 30.624245, w = 1 },
            { x = -1078.0283, y = -1531.6683, z = 30.624245, w = 1 },
            { x = -1065.177, y = -1520.6396, z = 34.77558, w = 1 },
            { x = -1082.5176, y = -1529.0112, z = 25.779922, w = 1 },
            { x = -1093.4764, y = -1504.4086, z = 25.779922, w = 1 },
            { x = -1069.0255, y = -1531.496, z = 25.779922, w = 1 }
        },

        huntersLine = {
            edgeA = { x = -1078.7885, y = -1528.4915, z = 25.779922, w = 1 },
            edgeB = { x = -1102.7998, y = -1514.9469, z = 25.779922, w = 1 }
        },

        smartHuntersPoints = {
            { x = -1569.9152, y = -1240.6104, z = 22, w = 1 },
            { x = -1551.5332, y = -1242.1003, z = 22.017448, w = 1 },
            { x = -1553.3634, y = -1234.7864, z = 22, w = 1 },
            { x = -1527.5874, y = -1219.8052, z = 16.793358, w = 1 },
            { x = -1514.9019, y = -1187.7734, z = 16.975014, w = 1 }
        },

        smartHuntersLine = {
            edgeA = { x = -1612.4158, y = -1220.4342, z = 24.694534, w = 1 },
            edgeB = { x = -1603.7832, y = -1209.8744, z = 24.805511, w = 1 }
        },

        samuraisPoints = {
            { x = -1085.0393, y = 1460.5868, z = 16.481453, w = 1 },
            { x = -1082.1028, y = 1449.2957, z = 19.75061, w = 1 },
            { x = -1102.3271, y = 1451.5339, z = 16.613518, w = 1 },
            { x = -1106.2848, y = 1437.279, z = 16.613518, w = 1 },
            { x = -1086.4799, y = 1407.0422, z = 21.7723, w = 1 },
            { x = -1093.1615, y = 1427.4495, z = 16.652817, w = 1 },
            { x = -1109.3002, y = 1443.4929, z = 16.355042, w = 1 },
            { x = -1109.0562, y = 1447.8878, z = 16.642517, w = 1 }
        },

        samuraisLine = {
            edgeA = { x = -1057.466, y = 1199.5851, z = 0.19934082, w = 1 },
            edgeB = { x = -1041.7489, y = 1210.875, z = 0.286911, w = 1 }
        }
    }

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

    local waves = {
        {
            name = "Wave 1 - Crickets Club",
            club = "CRICKETS CLUB",
            count = 20,
            npcs = npcs.crickets,
            fallbackNpc = C("gang_retaliation_enemies_sixthstreet_melee2_baton_wa"),
            markerPos = locations.start,
            spawnLine = locations.cricketsLine,
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
            forceMeleeAttack = true
        },
        {
            name = "Wave 2 - Baseballs Club",
            club = "BASEBALLS CLUB",
            count = 20,
            npcs = npcs.baseballs,
            markerPos = locations.baseballsMarker,
            spawnLine = locations.baseballsLine,
            extraSpawnPoint = locations.baseballsExtraPoint,
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
            forceMeleeAttack = true
        },
        {
            name = "Wave 3 - Blacksmiths Club",
            club = "BLACKSMITHS CLUB",
            count = 15,
            npcs = npcs.blacksmiths,
            spawnLine = locations.blacksmithsLine,
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
            forceMeleeAttack = true
        },
        {
            name = "Wave 4 - Cowboys Club",
            club = "COWBOYS CLUB",
            count = 20,
            npcs = npcs.cowboys,
            fallbackNpc = C("valentinos_grunt2_ranged2_overture_ma"),
            spawnLine = locations.cowboysLine,
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
            npcs = npcs.powerPeople,
            fallbackNpc = C("maelstom_strong_shotgun2_carnage_ma_rare"),
            spawnLine = locations.powerPeopleLine,
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
            npcs = npcs.hunters,
            spawnLine = locations.huntersLine,
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
            npcs = npcs.smartHunters,
            fallbackNpc = C("jpn_tyger_claws_gangster3_ranged3_sidewinder_ma"),
            spawnLine = locations.smartHuntersLine,
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
            name = "Wave 8 - Samurais Club",
            club = "SAMURAIS CLUB",
            count = 9,
            npcs = npcs.samurais,
            spawnLine = locations.samuraisLine,
            lockSpawnPosition = true,
            humanNavmeshCheckRadius = stableHumanNavmeshCheckRadius,
            skipEmptySpawnRetries = skipEmptySpawnRetries,
            treasure = { rewardMoney = 30000 },
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
            startMessage = "SAMURAIS CLUB: THE BLADE KNOWS NO FEAR, V.",
            forceMeleeAttack = true
        }
    }

    return {
        waves = waves,
        startMarkerPos = locations.start,
        spawnLines = spawnLines
    }
end
