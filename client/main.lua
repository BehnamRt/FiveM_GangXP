CurrentID = nil
CurrentXP = 0
CurrentRank = 0
Leaderboard = nil
Players = {}
Player = nil
UIActive = true
BR = nil
PlayerData = {}
Ready = false

Citzen.CreateThread(function()
    while BR == nil do
        Citzen.Wait(10)
        TriggerEvent('brt:getSharedObject', function(obj) BR = obj end)
    end
    
    while not BR.IsPlayerLoaded() do
        Citzen.Wait(10)
    end

    while BR.GetPlayerData() == nil do
        Citzen.Wait(10)
    end

    while BR.GetPlayerData().gang == nil do
        Citzen.Wait(10)
    end 

    PlayerData = BR.GetPlayerData()
    
    TriggerServerEvent("brt_gangxp:sync")
end)

RegisterNetEvent('brt:setGang')
AddEventHandler('brt:setGang', function(gang)
    PlayerData.gang = gang
    TriggerServerEvent("brt_gangxp:sync")
    Wait(1000)
    if PlayerData.gang.name ~= 'nogang' then
        TriggerEvent("brt_gangxp:update", CurrentXP, BRT_GetRank(CurrentXP))
    end
end)

AddEventHandler('brt_gangxp:isReady', function(cb)
    cb(Ready)
end)

RegisterNetEvent("brt_gangxp:init")
AddEventHandler("brt_gangxp:init", function(_id, _xp, _rank, gangs)
    local Ranks = CheckRanks()
    if #Ranks == 0 then
        CurrentID = tonumber(_id)
        CurrentXP = tonumber(_xp)
        CurrentRank = tonumber(_rank)

        local data = {
            xpm_init = true,
            xpm_config = Config,
            currentID = CurrentID,
            xp = CurrentXP
        }
    
        if Config.Leaderboard.Enabled and gangs then
            data.leaderboard = true
            data.players = gangs

            for k, v in pairs(gangs) do
                if v.gang_name == PlayerData.gang.name then
                    Player = v
                end
            end        
    
            Players = gangs                       
        end
    
        SendNUIMessage(data)
    
        StatSetInt("MPPLY_GLOBALXP", CurrentXP, 1)

        Ready = true
    end
end)

RegisterNetEvent("brt_gangxp:update")
AddEventHandler("brt_gangxp:update", function(_xp, _rank)
    local oldRank = CurrentRank
    local newRank = _rank
    local newXP = _xp

    SendNUIMessage({
        xpm_set = true,
        xp = newXP
    })

    CurrentXP = newXP
    CurrentRank = newRank
end)

if Config.Leaderboard.Enabled then
    RegisterNetEvent("brt_gangxp:setPlayerData")
    AddEventHandler("brt_gangxp:setPlayerData", function(gangs)
        for k, v in pairs(gangs) do
            table.insert(Players, v)

            if v.gang_name == PlayerData.gang.name then
                Player = v
            end     
        end

        SendNUIMessage({
            xpm_updateleaderboard = true,
            xpm_players = gangs
        })
    end)
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

function CheckRanks()
    local Limit = #Config.Ranks
    local InValid = {}

    for i = 1, Limit do
        local RankXP = Config.Ranks[i]

        if not IsInt(RankXP) then
            table.insert(InValid, _('err_lvl_check', i,  RankXP))
        end
        
    end

    return InValid
end

function SortLeaderboard(players, order)
    if order == nil then
        order = Config.Leaderboard.Order
    end

    if order == "rank" then
        table.sort(players, function(a,b)
            return a.rank > b.rank
        end)
    elseif order == "id" then
        table.sort(players, function(a,b)
            return a.id > b.id
        end)                      
    elseif order == "name" then
        table.sort(players, function(a,b)
            return a.name < b.name
        end)                
    end    
end

function IsInt(XPCheck)
    XPCheck = tonumber(XPCheck)
    if XPCheck and XPCheck == math.floor(XPCheck) then
        return true
    end
    return false
end

function UpdateXP(_xp, init, GangName)
    _xp = tonumber(_xp)

    local points = CurrentXP + _xp
    local max = BRT_GetMaxXP()

    if init then
        points = _xp
    end

    points = LimitXP(points)

    local rank = BRT_GetRank(points)

    TriggerServerEvent("brt_gangxp:setXP", points, rank, GangName)
end


function BRT_SetInitial(XPInit, GangName)
    local GoalXP = tonumber(XPInit)
    if not GoalXP or (GoalXP < 0 or GoalXP > BRT_GetMaxXP()) then
        return
    end    
    UpdateXP(tonumber(GoalXP), true, GangName)
end

function BRT_SetRank(Rank, GangName)
    local GoalRank = tonumber(Rank)

    if not GoalRank then
        return
    end

    local XPAdd = tonumber(Config.Ranks[GoalRank]) - CurrentXP

    BRT_Add(XPAdd, GangName)
end

function BRT_Add(XPAdd, GangName)
    if not tonumber(XPAdd) then
        return
    end       
    UpdateXP(tonumber(XPAdd), false, GangName)
end

function BRT_Remove(XPRemove, GangName)
    if not tonumber(XPRemove) then
        return
    end       
    UpdateXP(-(tonumber(XPRemove)), false, GangName)
end

function BRT_GetRank(_xp)

    if _xp == nil then
        return CurrentRank
    end

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

function BRT_GetXPToNextRank()
    local currentRank = BRT_GetRank()

    return Config.Ranks[currentRank + 1] - tonumber(CurrentXP)   
end


function BRT_GetXPToRank(Rank)
    local GoalRank = tonumber(Rank)
    if not GoalRank or (GoalRank < 1 or GoalRank > #Config.Ranks) then
        return
    end

    local goalXP = tonumber(Config.Ranks[GoalRankl])

    return goalXP - CurrentXP
end

function BRT_GetXP()
    return tonumber(CurrentXP)
end

function BRT_GetMaxXP()
    return Config.Ranks[#Config.Ranks]
end

function BRT_GetMaxRank()
    return #Config.Ranks
end

function BRT_ShowUI(update)
    UIActive = true

    if update ~= nil then
        TriggerServerEvent("brt_gangxp:getGangsData")
    end
    
    SendNUIMessage({
        xpm_show = true
    })    
end

function BRT_HideUI()
    UIActive = false
        
    SendNUIMessage({
        xpm_hide = true
    })      
end

function BRT_TimeoutUI(update)
    UIActive = true

    if update ~= nil then
        TriggerServerEvent("brt_gangxp:getGangsData")
    end
    
    SendNUIMessage({
        xpm_display = true
    })    
end

function BRT_SortLeaderboard(type)
    SendNUIMessage({
        xpm_lb_sort = true,
        xpm_lb_order = "xp"
    })   
end

AddEventHandler("onKeyDown", function(key)
	if key == "z" then
		if PlayerData.gang.name ~= 'nogang' then
            UIActive = not UIActive
            
            if UIActive then
                TriggerServerEvent("brt_gangxp:getGangsData")
                SendNUIMessage({
                    xpm_show = true
                })                 
            else
                SendNUIMessage({
                    xpm_hide = true
                })                
            end
        else
            BR.ShowNotification('Shoma Ozv Hich Gangi Jahat Didan XP Va Leaderboard Nistid')
        end
	end
end)

RegisterNetEvent("brt_gangxp:updateUI")
AddEventHandler("brt_gangxp:updateUI", function(_xp)
    CurrentXP = tonumber(_xp)

    SendNUIMessage({
        xpm_set = true,
        xp = CurrentXP
    })
end)

RegisterNetEvent("brt_gangxp:SetInitial")
AddEventHandler('brt_gangxp:SetInitial', function(XP, GangName)
    BRT_SetInitial(XP, GangName)
end)

RegisterNetEvent("brt_gangxp:Add")
AddEventHandler('brt_gangxp:Add', function(XP, GangName)
    BRT_Add(XP, GangName)
end)

RegisterNetEvent("brt_gangxp:Remove")
AddEventHandler('brt_gangxp:Remove', function(XP, GangName)
    BRT_Remove(XP, GangName)
end)

RegisterNetEvent("brt_gangxp:SetRank")
AddEventHandler('brt_gangxp:SetRank', function(Rank, GangName)
    BRT_SetRank(Rank, GangName)
end)

--[[RegisterNUICallback('behnam_rankchange', function(data)
    if data.rankUp then
        TriggerServerEvent("brt_gangxp:getGangsData")
        if data.current > data.previous then
            TriggerServerEvent('brt_gangxp:getNewLevel', data.current)
        end
    else
        TriggerServerEvent("brt_gangxp:getGangsData")
    end
end)--]]


RegisterNetEvent('addGangCarXP')
AddEventHandler('addGangCarXP', function(model, GangName)
    local playerPed = PlayerPedId()
	local coords    = GetEntityCoords(playerPed)
    BR.Game.SpawnVehicle(model, coords, 0.0, function(vehicle)
		if DoesEntityExist(vehicle) then
			SetVisible(vehicle, false, false)
			SetEntityCollision(vehicle, false)
			
			local vehicleProps = BR.Game.GetVehicleProperties(vehicle)
            local newPlate = exports.BR_vehicleshop:GeneratePlate()
			vehicleProps.plate = newPlate
            TriggerServerEvent('brt_gangxp:giveGangVehicle', vehicleProps, GangName)
			BR.Game.DeleteVehicele(vehicle)				
		end		
	end)
end)