Keys = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

local FirstSpawn, PlayerLoaded = true, false
local pozycjaBW = nil

IsDead = false
ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(100)
	end

	PlayerLoaded = true
	ESX.PlayerData = ESX.GetPlayerData()
end)

local hospitalTime = 0
local rehab = false

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	ESX.PlayerData = xPlayer
	PlayerLoaded = true

	Citizen.Wait(25000)

	ESX.TriggerServerCallback("route68:retrieveHospitalTime", function(inHospital, newHospitalTime)
		if inHospital then

			hospitalTime = newHospitalTime

			rehab = true
			ESX.ShowNotification("Twoja postać musi przebywać na rehabiltacji jeszcze przez " .. hospitalTime .. " minut...")

			HospitalLogin()
		end
	end)
end)

RegisterNetEvent('esx_ambulancejob:kickallserver')
AddEventHandler('esx_ambulancejob:kickallserver', function()
	TriggerServerEvent('esx_ambulancejob:kickallserver')
end)

function HospitalLogin()
	Citizen.CreateThread(function()

		while hospitalTime > 0 do

			hospitalTime = hospitalTime - 1
			rehab = true

			if tonumber(string.sub(tostring(hospitalTime), -1)) == 5 or tonumber(string.sub(tostring(hospitalTime), -1)) == 0 then
				ESX.ShowNotification("Pozostało " .. hospitalTime .. " minut rehabilitacji...")
			end

			local femaleskin = GetHashKey("mp_f_freemode_01")
			local sex = 'move_m@injured'

			if GetEntityModel(PlayerPedId()) == femaleskin then
				sex = 'move_f@injured'
			end

			ESX.Streaming.RequestAnimSet(sex, function()
				SetPedMovementClipset(PlayerPedId(), sex, true)
			end)

			TriggerServerEvent("route68:updateHospitalTime", hospitalTime)

			if hospitalTime <= 0 then
				UnHospital()
				TriggerServerEvent("route68:updateHospitalTime", 0)
			end

			Citizen.Wait(60000)
		end

	end)
end

function UnHospital()
	HospitalLogin()
	
	Citizen.Wait(1000)

	ESX.ShowNotification("Zakończono rehabilitację!")
	rehab = false
	ResetPedMovementClipset(PlayerPedId(), 0.0)
end

function OpenRehabMenu()
	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'hospital_menu',
		{
			title    = "Menu Rehablitacji",
			align    = 'left',
			elements = {
				{ label = "Wystaw zwolnienie / rehabilitację", value = "jail_closest_player" },
				{ label = "Anuluj rehabilitację", value = "unjail_player" }
			}
		},
	function(data, menu)

		local action = data.current.value

		if action == "jail_closest_player" then

			menu.close()

			ESX.UI.Menu.Open(
          		'dialog', GetCurrentResourceName(), 'hospital_time',
          		{
            		title = "Czas Rehabilitacji (w minutach)"
          		},
          	function(data2, menu2)

            	local jailTime = tonumber(data2.value)

            	if jailTime == nil then
              		ESX.ShowNotification("Nieprawidłowy czas!")
            	else
              		menu2.close()

              		local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()

              		if closestPlayer == -1 or closestDistance > 3.0 then
                		ESX.ShowNotification("Brak graczy w pobliżu!")
					else
						TriggerServerEvent("route68:hospitalPlayer", GetPlayerServerId(closestPlayer), jailTime)
              		end

				end

          	end, function(data2, menu2)
				menu2.close()
			end)
		elseif action == "unjail_player" then

			local elements = {}

			ESX.TriggerServerCallback("route68:retrieveHospitalPlayers", function(playerArray)

				if #playerArray == 0 then
					ESX.ShowNotification("Nikt z Twoich pacjentów nie przebywa obecnie na rehabilitacji!")
					return
				end

				for i = 1, #playerArray, 1 do
					table.insert(elements, {label = "Pacjant/ka: " .. playerArray[i].name .. " | Pozostała czas: " .. playerArray[i].jailTime .. " minut", value = playerArray[i].identifier })
				end

				ESX.UI.Menu.Open(
					'default', GetCurrentResourceName(), 'unhospital_menu',
					{
						title = "Anuluj rehabilitację",
						align = "left",
						elements = elements
					},
				function(data2, menu2)

					local action = data2.current.value

					TriggerServerEvent("route68:unHospitalPlayer", action)

					menu2.close()

				end, function(data2, menu2)
					menu2.close()
				end)
			end)

		end

	end, function(data, menu)
		menu.close()
	end)
end

RegisterNetEvent("route68:unHospitalPlayer")
AddEventHandler("route68:unHospitalPlayer", function()
	hospitalTime = 0

	UnHospital()
end)

RegisterNetEvent("route68:hospitalPlayer")
AddEventHandler("route68:hospitalPlayer", function(newJailTime)
	hospitalTime = newJailTime
	rehab = false
	HospitalLogin()
end)

RegisterNetEvent('route68_firejob:OtworzMenuRehab')
AddEventHandler('route68_firejob:OtworzMenuRehab', function()
	OpenRehabMenu()
end)

Citizen.CreateThread(function()
	while hospitalTime > 0 do
		Citizen.Wait(500)
		if rehab == true then
			local femaleskin = GetHashKey("mp_f_freemode_01")
			local sex = 'move_m@injured'

			if GetEntityModel(PlayerPedId()) == femaleskin then
				sex = 'move_f@injured'
			end

			ESX.Streaming.RequestAnimSet(sex, function()
				SetPedMovementClipset(PlayerPedId(), sex, true)
			end)
		end
	end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

RegisterNetEvent('esx_ambulancejob:SET_PED_DEFAULT_COMPONENT_VARIATION')
AddEventHandler('esx_ambulancejob:SET_PED_DEFAULT_COMPONENT_VARIATION', function()
	SetPedDefaultComponentVariation(GetPlayerPed(-1))
	print('done')
end)

AddEventHandler('playerSpawned', function()
	IsDead = false

	if FirstSpawn then
		exports.spawnmanager:setAutoSpawn(false) -- disable respawn
		FirstSpawn = false

		ESX.TriggerServerCallback('esx_ambulancejob:getDeathStatus', function(isDead)
			if isDead then
				while not PlayerLoaded do
					Citizen.Wait(1000)
				end

				ESX.ShowNotification("Jesteś nieprzytomny/a, ponieważ przed wyjściem z serwera, Towja postać miała BW")
				local playerPed  = PlayerPedId()
				KillRPDeath()
				RemoveItemsAfterRPDeath()
			end
		end)
	end
end)

-- Create blips
Citizen.CreateThread(function()
	for k,v in pairs(Config.Hospitals) do
		local blip = AddBlipForCoord(v.Blip.coords)

		SetBlipSprite(blip, v.Blip.sprite)
		SetBlipScale(blip, v.Blip.scale)
		SetBlipColour(blip, v.Blip.color)
		SetBlipAsShortRange(blip, true)

		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName(_U('hospital'))
		EndTextCommandSetBlipName(blip)
	end
end)

-- Disable most inputs when dead
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsDead then
			--DisableAllControlActions(0)
			EnableControlAction(0, Keys['G'], true)
			EnableControlAction(0, Keys['T'], true)
			EnableControlAction(0, Keys['E'], true)
			EnableControlAction(0, Keys['F2'], true)
			--EnableControlAction(0, 0, true)
		else
			Citizen.Wait(500)
		end
	end
end)

function OnPlayerDeath()
	IsDead = true
	TriggerServerEvent('esx_ambulancejob:setDeathStatus', true)

	StartDeathTimer()
	pozycjaBW = GetEntityCoords(PlayerPedId())
	startRagdollWorkaround()
end

function StartDistressSignal()
	Citizen.CreateThread(function()
		local timer = Config.BleedoutTimer

		while timer > 0 and IsDead do
			Citizen.Wait(2)
			timer = timer - 30

			SetTextFont(4)
			SetTextProportional(1)
			SetTextScale(0.45, 0.45)
			SetTextColour(185, 185, 185, 255)
			SetTextDropShadow(0, 0, 0, 0, 255)
			SetTextEdge(1, 0, 0, 0, 255)
			SetTextDropShadow()
			SetTextOutline()
			BeginTextCommandDisplayText('STRING')
			AddTextComponentSubstringPlayerName(_U('distress_send'))
			EndTextCommandDisplayText(0.175, 0.805)

			if IsControlPressed(0, Keys['G']) then
				SendDistressSignal()

				Citizen.CreateThread(function()
					Citizen.Wait(1000 * 60 * 5)
					if IsDead then
						StartDistressSignal()
					end
				end)

				break
			end
		end
	end)
end

function SendDistressSignal()
	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)

	ESX.ShowNotification(_U('distress_sent'))
	TriggerServerEvent('esx_phone:send', 'ambulance', _U('distress_message'), false, {
		x = coords.x,
		y = coords.y,
		z = coords.z
	})
end

function DrawGenericTextThisFrame()
	SetTextFont(4)
	SetTextProportional(0)
	SetTextScale(0.0, 0.5)
	SetTextColour(255, 255, 255, 255)
	SetTextDropshadow(0, 0, 0, 0, 255)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextCentre(true)
end

function secondsToClock(seconds)
	local seconds, hours, mins, secs = tonumber(seconds), 0, 0, 0

	if seconds <= 0 then
		return 0, 0
	else
		local hours = string.format("%02.f", math.floor(seconds / 3600))
		local mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
		local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))

		return mins, secs
	end
end

function StartDeathTimer()
	local canPayFine = false

	if Config.EarlyRespawnFine then
		ESX.TriggerServerCallback('esx_ambulancejob:checkBalance', function(canPay)
			canPayFine = canPay
		end)
	end

	local earlySpawnTimer = ESX.Math.Round(Config.EarlyRespawnTimer / 1000)
	local bleedoutTimer = ESX.Math.Round(Config.BleedoutTimer / 1000)

	Citizen.CreateThread(function()
		-- early respawn timer
		while earlySpawnTimer > 0 and IsDead do
			Citizen.Wait(1000)

			if earlySpawnTimer > 0 then
				earlySpawnTimer = earlySpawnTimer - 1
			end
		end

		-- bleedout timer
		while bleedoutTimer > 0 and IsDead do
			Citizen.Wait(1000)

			if bleedoutTimer > 0 then
				bleedoutTimer = bleedoutTimer - 1
			end
		end
	end)

	Citizen.CreateThread(function()
		local text, timeHeld

		-- early respawn timer
		while earlySpawnTimer > 0 and IsDead do
			Citizen.Wait(0)
			text = _U('respawn_available_in', secondsToClock(earlySpawnTimer))

			DrawGenericTextThisFrame()

			SetTextEntry("STRING")
			AddTextComponentString(text)
			DrawText(0.5, 0.8)
		end

		-- bleedout timer
		while bleedoutTimer > 0 and IsDead do
			Citizen.Wait(0)
			text = ''

			if not Config.EarlyRespawnFine then
				text = text .. _U('respawn_bleedout_prompt')

				if IsControlPressed(0, Keys['E']) and timeHeld > 60 then
					RemoveItemsAfterRPDeath()
					local count = 250
					local society = 'fire'
					TriggerServerEvent('esx_society:szpital', society, count)
					break
				end
			elseif Config.EarlyRespawnFine and canPayFine then
				text = text .. _U('respawn_bleedout_fine', ESX.Math.GroupDigits(Config.EarlyRespawnFineAmount))

				if IsControlPressed(0, Keys['E']) and timeHeld > 60 then
					TriggerServerEvent('esx_ambulancejob:payFine')
					RemoveItemsAfterRPDeath()
					break
				end
			end

			if IsControlPressed(0, Keys['E']) then
				timeHeld = timeHeld + 1
			else
				timeHeld = 0
			end

			DrawGenericTextThisFrame()

			SetTextEntry("STRING")
			AddTextComponentString(text)
			DrawText(0.5, 0.8)
		end

		if bleedoutTimer < 1 and IsDead then
			RemoveItemsAfterRPDeath()
		end
	end)
end

function RemoveItemsAfterRPDeath()
	TriggerServerEvent('esx_ambulancejob:setDeathStatus', false)

	Citizen.CreateThread(function()
		DoScreenFadeOut(800)

		while not IsScreenFadedOut() do
			Citizen.Wait(10)
		end

		ESX.TriggerServerCallback('esx_ambulancejob:removeItemsAfterRPDeath', function()
			ESX.SetPlayerData('lastPosition', Config.RespawnPoint.coords)
			ESX.SetPlayerData('loadout', {})

			TriggerServerEvent('esx:updateLastPosition', Config.RespawnPoint.coords)
			RespawnPed(PlayerPedId(), Config.RespawnPoint.coords, Config.RespawnPoint.heading)

			StopScreenEffect('DeathFailOut')
			DoScreenFadeIn(800)
			--TriggerEvent("pNotify:SendNotification", {text = 'Posiadane bronie zaraz zostaną przywrócone', timeout=7000})
		end)
	end)
end

function KillRPDeath()
	TriggerServerEvent('esx_ambulancejob:setDeathStatus', false)

	Citizen.CreateThread(function()
		DoScreenFadeOut(800)

		while not IsScreenFadedOut() do
			Citizen.Wait(10)
			SetEntityHealth(PlayerPedId(), 99)
		end

		DoScreenFadeIn(800)

	end)
end

function RespawnPed(ped, coords, heading)
	SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false, true)
	NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
	SetPlayerInvincible(ped, false)
	TriggerEvent('playerSpawned', coords.x, coords.y, coords.z)
	ClearPedBloodDamage(ped)

	ESX.UI.Menu.CloseAll()
end

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function(phoneNumber, contacts)
	local specialContact = {
		name		= 'Ambulance',
		number		= 'ambulance',
		base64Icon	= 'data:image/png;base64,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'
	}

	TriggerEvent('esx_phone:addSpecialContact', specialContact.name, specialContact.number, specialContact.base64Icon)
end)

AddEventHandler('esx:onPlayerDeath', function(reason)
	OnPlayerDeath()
end)

RegisterNetEvent('esx_ambulancejob:revive')
AddEventHandler('esx_ambulancejob:revive', function()
	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)
	TriggerServerEvent('esx_ambulancejob:setDeathStatus', false)
	TriggerEvent('kartazdrowia:HealBones',"all")

	Citizen.CreateThread(function()
		DoScreenFadeOut(800)

		while not IsScreenFadedOut() do
			Citizen.Wait(50)
		end

		ESX.SetPlayerData('lastPosition', {
			x = coords.x,
			y = coords.y,
			z = coords.z
		})

		TriggerServerEvent('esx:updateLastPosition', {
			x = coords.x,
			y = coords.y,
			z = coords.z
		})

		RespawnPed(playerPed, {
			x = coords.x,
			y = coords.y,
			z = coords.z,
			heading = 0.0
		})

		TriggerEvent('route68_animacje:blocked')

		StopScreenEffect('DeathFailOut')
		DoScreenFadeIn(800)
	end)
end)

RegisterNetEvent('esx_ambulancejob:fix')
AddEventHandler('esx_ambulancejob:fix', function()
	local playerPed = GetPlayerPed(-1)
	if IsPedInAnyVehicle(playerPed, false) then
		local vehicle = GetVehiclePedIsIn(playerPed, false)
		SetVehicleEngineHealth(vehicle, 1000)
		SetVehicleEngineOn( vehicle, true, true )
		SetVehicleFixed(vehicle)
		TriggerEvent("pNotify:SendNotification", {text = 'Pojazd Naprawiony!'})
	else
		TriggerEvent("pNotify:SendNotification", {text = 'Musisz znajdować się w pojeździe!'})
	end
end)

RegisterNetEvent('esx_ambulancejob:clean')
AddEventHandler('esx_ambulancejob:clean', function()
	local playerPed = GetPlayerPed(-1)
	if IsPedInAnyVehicle(playerPed, false) then
		local vehicle = GetVehiclePedIsIn(playerPed, false)
		SetVehicleDirtLevel(vehicle, 0)
		TriggerEvent("pNotify:SendNotification", {text = 'Pojazd Wyczyszczony!'})
	else
		TriggerEvent("pNotify:SendNotification", {text = 'Musisz znajdować się w pojeździe!'})
	end
end)

local jedzie = false
local blipX = 0.0
local blipY = 0.0
local blipZ = 0.0

RegisterNetEvent('esx_ambulancejob:teslagoto')
AddEventHandler('esx_ambulancejob:teslagoto', function(args)
		jedzie = true
		local playerPed = PlayerPedId()
		local vehicle = GetVehiclePedIsIn(playerPed, false)
		local speed = 20.0

		local blip = GetFirstBlipInfoId(8)

		if (blip ~= 0) then
			tx, ty, tz = table.unpack(Citizen.InvokeNative(0xFA7C7F0AADF25D09, blip, Citizen.ResultAsVector()))
			blipX = tx
			blipY = ty
			blipZ = tz
		end

		TriggerEvent('pNotify:SendNotification', {text = 'X: '..blipX..' | Y: '..blipY.." | Z:"..blipZ})
		TaskVehicleDriveToCoord(playerPed, vehicle, blipX, blipY, blipZ, speed, false, GetHashKey('taxi'), 427, 20.0, true)

		TaskVehicleDriveWander(PlayerPedId(), GetVehiclePedIsIn(PlayerPedId(), false), 20.0, 427)
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(100)
		if blipX ~= 0.0 or blipY ~= 0.0 then
			if GetFirstBlipInfoId(8) == 0 and jedzie == true then
				jedzie = false
				TriggerEvent('pNotify:SendNotification', {text = 'Jesteś u celu! Dziękujemy za wspólną podróż!'})
				ClearPedTasks(playerPed)
			end
		end
	end
end)

RegisterNetEvent('esx_ambulancejob:waypoint')
AddEventHandler('esx_ambulancejob:waypoint', function()
	local playerPed = GetPlayerPed(-1)
	local inCar = false
	local blip = GetFirstBlipInfoId(8)

	if DoesBlipExist(blip) then
		local coord = GetBlipInfoIdCoord(blip)
		local groundFound, coordZ = false, 0
		local groundCheckHeights = { 0.0, 50.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0, 400.0,450.0, 500.0, 550.0, 600.0, 650.0, 700.0, 750.0, 800.0 }
		local vehicle
		if IsPedInAnyVehicle(playerPed, false) then
			vehicle = GetVehiclePedIsIn(playerPed, false)
			inCar = true
		end

		for i, height in ipairs(groundCheckHeights) do
		
			if inCar then
				ESX.Game.Teleport(vehicle, {
					x = coord.x,
					y = coord.y,
					z = height
				})
			else
				ESX.Game.Teleport(playerPed, {
					x = coord.x,
					y = coord.y,
					z = height
				})
			end

			local foundGround, z = GetGroundZFor_3dCoord(coord.x, coord.y, height)
			if foundGround then
				coordZ = z + 3
				groundFound = true
				break
			end
		end

		if inCar then
			ESX.Game.Teleport(vehicle, {
				x = coord.x,
				y = coord.y,
				z = coordZ
			})
		else
			ESX.Game.Teleport(playerPed, {
				x = coord.x,
				y = coord.y,
				z = coordZ
			})
		end
	end
end)

RegisterNetEvent('esx_ambulancejob:vanish')
AddEventHandler('esx_ambulancejob:vanish', function(args)
	local playerPed = PlayerPedId()
	local vanish = false

	if not vanish then
		SetEntityVisible(playerPed, false, false)
	end
end)

RegisterNetEvent('esx_ambulancejob:unvanish')
AddEventHandler('esx_ambulancejob:unvanish', function(args)
	local playerPed = PlayerPedId()
	local vanish = false

	if not vanish then
		SetEntityVisible(playerPed, true, true)
	end
end)

-- Load unloaded IPLs
if Config.LoadIpl then
	Citizen.CreateThread(function()
		LoadMpDlcMaps()
		EnableMpDlcMaps(true)
		RequestIpl('Coroner_Int_on') -- Morgue
	end)
end

function DeadInventory68First()
ESX.TriggerServerCallback('esx_ambulancejob:getDeathStatus', function(isDead)
	local Zycie = GetEntityHealth(PlayerPedId())
		if Zycie <= 100 then
			TriggerEvent("pNotify:SendNotification", {text = 'Nie możesz korzystać z ekwipunku będąc nieprzytomnym!'})
		else
		--	exports['es_extended']:openInventory()
	--		TriggerEvent('route68_eq:OpenInventory')
		end
	local playerPed = PlayerPedId()
	if not isDead then
		exports['es_extended']:openInventory()
	elseif isDead then
		TriggerEvent("pNotify:SendNotification", {text = 'Nie możesz korzystać z ekwipunku będąc nieprzytomnym!'})
	end
end)
end

function DeadInventory68()
	DeadInventory68First()
end

function openAmbulance68()
		OpenMobileAmbulanceActionsMenu()
end

RegisterNetEvent('esx_ambulancejob:tabletka')
AddEventHandler('esx_ambulancejob:tabletka', function()
    local playerPed = PlayerPedId()
	local zycie = GetEntityHealth(playerPed)
	local leczy = false

	if not leczy then
		if zycie < 170 then
			local sekunda = 1000
			local minuta = 60 * sekunda
			local czas = 3 * minuta
			leczy = true
			TriggerServerEvent('esx_ambulancejob:removeItem', 'anti')
			ESX.ShowNotification('~p~Tabletka ~w~zaczyna działać...')
			local hp = math.floor(zycie + 10)
			SetEntityHealth(playerPed, hp)
			Citizen.Wait(15000)
			ESX.ShowNotification('Czujesz się lepiej!')
			SetEntityHealth(playerPed, 170)
			Citizen.Wait(czas)
			leczy = false
		else
			ESX.ShowNotification('Nie możesz użyć ~p~tabletki, ~w~jeśli masz powyżej ~p~70 HP!')
		end
	else
		ESX.ShowNotification('Nie możesz teraz użyć kolejnej ~p~tabletki!')
	end

end)



-- OCHRONA PRZED BW

RegisterNetEvent('adrp_fix:ragdoll')
AddEventHandler('adrp_fix:ragdoll', function()
    startRagdollWorkaround()
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(25000)
		local Zycie = GetEntityHealth(PlayerPedId())
		if Zycie <= 99 and not IsPedInAnyVehicle(PlayerPedId(), false) then
			ClearPedTasksImmediately(PlayerPedId())
		end
	end
end)

function startRagdollWorkaround()
	
	local work = true
	local pozycjaBW = GetEntityCoords(PlayerPedId())
    SetTimecycleModifier('default')
    local players = {}
	
	for _, player in ipairs(GetActivePlayers()) do
		players[player] = true
	end

    Citizen.CreateThread(function()
        while work do
            Citizen.Wait(0)

            for k,v in pairs(players) do
                local targetPed = GetPlayerPed(k)

                SetEntityNoCollisionEntity(PlayerPedId(), targetPed, true)
            end
        end
	end)

	for i=1, 10 do
		Citizen.Wait(15000)
		ESX.TriggerServerCallback('esx_ambulancejob:getDeathStatus', function(isDead)
			if isDead then
				SetEntityCoords(PlayerPedId(), pozycjaBW.x, pozycjaBW.y, pozycjaBW.z, 1, 0, 0, 1)
				ClearPedTasksImmediately(PlayerPedId())
			end
		end)
    end

    for k,v in pairs(players) do
		if NetworkIsPlayerActive(k) then
			SetEntityLocallyVisible(GetPlayerPed(k))
        end
    end
	
	work = false
    SetTimecycleModifier('default')
end

function drawLoadingText(text, red, green, blue, alpha)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(1.0, 1.5)
    SetTextColour(red, green, blue, alpha)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.5)
end