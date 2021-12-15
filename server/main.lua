CurrentID = nil
CurrentXP = 0
CurrentRank = 0
BR = nil

TriggerEvent('brt:getSharedObject', function(obj) BR = obj end)

RegisterNetEvent("brt_gangxp:sync")
AddEventHandler("brt_gangxp:sync", function()
    local _source = source
    local xPlayer = BR.GetPlayerFromId(_source)

    if xPlayer.gang.name ~= 'nogang' then
        MySQL.Async.fetchAll('SELECT ID, xp, rank FROM gangs_data WHERE gang_name = @gang', {
            ['@gang'] = xPlayer.gang.name
        }, function(result)
            if #result > 0 then

                CurrentID = tonumber(result[1]["ID"])
                CurrentXP = tonumber(result[1]["xp"])
                CurrentRank = tonumber(result[1]["rank"])                
                    
                if Config.Leaderboard.Enabled then
                    FetchGangs(_source, CurrentID, CurrentXP, CurrentRank)
                    TriggerEvent("brt_gangxp:getGangsData")
                else
                    TriggerClientEvent("brt_gangxp:init", _source, CurrentID, CurrentXP, CurrentRank, false)
                    TriggerEvent("brt_gangxp:getGangsData")
                end
            end
        end)
    end
end)

function GetGangs(gangs)
    local AllGangs = {}
    for k, v in pairs(gangs) do
        local gang = {
            name = v.gang_name,
            id = v.ID,
            xp = v.xp,
            rank = v.rank,
        }
        
        table.insert(AllGangs, gang)
    end
    return AllGangs
end

function FetchGangs(_source, CurrentID, CurrentXP, CurrentRank)
    MySQL.Async.fetchAll('SELECT gang_name, ID, xp, rank FROM gangs_data', {}, function(gangs)
        if #gangs > 0 then
            TriggerClientEvent("brt_gangxp:init", _source, CurrentID, CurrentXP, CurrentRank, GetGangs(gangs))
        end
    end)
end

function GetRank(_xp)
    local len = #Config.Ranks
    for rank = 1, len do
        if rank < len then
            if Config.Ranks[rank + 1] > tonumber(_xp) then
                return rank
            end
        else
            return rank
        end
    end
end	

function IsInt(XPCheck)
    XPCheck = tonumber(XPCheck)
    if XPCheck and XPCheck == math.floor(XPCheck) then
        return true
    end
    return false
end

function LimitXP(XPCheck)
    local Max = tonumber(Config.Ranks[#Config.Ranks])

    if XPCheck > Max then
        XPCheck = Max
    elseif XPCheck < 0 then
        XPCheck = 0
    end

    return tonumber(XPCheck)
end

RegisterNetEvent("brt_gangxp:setXP")
AddEventHandler("brt_gangxp:setXP", function(_xp, _rank, GangName)
    _xp = tonumber(_xp)
    _rank = tonumber(_rank)

    MySQL.Async.fetchAll('SELECT rank FROM gangs_data WHERE gang_name = @gang', {
        ['@gang'] = GangName
    }, function(result)
        if #result > 0 then
            local oldRank = tonumber(result[1]["rank"])                
            if _rank > oldRank then
                for i = oldRank + 1, _rank do
                    TriggerEvent('brt_gangxp:getNewLevel', i, GangName)
                end
            end
        end
    end)

    MySQL.Async.execute('UPDATE gangs_data SET xp = @xp, rank = @rank WHERE gang_name = @gang', {
        ['@gang'] = GangName,
        ['@xp'] = _xp,
        ['@rank'] = _rank
    }, function(result)
        CurrentXP = tonumber(_xp)
        CurrentRank = tonumber(_rank)
        local xPlayers, xP = BR.GetPlayers(), nil
		for i=1, #xPlayers, 1 do
			xPlayer = BR.GetPlayerFromId(xPlayers[i])
			if xPlayer.gang.name == GangName then
                TriggerClientEvent("brt_gangxp:update", xPlayers[i], CurrentXP, CurrentRank)
			end
		end
        TriggerEvent("brt_gangxp:getGangsData")
    end)
end)

function UpdatePlayer(GangName, xp)
    CurrentXP = tonumber(xp)
    CurrentRank = GetRank(CurrentXP)

    MySQL.Async.fetchAll('SELECT rank FROM gangs_data WHERE gang_name = @gang', {
        ['@gang'] = GangName
    }, function(result)
        if #result > 0 then
            local oldRank = tonumber(result[1]["rank"])                
            if CurrentRank > oldRank then
                for i = oldRank + 1, CurrentRank do
                    TriggerEvent('brt_gangxp:getNewLevel', i, GangName)
                end
            end
        end
    end)

    MySQL.Async.execute('UPDATE gangs_data SET xp = @xp, rank = @rank WHERE gang_name = @gang', {
        ['@gang'] = GangName,
        ['@xp'] = CurrentXP,
        ['@rank'] = CurrentRank
    }, function(result)
        local xPlayers, xPlayer = BR.GetPlayers(), nil
		for i=1, #xPlayers, 1 do
			xPlayer = BR.GetPlayerFromId(xPlayers[i])
			if xPlayer.gang.name == GangName then
                TriggerClientEvent("brt_gangxp:update", xPlayers[i], CurrentXP, CurrentRank)
			end
		end
    end)

    TriggerEvent("brt_gangxp:getGangsData")
end

RegisterNetEvent("brt_gangxp:getGangsData")
AddEventHandler("brt_gangxp:getGangsData", function()
    MySQL.Async.fetchAll('SELECT * FROM gangs_data', {}, function(gangs)
        if #gangs > 0 then
            local xPlayers, xPlayer = BR.GetPlayers(), nil
            for i=1, #xPlayers, 1 do
                xPlayer = BR.GetPlayerFromId(xPlayers[i])
                if xPlayer.gang.name ~= 'nogang' then
                    TriggerClientEvent("brt_gangxp:setPlayerData", xPlayers[i], GetGangs(gangs))
                end
            end
        end
    end)
end)

AddEventHandler("brt_gangxp:addXP", function(GangName, XPAdd)
    if IsInt(XPAdd) then
        local NewXP = CurrentXP + XPAdd
        UpdatePlayer(GangName, LimitXP(NewXP))
    end
end)

AddEventHandler("brt_gangxp:removeXP", function(GangName, XPRemove)
    if IsInt(XPRemove) then
        local NewXP = CurrentXP - XPRemove
        UpdatePlayer(GangName, LimitXP(NewXP))
    end
end)

RegisterServerEvent('brt_gangxp:giveGangVehicle')
AddEventHandler('brt_gangxp:giveGangVehicle', function (vehicleProps, GangName)
	local _source = source
	MySQL.Async.execute('INSERT INTO owned_vehicles (owner, modelname, plate, vehicle, job) VALUES (@owner, @model, @plate, @vehicle, @job)', {
		['@owner']   = GangName,
        ['@model']   = BR.GetVehicleLabelFromHash(vehicleProps.model),
		['@plate']   = vehicleProps.plate,
		['@vehicle'] = json.encode(vehicleProps),
		['@job']	 = 'gang'
	}, function (rowsChanged)
        if rowsChanged > 0 then
            TriggerEvent('brt_advancedgarage:setVehicleState', vehicleProps.plate, true)
            local xPlayers, xPlayer = BR.GetPlayers(), nil
            for i=1, #xPlayers, 1 do
                xPlayer = BR.GetPlayerFromId(xPlayers[i])
                if xPlayer.gang.name == GangName then
                    TriggerClientEvent('brt:showNotification', xPlayers[i], "VasileNaghlie Ba Pelak ~g~"..vehicleProps.plate.. " ~s~Baraye Rank Up Shodan Be Gang Shoma Ezafe Shod")
                end
            end
        end
	end)
end)

RegisterNetEvent("brt_gangxp:getNewLevel")
AddEventHandler("brt_gangxp:getNewLevel", function(rank, GangName)
    if rank > 1 and rank < 11 then
        MySQL.Async.execute('UPDATE gangs_data SET slot = slot + 1 WHERE gang_name = @gang', {['@gang'] = GangName})
        MySQL.Async.execute('UPDATE gangs_data SET garage_limit = garage_limit + 2 WHERE gang_name = @gang', {['@gang'] = GangName})
        if rank == 2 then
            AddGun(GangName, 'WEAPON_SNSPISTOL', 3)
            AddItem(GangName, 'water', 20)
            AddItem(GangName, 'bread', 20)
            AddItem(GangName, 'coffee', 10)
            AddMoney(GangName, 10000)
            local Gived = false
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(2000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^22 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'exemplar', GangName)
                        Gived = true
                    end
                end
            end
        elseif rank == 3 then
            local Gived = false
            ChangeVest(GangName, 60, 7000)
            AddGun(GangName, 'WEAPON_SNSPISTOL', 5)
            AddItem(GangName, 'water', 25)
            AddItem(GangName, 'bread', 25)
            AddItem(GangName, 'coffee', 15)
            AddMoney(GangName, 15000)
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(3000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^23 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'dubsta2', GangName)
                        Gived = true
                    end
                end
            end
        elseif rank == 4 then
            local Gived = false
            ChangeVest(GangName, 70, 6000)
            AddGun(GangName, 'WEAPON_SNSPISTOL', 3)
            AddGun(GangName, 'WEAPON_PISTOL', 2)
            AddItem(GangName, 'water', 30)
            AddItem(GangName, 'bread', 30)
            AddItem(GangName, 'coffee', 20)
            AddMoney(GangName, 20000)
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(4000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^24 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'neon', GangName)
                        Gived = true
                    end
                end
            end
        elseif rank == 5 then
            local Gived = false
            ChangeVest(GangName, 80, 5000)
            AddGun(GangName, 'WEAPON_SNSPISTOL', 4)
            AddGun(GangName, 'WEAPON_PISTOL', 3)
            AddItem(GangName, 'water', 35)
            AddItem(GangName, 'bread', 35)
            AddItem(GangName, 'coffee', 25)
            AddMoney(GangName, 25000)
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(5000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^25 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'ninef', GangName)
                        Gived = true
                    end
                end
            end
        elseif rank == 6 then
            local Gived = false
            ChangeVest(GangName, 80, 4000)
            AddGun(GangName, 'WEAPON_SMG', 2)
            AddItem(GangName, 'water', 40)
            AddItem(GangName, 'bread', 40)
            AddItem(GangName, 'coffee', 30)
            AddMoney(GangName, 30000)
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(6000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^26 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'baller6', GangName)
                        Gived = true
                    end
                end
            end
        elseif rank == 7 then
            local Gived = false
            ChangeVest(GangName, 80, 3000)
            AddGun(GangName, 'WEAPON_SMG', 2)
            AddGun(GangName, 'WEAPON_MICROSMG', 1)
            AddItem(GangName, 'water', 45)
            AddItem(GangName, 'bread', 45)
            AddItem(GangName, 'coffee', 35)
            AddMoney(GangName, 35000)
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(7000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^27 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'nero', GangName)
                        Gived = true
                    end
                end
            end
        elseif rank == 8 then
            local Gived = false
            ChangeVest(GangName, 80, 3000)
            AddGun(GangName, 'WEAPON_SMG', 2)
            AddGun(GangName, 'WEAPON_MICROSMG', 2)
            AddItem(GangName, 'water', 50)
            AddItem(GangName, 'bread', 50)
            AddItem(GangName, 'coffee', 40)
            AddMoney(GangName, 40000)
            MySQL.Async.execute('UPDATE gangs_data SET lockpick = 1 WHERE gang_name = @gang', {
                ['@gang'] = GangName
            })
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(8000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^28 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'toros', GangName)
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'kuruma2', GangName)
                        Gived = true
                    end
                end
            end
        elseif rank == 9 then
            local Gived = false
            ChangeVest(GangName, 80, 2000)
            AddGun(GangName, 'WEAPON_ASSAULTRIFLE', 2)
            AddItem(GangName, 'water', 55)
            AddItem(GangName, 'bread', 55)
            AddItem(GangName, 'coffee', 45)
            AddMoney(GangName, 45000)
            MySQL.Async.execute('UPDATE gangs_data SET helicopter = 1 WHERE gang_name = @gang', {
                ['@gang'] = GangName
            })
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(9000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^29 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'zentorno', GangName)
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'voltic', GangName)
                        Gived = true
                    end
                end
            end
        elseif rank == 10 then
            local Gived = false
            ChangeVest(GangName, 80, 0)
            AddGun(GangName, 'WEAPON_GUSENBERG', 2)
            AddItem(GangName, 'water', 60)
            AddItem(GangName, 'bread', 60)
            AddItem(GangName, 'coffee', 50)
            AddMoney(GangName, 50000)
            MySQL.Async.execute('UPDATE gangs_data SET gps = 1 WHERE gang_name = @gang', {
                ['@gang'] = GangName
            })
            local aPlayers = BR.GetPlayers()
            for i=1, #aPlayers, 1 do
                local GangMember = BR.GetPlayerFromId(aPlayers[i])
                if GangMember.gang.name == GangName then
                    GangMember.setGang(GangName, GangMember.gang.grade)
                    GangMember.addMoney(10000)
                    TriggerClientEvent('chatMessage', aPlayers[i], "[GANG SYSTEM]", {255, 0, 0}, " ^0Gang Shoma Be Rank ^210 ^0Resid. Jahat Etela Az Javayeze Daryafti, ^1PDF XPGang ^0Ra Az ^2Discord ^0Server Moshahede Namayiid")
                    if not Gived then
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'visione', GangName)
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'caracara2', GangName)
                        TriggerClientEvent('addGangCarXP', aPlayers[i], 'Mgt', GangName)
                        Gived = true
                    end
                end
            end
        end
    end
end)


function ChangeVest(gang, meghdar, gheymat)
    MySQL.Async.execute('UPDATE gangs_data SET bulletproof = @bulletproof, vest_price = @vest_price WHERE gang_name = @gang', {
        ['@gang'] = gang,
        ['@bulletproof'] = meghdar,
        ['@vest_price'] = gheymat
    })
end

function AddGun(gang, aslahe, tedad)
    for i=1, tedad do
        TriggerEvent('brt_datastore:getSharedDataStore', 'gang_'..string.lower(gang), function(store)
            local storeWeapons = store.get('weapons') or {}
            table.insert(storeWeapons, {
                name = aslahe,
                ammo = 250
            })
            store.set('weapons', storeWeapons)
        end)
    end
end

function AddItem(gang, item, tedad)
    TriggerEvent('brt_addoninventory:getSharedInventory', 'gang_'..string.lower(gang), function(inventory)
        inventory.addItem(item, tedad)
    end)
end

function AddMoney(gang, meghdar)
    TriggerEvent('gangaccount:getGangAccount', 'gang_'..string.lower(gang), function(account)
        account.addMoney(meghdar)
    end)
end