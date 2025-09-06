local QBCore = exports['qb-core']:GetCoreObject()

---@class TaxiService
local TaxiService = {
    activeRentals = {},   -- [src] = { companyId, plate, model, index, endTime }
    companyFunds = {},    -- [cid] = number
    plates = {},          -- { {companyId, plate} }
    taxiMeters = {}       -- [plate] = { fare, total }
}

TaxiService.__index = TaxiService
local Taxi = setmetatable({}, TaxiService)

local function notify(src, msg, type_)
    TriggerClientEvent("crimson_taxi:client:notify", src, msg, type_ or "inform")
end

function Taxi:getFunds(cid)
    if self.companyFunds[cid] ~= nil then return self.companyFunds[cid] end
    local row = MySQL.single.await("SELECT funds FROM taxi_owner WHERE company_id=? LIMIT 1", {cid})
    if not row then
        MySQL.insert.await("INSERT INTO taxi_owner (company_id,funds) VALUES (?,0)", {cid})
        self.companyFunds[cid] = 0
    else
        self.companyFunds[cid] = row.funds or 0
    end
    return self.companyFunds[cid]
end

function Taxi:setFunds(cid, amount)
    self.companyFunds[cid] = math.max(amount,0)
    MySQL.update.await("UPDATE taxi_owner SET funds=? WHERE company_id=?", { self.companyFunds[cid], cid })
end

function Taxi:addFunds(cid, amt) self:setFunds(cid, self:getFunds(cid) + (amt or 0)) end
function Taxi:removeFunds(cid, amt)
    local cur = self:getFunds(cid)
    if cur >= amt then
        self:setFunds(cid, cur - amt)
        return true
    end
    return false
end

function Taxi:rentTaxi(src, cid, model, idx, hours)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if self.activeRentals[src] then return notify(src, "Bạn đã có xe thuê rồi!", "error") end

    local comp = Config.Companies[cid]
    local veh = comp and comp.rentVehicles and comp.rentVehicles[idx]
    if not veh or veh.rented then return notify(src, "Xe không khả dụng!", "error") end

    local cost = (veh.price or 0) * (hours or 1)
    if not Player.Functions.RemoveMoney("cash", cost, "taxi-rental") then
        return notify(src, "Không đủ tiền!", "error")
    end

    local plate = ("TAXI%04d"):format(math.random(0,9999))
    self.activeRentals[src] = { companyId=cid, plate=plate, model=model, index=idx, endTime=os.time()+(hours*3600) }

    veh.rented = true
    self:addFunds(cid, cost)
    TriggerClientEvent("crimson_taxi:client:spawnTaxi", src, plate, model, hours*3600, cid)
    TriggerClientEvent("crimson_taxi:client:updateRentalState", -1, cid, idx, true)
    TriggerClientEvent("crimson_taxi:client:setRental", src, self.activeRentals[src])
    notify(src, ("Đã trừ %s$ cho %s giờ thuê"):format(cost,hours), "success")
end

function Taxi:clearRental(src, rental, timeout)
    local comp = Config.Companies[rental.companyId]
    if comp and comp.rentVehicles and comp.rentVehicles[rental.index] then
        comp.rentVehicles[rental.index].rented = false
        TriggerClientEvent("crimson_taxi:client:updateRentalState", -1, rental.companyId, rental.index, false)
    end
    if timeout then 
        notify(src,"Hết giờ thuê xe!","error")
    else 
        notify(src,"Bạn đã trả xe thành công!","success") 
    end
    TriggerClientEvent("crimson_taxi:client:deleteRentedVehicle", src, rental.plate)
    TriggerClientEvent("crimson_taxi:client:clearRental", src)
    TriggerClientEvent("crimson_taxi:client:setRental", src, nil)
    TriggerClientEvent("crimson_taxi:client:cancelRental", src)

    self.activeRentals[src] = nil
end

function Taxi:returnTaxi(src, plate)
    local rental = self.activeRentals[src]
    if not rental or rental.plate ~= plate then 
        return notify(src,"Bạn không thuê xe này!","error") 
    end
    self:clearRental(src, rental, false)
end

function Taxi:returnTimeout(src)
    local rental = self.activeRentals[src]
    if rental then self:clearRental(src, rental, true) end
end

function Taxi:openFundsMenu(src, cid)
    TriggerClientEvent("crimson_taxi:client:openFundsMenu", src, cid, self:getFunds(cid))
end

function Taxi:depositFunds(src, cid, amt)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or amt<=0 then return end
    if P.Functions.RemoveMoney("cash", amt, "taxi-deposit") then
        self:addFunds(cid, amt)
        notify(src, ("Đã nạp %s$ vào quỹ"):format(amt), "success")
        self:openFundsMenu(src,cid)
    else
        notify(src,"Không đủ tiền mặt","error")
    end
end

function Taxi:withdrawFunds(src, cid, amt)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or amt<=0 then return end
    if self:removeFunds(cid, amt) then
        P.Functions.AddMoney("cash", amt, "taxi-withdraw")
        notify(src, ("Đã rút %s$ từ quỹ"):format(amt), "success")
        self:openFundsMenu(src,cid)
    else
        notify(src,"Quỹ không đủ tiền","error")
    end
end


RegisterNetEvent("crimson_taxi:server:syncMeter", function(plate, fare, total)
    Taxi.taxiMeters[plate] = {fare=fare,total=total}
    local src=source
    local veh=GetVehiclePedIsIn(GetPlayerPed(src),false)
    if veh and veh~=0 then
        for _,player in pairs(GetPlayers()) do
            if GetVehiclePedIsIn(GetPlayerPed(player),false)==veh then
                TriggerClientEvent("crimson_taxi:client:updateMeterData", player, fare,total)
            end
        end
    end
end)

RegisterNetEvent("crimson_taxi:server:requestMeter", function(plate)
    local src=source
    local data=Taxi.taxiMeters[plate] or {fare=0,total=0,pricePer100m=50}
    TriggerClientEvent("crimson_taxi:client:spawnTaxiMeter", src, data)
end)

RegisterNetEvent("crimson_taxi:server:rentTaxi",      function(cid,model,idx,h) Taxi:rentTaxi(source,cid,model,idx,h) end)
RegisterNetEvent("crimson_taxi:server:returnTaxi",    function(plate) Taxi:returnTaxi(source,plate) end)
RegisterNetEvent("crimson_taxi:server:returnTimeout", function() Taxi:returnTimeout(source) end)
RegisterNetEvent("crimson_taxi:server:openFundsMenu", function(cid) Taxi:openFundsMenu(source,cid) end)
RegisterNetEvent("crimson_taxi:server:depositFunds",  function(cid,amt) Taxi:depositFunds(source,cid,tonumber(amt or 0)) end)
RegisterNetEvent("crimson_taxi:server:withdrawFunds", function(cid,amt) Taxi:withdrawFunds(source,cid,tonumber(amt or 0)) end)

--==================== Crimson Taxi NPC (SERVER) ====================--
local TaxiNPC = {}
TaxiNPC.__index = TaxiNPC

function TaxiNPC:new()
    local self = setmetatable({}, TaxiNPC)
    self.orders = {}
    self.playerOrders = {}
    return self
end

function TaxiNPC:generateOrders()
    math.randomseed(os.time() + GetGameTimer())
    local orders = {}
    for i = 1, 10 do
        local pick = Config.NpcTaxi.PickLocations[math.random(#Config.NpcTaxi.PickLocations)]
        local drop = Config.NpcTaxi.DropLocations[math.random(#Config.NpcTaxi.DropLocations)]
        orders[i] = { id = i, pick = pick, drop = drop, status = "available", taker = nil }
    end
    self.orders = orders
end

function TaxiNPC:syncAll(target)
    if target then
        TriggerClientEvent("crimson_taxi:client:setOrders", target, self.orders)
    else
        TriggerClientEvent("crimson_taxi:client:setOrders", -1, self.orders)
    end
end

function TaxiNPC:playerHasOrder(src)
    return self.playerOrders[src] ~= nil
end

function TaxiNPC:takeOrder(src, id)
    id = tonumber(id)
    local order = self.orders[id]
    if not order then
        TriggerClientEvent("crimson_taxi:client:takeResult", src, false, "not_found", id)
        return
    end
    if self:playerHasOrder(src) then
        TriggerClientEvent("crimson_taxi:client:takeResult", src, false, "already_has_order", id)
        return
    end
    if order.status ~= "available" then
        TriggerClientEvent("crimson_taxi:client:takeResult", src, false, "not_available", id)
        return
    end
    order.status = "taken"
    order.taker = src
    self.playerOrders[src] = id
    self:syncAll()
    TriggerClientEvent("crimson_taxi:client:updateOrder", src, {
        id = id, pick = order.pick, drop = order.drop, status = "yours"
    })
    TriggerClientEvent("crimson_taxi:client:takeResult", src, true, nil, id)
end

function TaxiNPC:cancelOrder(src, id)
    id = tonumber(id)
    local order = self.orders[id]
    if not order then
        TriggerClientEvent("crimson_taxi:client:cancelResult", src, false, "not_found")
        return
    end
    if order.taker ~= src then
        TriggerClientEvent("crimson_taxi:client:cancelResult", src, false, "not_taker")
        return
    end
    order.status = "available"
    order.taker = nil
    self.playerOrders[src] = nil
    self:syncAll()
    TriggerClientEvent("crimson_taxi:client:updateOrder", src, nil)
    TriggerClientEvent("crimson_taxi:client:cancelResult", src, true)
end

function TaxiNPC:finishOrder(src, id)
    id = tonumber(id)
    local order = self.orders[id]
    if not order then
        TriggerClientEvent("crimson_taxi:client:completeResult", src, false, "not_found")
        return
    end
    if order.taker ~= src then
        TriggerClientEvent("crimson_taxi:client:completeResult", src, false, "not_taker")
        return
    end
    local dist = #(order.pick.coords - order.drop.coords)
    local fare = math.floor(dist / 100 * (Config.MeterPrice and Config.MeterPrice.per100m or 50))
    exports.ox_inventory:AddItem(src, "money", fare)
    self.orders[id] = nil
    self.playerOrders[src] = nil
    self:syncAll()
    TriggerClientEvent("crimson_taxi:client:updateOrder", src, nil)
    TriggerClientEvent("crimson_taxi:client:completeResult", src, true, fare)
    SetTimeout(120000, function()
        local pick = Config.NpcTaxi.PickLocations[math.random(#Config.NpcTaxi.PickLocations)]
        local drop = Config.NpcTaxi.DropLocations[math.random(#Config.NpcTaxi.DropLocations)]
        self.orders[id] = { id = id, pick = pick, drop = drop, status = "available", taker = nil }
        print(("[DEBUG] TaxiNPC: Respawned order #%s"):format(id))
        self:syncAll()
    end)
end

TaxiNPC.Server = TaxiNPC:new()

RegisterNetEvent("crimson_taxi:server:takeOrder", function(id) TaxiNPC.Server:takeOrder(source, id) end)
RegisterNetEvent("crimson_taxi:server:cancelOrder", function(id) TaxiNPC.Server:cancelOrder(source, id) end)
RegisterNetEvent("crimson_taxi:server:finishOrder", function(id) TaxiNPC.Server:finishOrder(source, id) end)
--==================== Crimson Taxi NPC (SERVER) ====================--

local function syncOwners(target)
    local rows = MySQL.query.await("SELECT company_id, citizenid, funds FROM taxi_owner")
    local owners = {}
    for _, r in ipairs(rows or {}) do
        owners[r.company_id] = { citizenid = r.citizenid, funds = r.funds }
    end
    if target then
        TriggerClientEvent("crimson_taxi:client:setOwners", target, owners)
    else
        TriggerClientEvent("crimson_taxi:client:setOwners", -1, owners)
    end
end

local function parseArgs(a, b, c)
    if type(a) == "number" and type(b) == "string" then
        return a, b, c
    else
        return source, a, b
    end
end

RegisterNetEvent("crimson_taxi:server:buyCompany", function(a, b, c)
    local src, companyId, price = parseArgs(a, b, c)
    if not src or not companyId or not price then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local row = MySQL.single.await("SELECT * FROM taxi_owner WHERE company_id=?", {companyId})
    if not row or not row.citizenid then
        if Player.Functions.GetMoney("bank") < price then
            return notify(src, "Không đủ tiền ngân hàng!", "error")
        end
        Player.Functions.RemoveMoney("bank", price, "Mua công ty taxi")

        if row then
            MySQL.update.await("UPDATE taxi_owner SET citizenid=?, sell_price=NULL WHERE company_id=?", {citizenid, companyId})
        else
            MySQL.insert.await("INSERT INTO taxi_owner (company_id, funds, citizenid) VALUES (?, ?, ?)", {companyId, 0, citizenid})
        end

        notify(src, ("Bạn đã mua công ty %s với giá $%s"):format(companyId, price), "success")
        syncOwners()
        return
    end
    if row.sell_price and row.sell_price > 0 and row.citizenid ~= citizenid then
        if Player.Functions.GetMoney("bank") < row.sell_price then
            return notify(src, "Không đủ tiền để mua", "error")
        end
        Player.Functions.RemoveMoney("bank", row.sell_price, "Mua lại công ty taxi")
        local seller = QBCore.Functions.GetPlayerByCitizenId(row.citizenid)
        if seller then
            seller.Functions.AddMoney("bank", row.sell_price, "Bán công ty taxi")
        else
            MySQL.update.await("UPDATE players SET bank = bank + ? WHERE citizenid = ?", {row.sell_price, row.citizenid})
        end
        MySQL.update.await("UPDATE taxi_owner SET citizenid=?, sell_price=NULL WHERE company_id=?", {citizenid, companyId})
        notify(src, ("Bạn đã mua lại công ty %s với giá $%s"):format(companyId, row.sell_price), "success")
        syncOwners()
        return
    end
    notify(src, "Công ty này không bán hoặc bạn đã là chủ!", "error")
end)

RegisterNetEvent("crimson_taxi:server:sellCompany", function(a, b, c)
    local src, companyId, sellPrice = parseArgs(a, b, c)
    if not src or not companyId or not sellPrice then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local row = MySQL.single.await("SELECT * FROM taxi_owner WHERE company_id=?", {companyId})

    if not row or row.citizenid ~= citizenid then
        return notify(src, "Bạn không phải chủ công ty này!", "error")
    end
    if (row.funds or 0) > 0 then
        return notify(src, "Không thể bán khi quỹ công ty còn tiền!", "error")
    end

    MySQL.update.await("UPDATE taxi_owner SET sell_price=? WHERE company_id=?", {sellPrice, companyId})
    notify(src, ("Bạn đã rao bán công ty %s với giá $%s"):format(companyId, sellPrice), "success")
end)

QBCore.Commands.Add("buytaxi", "Mua công ty taxi", {}, false, function(src)
    TriggerEvent("crimson_taxi:server:buyCompany", src, "CRS", 500000)
end)

QBCore.Commands.Add("selltaxi", "Rao bán công ty taxi với giá mong muốn", {
    {name = "price", help = "Giá bán"}
}, false, function(src, args)
    local price = tonumber(args[1])
    if not price or price <= 0 then
        return notify(src, "Nhập giá bán hợp lệ!", "error")
    end
    TriggerEvent("crimson_taxi:server:sellCompany", src, "CRS", price)
end)

AddEventHandler("playerDropped", function()
    local src = source
    local rental = Taxi.activeRentals[src]
    if rental then Taxi:clearRental(src, rental, true) end
    if TaxiNPC.Server.playerOrders[src] then
        TaxiNPC.Server:cancelOrder(src, TaxiNPC.Server.playerOrders[src])
    end
end)

AddEventHandler("QBCore:Server:PlayerLoaded", function(player)
    local src = player.PlayerData.source
    for _, rental in pairs(Taxi.activeRentals) do
        TriggerClientEvent("crimson_taxi:client:updateRentalState", src, rental.companyId, rental.index, true)
    end

    syncOwners(src)
    TaxiNPC.Server:syncAll(src)
end)

AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        TaxiNPC.Server:generateOrders()
        Wait(500)
        syncOwners()
        TaxiNPC.Server:syncAll()
    end)
end)

