ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_ambulancejob:revive')
AddEventHandler('esx_ambulancejob:revive', function(target)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == 'ambulance' or xPlayer.job.name == 'fire' or xPlayer.job.name == 'police' then
		xPlayer.addMoney(Config.ReviveReward)
		TriggerClientEvent('esx_ambulancejob:revive', target)
	else
		print(('esx_ambulancejob: %s attempted to revive!'):format(xPlayer.identifier))
	end
end)

RegisterServerEvent('esx_ambulancejob:pomozWstac')
AddEventHandler('esx_ambulancejob:pomozWstac', function(target)
	local xPlayer = ESX.GetPlayerFromId(source)

	xPlayer.addMoney(Config.ReviveReward)
	TriggerClientEvent('esx_ambulancejob:revive', target)
	print(('%s udzielil pierwszej pomocy!'):format(xPlayer.identifier))
end)

RegisterServerEvent('esx_ambulancejob:heal')
AddEventHandler('esx_ambulancejob:heal', function(target, type)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == 'ambulance' or xPlayer.job.name == 'fire' or xPlayer.job.name == 'police' then
		TriggerClientEvent('esx_ambulancejob:heal', target, type)
	else
		print(('esx_ambulancejob: %s attempted to heal!'):format(xPlayer.identifier))
	end
end)

RegisterServerEvent('esx_ambulancejob:drag')
AddEventHandler('esx_ambulancejob:drag', function(target)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == 'ambulance' then
		TriggerClientEvent('esx_ambulancejob:drag', target, source)
	else
		print(('esx_ambulancejob: %s attempted to drag (not cop)!'):format(xPlayer.identifier))
	end
end)

RegisterServerEvent('esx_ambulancejob:putInVehicle')
AddEventHandler('esx_ambulancejob:putInVehicle', function(target)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == 'ambulance' then
		TriggerClientEvent('esx_ambulancejob:putInVehicle', target)
	else
		print(('esx_ambulancejob: %s attempted to put in vehicle!'):format(xPlayer.identifier))
	end
end)

TriggerEvent('esx_phone:registerNumber', 'ambulance', _U('alert_ambulance'), true, true)

TriggerEvent('esx_society:registerSociety', 'ambulance', 'Ambulance', 'society_ambulance', 'society_ambulance', 'society_ambulance', {type = 'public'})

ESX.RegisterServerCallback('esx_ambulancejob:removeItemsAfterRPDeath', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	if Config.RemoveCashAfterRPDeath then
		if xPlayer.getMoney() > 0 then
			xPlayer.removeMoney(xPlayer.getMoney())
		end

		if xPlayer.getAccount('black_money').money > 0 then
			xPlayer.setAccountMoney('black_money', 0)
		end
	end

	if Config.RemoveItemsAfterRPDeath then
		for i=1, #xPlayer.inventory, 1 do
			if xPlayer.inventory[i].count > 0 then
				xPlayer.setInventoryItem(xPlayer.inventory[i].name, 0)
			end
		end
	end

	local playerLoadout = {}
	if Config.RemoveWeaponsAfterRPDeath then
		for i=1, #xPlayer.loadout, 1 do
			xPlayer.removeWeapon(xPlayer.loadout[i].name)
		end
	else -- save weapons & restore em' since spawnmanager removes them
		for i=1, #xPlayer.loadout, 1 do
			table.insert(playerLoadout, xPlayer.loadout[i])
		end

		-- give back wepaons after a couple of seconds
		Citizen.CreateThread(function()
			Citizen.Wait(5000)
			for i=1, #playerLoadout, 1 do
				if playerLoadout[i].label ~= nil then
					xPlayer.addWeapon(playerLoadout[i].name, playerLoadout[i].ammo)
				end
			end
		end)
	end

	cb()
end)

if Config.EarlyRespawnFine then
	ESX.RegisterServerCallback('esx_ambulancejob:checkBalance', function(source, cb)
		local xPlayer = ESX.GetPlayerFromId(source)
		local bankBalance = xPlayer.getAccount('bank').money

		cb(bankBalance >= Config.EarlyRespawnFineAmount)
	end)

	RegisterServerEvent('esx_ambulancejob:payFine')
	AddEventHandler('esx_ambulancejob:payFine', function()
		local xPlayer = ESX.GetPlayerFromId(source)
		local fineAmount = Config.EarlyRespawnFineAmount

		TriggerClientEvent('esx:showNotification', xPlayer.source, _U('respawn_bleedout_fine_msg', ESX.Math.GroupDigits(fineAmount)))
		xPlayer.removeAccountMoney('bank', fineAmount)
	end)
end

ESX.RegisterServerCallback('esx_ambulancejob:getItemAmount', function(source, cb, item)
	local xPlayer = ESX.GetPlayerFromId(source)
	local quantity = xPlayer.getInventoryItem(item).count

	cb(quantity)
end)

ESX.RegisterServerCallback('esx_ambulancejob:buyJobVehicle', function(source, cb, vehicleProps, type)
	local xPlayer = ESX.GetPlayerFromId(source)
	local price = getPriceFromHash(vehicleProps.model, xPlayer.job.grade_name, type)

	-- vehicle model not found
	if price == 0 then
		print(('esx_ambulancejob: %s attempted to exploit the shop! (invalid vehicle model)'):format(xPlayer.identifier))
		cb(false)
	end

	if xPlayer.getMoney() >= price then
		xPlayer.removeMoney(price)

		MySQL.Async.execute('INSERT INTO owned_vehicles (owner, vehicle, plate, type, job, `stored`) VALUES (@owner, @vehicle, @plate, @type, @job, @stored)', {
			['@owner'] = xPlayer.identifier,
			['@vehicle'] = json.encode(vehicleProps),
			['@plate'] = vehicleProps.plate,
			['@type'] = type,
			['@job'] = xPlayer.job.name,
			['@stored'] = true
		}, function (rowsChanged)
			cb(true)
		end)
	else
		cb(false)
	end
end)

ESX.RegisterServerCallback('esx_ambulancejob:storeNearbyVehicle', function(source, cb, nearbyVehicles)
	local xPlayer = ESX.GetPlayerFromId(source)
	local foundPlate, foundNum

	for k,v in ipairs(nearbyVehicles) do
		local result = MySQL.Sync.fetchAll('SELECT plate FROM owned_vehicles WHERE owner = @owner AND plate = @plate AND job = @job', {
			['@owner'] = xPlayer.identifier,
			['@plate'] = v.plate,
			['@job'] = xPlayer.job.name
		})

		if result[1] then
			foundPlate, foundNum = result[1].plate, k
			break
		end
	end

	if not foundPlate then
		cb(false)
	else
		MySQL.Async.execute('UPDATE owned_vehicles SET `stored` = true WHERE owner = @owner AND plate = @plate AND job = @job', {
			['@owner'] = xPlayer.identifier,
			['@plate'] = foundPlate,
			['@job'] = xPlayer.job.name
		}, function (rowsChanged)
			if rowsChanged == 0 then
				print(('esx_ambulancejob: %s has exploited the garage!'):format(xPlayer.identifier))
				cb(false)
			else
				cb(true, foundNum)
			end
		end)
	end

end)

function getPriceFromHash(hashKey, jobGrade, type)
	if type == 'helicopter' then
		local vehicles = Config.AuthorizedHelicopters[jobGrade]

		for k,v in ipairs(vehicles) do
			if GetHashKey(v.model) == hashKey then
				return v.price
			end
		end
	elseif type == 'car' then
		local vehicles = Config.AuthorizedVehicles[jobGrade]

		for k,v in ipairs(vehicles) do
			if GetHashKey(v.model) == hashKey then
				return v.price
			end
		end
	end

	return 0
end

RegisterServerEvent('esx_ambulancejob:removeItem')
AddEventHandler('esx_ambulancejob:removeItem', function(item)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)

	xPlayer.removeInventoryItem(item, 1)

	if item == 'bandage' then
		TriggerClientEvent('esx:showNotification', _source, _U('used_bandage'))
	elseif item == 'medikit' then
		TriggerClientEvent('esx:showNotification', _source, _U('used_medikit'))
	end
end)

RegisterServerEvent('esx_ambulancejob:giveItem')
AddEventHandler('esx_ambulancejob:giveItem', function(itemName)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name ~= 'ambulance' then
		print(('esx_ambulancejob: %s attempted to spawn in an item!'):format(xPlayer.identifier))
		return
	elseif (itemName ~= 'medikit' and itemName ~= 'bandage') then
		print(('esx_ambulancejob: %s attempted to spawn in an item!'):format(xPlayer.identifier))
		return
	end

	local xItem = xPlayer.getInventoryItem(itemName)
	local count = 1

	if xItem.limit ~= -1 then
		count = xItem.limit - xItem.count
	end

	if xItem.count < xItem.limit then
		xPlayer.addInventoryItem(itemName, count)
	else
		TriggerClientEvent('esx:showNotification', source, _U('max_item'))
	end
end)

TriggerEvent('es:addGroupCommand', 'revive', 'mod', function(source, args, user)
	if args[1] ~= nil then
		if GetPlayerName(tonumber(args[1])) ~= nil then
			print(('esx_ambulancejob: %s used admin revive'):format(GetPlayerIdentifiers(source)[1]))
			TriggerClientEvent('esx_ambulancejob:revive', tonumber(args[1]))
		end
	else
		TriggerClientEvent('esx_ambulancejob:revive', source)
	end
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient Permissions.' } })
end, { help = _U('revive_help'), params = {{ name = 'id' }} })

TriggerEvent('es:addGroupCommand', 'reviveall', 'admin', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:revive', -1)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient Permissions.' } })
end, { help = _U('revive_help'), params = {{ name = 'id' }} })

--TESLA XD

TriggerEvent('es:addGroupCommand', 'teslagoto', 'admin', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:teslagoto', source)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient Permissions.' } })
end, { help = _U('revive_help'), params = {{ name = 'id' }} })

TriggerEvent('es:addGroupCommand', 'resetskindefault', 'admin', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:SET_PED_DEFAULT_COMPONENT_VARIATION', source)
end, function(source, args, user)
end)

TriggerEvent('es:addGroupCommand', 'gotogps', 'mod', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:waypoint', source)
end, function(source, args, user)
end)

TriggerEvent('es:addGroupCommand', 'testmysqlquery', 'admin', function(source, args, user)
	local query = table.concat(args, " ",1)
	local wynik = MySQL.Sync.fetchAll(query,{})
	TriggerClientEvent('pNotify:SendNotification', source, {text = tostring(wynik[1].plate)})
end, function(source, args, user)
end)

TriggerEvent('es:addGroupCommand', 'fix', 'admin', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:fix', source)
end, function(source, args, user)
end)

TriggerEvent('es:addGroupCommand', 'clean', 'admin', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:clean', source)
end, function(source, args, user)
end)

TriggerEvent('es:addGroupCommand', 'komisaktualizuj', 'admin', function(source, args, user)
	TriggerClientEvent('route68_komis:aktualizuj', -1)
	print('Komis zaktualizowany')
end, function(source, args, user)
end)

TriggerEvent('es:addGroupCommand', 'kickallserver', 'admin', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:kickallserver', -1)
end, function(source, args, user)
end)

RegisterServerEvent('esx_ambulancejob:kickallserver')
AddEventHandler('esx_ambulancejob:kickallserver', function()
	DropPlayer(source, 'Restart serwera [Route 68] - Oczekuj wiadomości o starcie serwera na Discordzie!')
end)

TriggerEvent('es:addGroupCommand', 'dj', 'user', function(source, args, user)
	TriggerClientEvent('esx_jb_dj:enabledjbooth', source, true)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient Permissions.' } })
end, { help = _U('revive_help'), params = {{ name = 'id' }} })

TriggerEvent('es:addGroupCommand', 'offdj', 'user', function(source, args, user)
	TriggerClientEvent('esx_jb_dj:enabledjbooth', source, false)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient Permissions.' } })
end, { help = _U('revive_help'), params = {{ name = 'id' }} })

--/TESLA XD

TriggerEvent('es:addGroupCommand', 'vanish', 'mod', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:vanish', source)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient Permissions.' } })
end, { help = _U('revive_help'), params = {{ name = 'id' }} })

TriggerEvent('es:addGroupCommand', 'unvanish', 'mod', function(source, args, user)
	TriggerClientEvent('esx_ambulancejob:unvanish', source)
end, function(source, args, user)
	TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient Permissions.' } })
end, { help = _U('revive_help'), params = {{ name = 'id' }} })

-- Vanish

ESX.RegisterUsableItem('medikit', function(source)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	xPlayer.removeInventoryItem('medikit', 1)

	TriggerClientEvent('esx_ambulancejob:heal', _source, 'big')
	TriggerClientEvent('esx:showNotification', _source, _U('used_medikit'))
end)

ESX.RegisterUsableItem('bandage', function(source)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	xPlayer.removeInventoryItem('bandage', 1)

	TriggerClientEvent('esx_ambulancejob:heal', _source, 'small')
	TriggerClientEvent('esx:showNotification', _source, _U('used_bandage'))
end)

ESX.RegisterUsableItem('anti', function(source)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    --xPlayer.removeInventoryItem('anti', 1)

    TriggerClientEvent('esx_ambulancejob:tabletka', _source)
    --TriggerClientEvent('adrp_fix:ragdoll', _source)
end)

ESX.RegisterServerCallback('esx_ambulancejob:getDeathStatus', function(source, cb)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local Martwy = false

	MySQL.Async.fetchAll('SELECT is_dead FROM users WHERE @identifier=identifier', {
		['@identifier'] = xPlayer.identifier
	}, function(result)
		if result == 1 then
			Martwy = true
		else
			Martwy = false
		end
	end)
	cb(Martwy)
end)

RegisterServerEvent('esx_ambulancejob:setDeathStatus')
AddEventHandler('esx_ambulancejob:setDeathStatus', function(isDead)
	local identifier = GetPlayerIdentifiers(source)[1]

	MySQL.Sync.execute('UPDATE users SET is_dead = @isDead WHERE identifier = @identifier', {
		['@identifier'] = identifier,
		['@isDead']     = isDead
	})
end)

RegisterServerEvent('esx_ambulancejob:setDeathStatus3')
AddEventHandler('esx_ambulancejob:setDeathStatus3', function(target)
	local identifier = GetPlayerIdentifiers(target)[1]

	MySQL.Sync.execute('UPDATE users SET is_dead = @isDead WHERE identifier = @identifier', {
		['@identifier'] = identifier,
		['@isDead']     = false
	})
end)

RegisterServerEvent('esx_ambulancejob:setDeathStatus2')
AddEventHandler('esx_ambulancejob:setDeathStatus2', function(player, isDead)
	local identifier = GetPlayerIdentifiers(player)[1]

	MySQL.Sync.execute('UPDATE users SET is_dead = @isDead WHERE identifier = @identifier', {
		['@identifier'] = identifier,
		['@isDead']     = isDead
	})
end)


ESX.RegisterServerCallback('esx_ambulancejob:sprawdzLicencjeFirstAid', function(source, cb)
	local identifier = GetPlayerIdentifiers(source)[1]
	local licencja = false

	local licenses = MySQL.Sync.fetchAll("SELECT type FROM user_licenses where `owner`= @owner",{['@owner'] = identifier})

	for i=1, #licenses, 1 do
		if(licenses[i].type =="firstaid")then
			licencja = true
		end
	end

	Citizen.Wait(1000)
	
	cb(licencja)
end)

ESX.RegisterServerCallback('esx_holdup:CzyObrabowany', function(source, cb)
	local obrabowany = false

	MySQL.Async.fetchAll("SELECT `rabunek` FROM `cooldown` WHERE `name`='sklep'", {}, function(result)
		--if result[1] then
			if result[1] == 1 then
				obrabowany = true
			else
				obrabowany = false
				MySQL.Sync.execute("UPDATE cooldown SET rabunek=1")
			end
		--end
	end)
	cb(obrabowany)
end)

ESX.RegisterServerCallback('esx_holdupbank:CzyObrabowany', function(source, cb)
	local obrabowany = false

	MySQL.Async.fetchAll("SELECT `rabunek` FROM `cooldown` WHERE `name`='bank'", {}, function(result)
		--if result[1] then
			if result[1] == 1 then
				obrabowany = true
			else
				obrabowany = false
				MySQL.Sync.execute("UPDATE cooldown SET rabunek=1")
			end
		--end
	end)
	cb(obrabowany)
end)

ESX.RegisterServerCallback('route68_jubiler:CzyObrabowany', function(source, cb)
	local obrabowany = false

	MySQL.Async.fetchAll("SELECT `rabunek` FROM `cooldown` WHERE `name`='jubiler'", {}, function(result)
		--if result[1] then
			if result[1] == 1 then
				obrabowany = true
			else
				obrabowany = false
				MySQL.Sync.execute("UPDATE cooldown SET rabunek=1")
			end
		--end
	end)
	cb(obrabowany)
end)


RegisterServerEvent('route68_napady:koniecNapadu')
AddEventHandler('route68_napady:koniecNapadu', function(rodzaj)
	if rodzaj == 'bank' then
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='jubiler'")
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='sklep'")
	elseif rodzaj == 'sklep' then
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='jubiler'")
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='bank'")
	elseif rodzaj == 'jubiler' then
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='sklep'")
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='bank'")
	end
end)

RegisterServerEvent('route68_napady:koniecCoolDownu')
AddEventHandler('route68_napady:koniecCoolDownu', function(rodzaj)
	if rodzaj == 'bank' then
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='bank'")
	elseif rodzaj == 'sklep' then
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='sklep'")
	elseif rodzaj == 'jubiler' then
		MySQL.Sync.execute("UPDATE cooldown SET rabunek=0 WHERE `name`='jubiler'")
	end
end)

RegisterServerEvent('esx_teleport:przelaczKlubServer')
AddEventHandler('esx_teleport:przelaczKlubServer', function(rodzaj)
	TriggerClientEvent('esx_teleport:przelaczKlubClient', -1, rodzaj)
end)

ESX.RegisterServerCallback("route68:retrieveHospitalTime", function(source, cb)

	local src = source

	local xPlayer = ESX.GetPlayerFromId(src)
	local Identifier = xPlayer.identifier


	MySQL.Async.fetchAll("SELECT hospital FROM users WHERE identifier = @identifier", { ["@identifier"] = Identifier }, function(result)

		local HospitalTime = tonumber(result[1].hospital)

		if HospitalTime > 0 then

			cb(true, HospitalTime)
		else
			cb(false, 0)
		end

	end)
end)

RegisterServerEvent("route68:updateHospitalTime")
AddEventHandler("route68:updateHospitalTime", function(newHospitalTime)
	local src = source

	EditHospitalTime(src, newHospitalTime)
end)

function EditHospitalTime(source, hospitalTime, lekarz)

	local src = source
	local lekarz2 = ESX.GetPlayerFromId(lekarz)
	local xPlayer = ESX.GetPlayerFromId(src)
	local Identifier = xPlayer.identifier
	local IdentifierLekarz = nil
	if lekarz ~= nil then
		IdentifierLekarz = lekarz2.identifier
	end

	MySQL.Async.execute(
       "UPDATE users SET hospital = @newHospitalTime, lekarz = @lekarz WHERE identifier = @identifier",
        {
			['@identifier'] = Identifier,
			['@newHospitalTime'] = tonumber(hospitalTime),
			['@lekarz'] = IdentifierLekarz
		}
	)
	--[[MySQL.Async.execute(
       "UPDATE users SET lekarz = @lekarz WHERE identifier = @identifier",
        {
			['@identifier'] = Identifier,
			['@lekarz'] = IdentifierLekarz
		}
	)]]
end

RegisterServerEvent("route68:hospitalPlayer")
AddEventHandler("route68:hospitalPlayer", function(targetSrc, hospitalTime)
	local src = source
	local identifier = targetSrc
	local targetSrc = tonumber(targetSrc)

	HospitalPlayer(targetSrc, hospitalTime, identifier, src)

	TriggerClientEvent("esx:showNotification", identifier, "Wystawiono Ci zwolnienie lekarskie oraz wyznaczono rehabilitację na okres " .. hospitalTime .. " minut.")

	local oficerIDN = ESX.GetPlayerFromId(src).identifier
	local skazanyIDN = ESX.GetPlayerFromId(targetSrc).identifier
	local oficer = 'Nieznany'
	local skazany = 'Nieznany'

	MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE @identifier = identifier', {
		['@identifier'] = oficerIDN
	}, function(result)
		if result[1] then
			local imie = result[1].firstname
			local nazwisko = result[1].lastname
			oficer = imie..' '..nazwisko
		end
	end)
	MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE @identifier = identifier', {
		['@identifier'] = skazanyIDN
	}, function(result)
		if result[1] then
			local imie = result[1].firstname
			local nazwisko = result[1].lastname
			skazany = imie..' '..nazwisko
		end
	end)

	Citizen.Wait(5000)

	MySQL.Async.execute("INSERT INTO `hospitalhistory` (doctor, pacjent, czas) VALUES (@oficer, @skazany, @wyrok)",
		{
			['@oficer'] = oficer,
			['@skazany'] = skazany,
			['@wyrok'] = hospitalTime
		}
	)

end)

RegisterServerEvent("route68:unHospitalPlayer")
AddEventHandler("route68:unHospitalPlayer", function(targetIdentifier)
	local src = source
	local xPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)

	if xPlayer ~= nil then
		UnHospital(xPlayer.source)
	else
		MySQL.Async.execute(
			"UPDATE users SET hospital = @newHospitalTime WHERE identifier = @identifier",
			{
				['@identifier'] = targetIdentifier,
				['@newHospitalTime'] = 0
			}
		)
	end

	TriggerClientEvent("esx:showNotification", src, "Anulowano rehabilitrację gracza "..xPlayer.name)
end)

ESX.RegisterServerCallback("route68:retrieveHospitalPlayers", function(source, cb)

	local jailedPersons = {}
	local lekarz = ESX.GetPlayerFromId(source)
	local IdentifierLekarz = lekarz.identifier

	MySQL.Async.fetchAll("SELECT `name`, `hospital`, `identifier` FROM `users` WHERE `hospital` > @hospital AND `lekarz` = @lekarz", { ["@hospital"] = 0, ['@lekarz'] = IdentifierLekarz }, function(result)

		for i = 1, #result, 1 do
			table.insert(jailedPersons, { name = result[i].name, jailTime = result[i].hospital, identifier = result[i].identifier })
		end

		cb(jailedPersons)
	end)
end)

function HospitalPlayer(jailPlayer, jailTime, identifier, lekarz)
	TriggerClientEvent("route68:hospitalPlayer", jailPlayer, jailTime)

	EditHospitalTime(jailPlayer, jailTime, lekarz)
	local xPlayer = ESX.GetPlayerFromId(identifier)
	local job = xPlayer.job.name
	local grade = xPlayer.job.grade

	if job == 'police' or job == 'ambulance' or job == 'mecano' or job == 'fire' then
		xPlayer.setJob('off' ..job, grade)
		TriggerClientEvent('esx:showNotification', identifier, 'Zakończono służbę ze względu na zwolnienie lekarskie.')
		TriggerEvent('esx_policejob:updateBlip')
	end
end

function UnHospital(jailPlayer)
	TriggerClientEvent("route68:unHospitalPlayer", jailPlayer)

	EditHospitalTime(jailPlayer, 0)
end