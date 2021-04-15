Config                            = {}

Config.DrawDistance               = 100.0

Config.Marker                     = { type = 25, x = 1.5, y = 1.5, z = 0.5, r = 242, g = 123, b = 151, a = 175, rotate = false }

Config.ReviveReward               = 0  -- revive reward, set to 0 if you don't want it enabled
Config.AntiCombatLog              = true -- enable anti-combat logging?
Config.LoadIpl                    = false -- disable if you're using fivem-ipl or other IPL loaders

Config.Locale                     = 'pl'

local second = 1000
local minute = 60 * second

Config.EarlyRespawnTimer          = 10 * minute  -- Time til respawn is available
Config.BleedoutTimer              = 10 * minute -- Time til the player bleeds out

Config.EnablePlayerManagement     = true
Config.EnableSocietyOwnedVehicles = false

Config.RemoveWeaponsAfterRPDeath  = true
Config.RemoveCashAfterRPDeath     = true
Config.RemoveItemsAfterRPDeath    = true

-- Let the player pay for respawning early, only if he can afford it.
Config.EarlyRespawnFine           = false
Config.EarlyRespawnFineAmount     = 375

Config.RespawnPoint = { coords = vector3(330.53, -575.47, 43.28), heading = 161.30 }

Config.Hospitals = {

	CentralLosSantos = {

		Blip = {
			coords = vector3(311.04, -588.87, 43.28),
			sprite = 621,
			scale  = 0.9,
			color  = 1
		},

		AmbulanceActions = {
			vector3(301.59, -599.26, 42.29)
		},

		Pharmacies = {
			vector3(306.78, -601.45, 42.29)
		},

		Vehicles = {
			{
				Spawner = vector3(287.53, -590.91, 43.40),
				InsideShop = vector3(446.7, -1355.6, 43.5),
				Marker = { type = 36, x = 1.0, y = 1.0, z = 1.0, r = 242, g = 123, b = 151, a = 175, rotate = true },
				SpawnPoints = {
					{ coords = vector3(289.30, -585.58, 43.15), heading = 441.6, radius = 4.0 },
					{ coords = vector3(294.0, -1433.1, 29.8), heading = 227.6, radius = 4.0 },
					{ coords = vector3(309.4, -1442.5, 29.8), heading = 227.6, radius = 6.0 }
				}
			}
		},

		Helicopters = {
			{
				Spawner = vector3(351.73, -588.01, 74.26),
				InsideShop = vector3(305.6, -1419.7, 41.5),
				Marker = { type = 34, x = 1.5, y = 1.5, z = 1.5, r = 242, g = 123, b = 151, a = 175, rotate = true },
				SpawnPoints = {
					{ coords = vector3(351.73, -588.01, 74.26), heading = 142.7, radius = 10.0 }
				}
			}
		},

		FastTravels = {
			--[[{
				From = vector3(294.7, -1448.1, 29.1),
				To = { coords = vector3(272.8, -1358.8, 23.6), heading = 0.0 },
				Marker = { type = 25, x = 2.0, y = 2.0, z = 0.5, r = 242, g = 123, b = 151, a = 175, rotate = false }
			},]]--

			--[[{
				From = vector3(275.3, -1361, 23.5),
				To = { coords = vector3(295.8, -1446.5, 28.9), heading = 0.0 },
				Marker = { type = 25, x = 2.0, y = 2.0, z = 0.5, r = 242, g = 123, b = 151, a = 175, rotate = false }
			},]]--

			--[[{
				From = vector3(247.3, -1371.5, 23.5),
				To = { coords = vector3(333.1, -1434.9, 45.5), heading = 138.6 },
				Marker = { type = 25, x = 1.5, y = 1.5, z = 0.5, r = 242, g = 123, b = 151, a = 175, rotate = false }
			},]]--

			--[[{
				From = vector3(335.5, -1432.0, 45.50),
				To = { coords = vector3(249.1, -1369.6, 23.5), heading = 0.0 },
				Marker = { type = 25, x = 2.0, y = 2.0, z = 0.5, r = 242, g = 123, b = 151, a = 175, rotate = false }
			},]]--

			--[[{
				From = vector3(234.5, -1373.7, 20.9),
				To = { coords = vector3(320.9, -1478.6, 28.8), heading = 0.0 },
				Marker = { type = 25, x = 1.5, y = 1.5, z = 1.0, r = 242, g = 123, b = 151, a = 175, rotate = false }
			},]]--

			--[[{
				From = vector3(317.9, -1476.1, 29.0),
				To = { coords = vector3(238.6, -1368.4, 23.5), heading = 0.0 },
				Marker = { type = 25, x = 1.5, y = 1.5, z = 1.0, r = 242, g = 123, b = 151, a = 175, rotate = false }
			}]]--
		},

		FastTravelsPrompt = {



		}

	}

}

Config.AuthorizedVehicles = {

	ambulance = {

	},

	doctor = {

	},

	chief_doctor = {

	},

	boss = {

	}

}

Config.AuthorizedHelicopters = {

	ambulance = {},

	doctor = {

	},

	chief_doctor = {

	},

	boss = {

	}

}
