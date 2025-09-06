local QBCore = exports['qb-core']:GetCoreObject()
local function notify(msg, type_)
    if lib and lib.notify then
        lib.notify({ description = msg, type = type_ or "inform", position = "center-right" })
    else
        QBCore.Functions.Notify(msg, type_ or "primary")
    end
end

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then print("^1[crimson_taxi] error: ^7" .. tostring(err)) end
end

local TaxiMeter = {}
TaxiMeter.__index = TaxiMeter

function TaxiMeter:new(pricePer100m, manager)
    return setmetatable({
        enabled = false,
        running = false,
        lastPos = nil,
        fare = 0,
        total = 0, 
        pricePer100m = pricePer100m or 50,
        renterPlate = nil,
        manager = manager
    }, TaxiMeter)
end

function TaxiMeter:open(isPassenger, preserveValues)
    if self.enabled then return end
    self.enabled = true
    SendNUIMessage({
        action = "openUI",
        meterData = {
            defaultPrice = self.pricePer100m,
            isPassenger = isPassenger,
            currentFare = preserveValues and self.fare or 0,
            distanceTraveled = preserveValues and self.total or 0
        }
    })
end

function TaxiMeter:close()
    if not self.enabled then return end
    self.enabled = false
    SendNUIMessage({ action = "closeUI" })
end

function TaxiMeter:reset()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    self.fare = 0
    self.total = 0
    self.lastPos = nil
    SendNUIMessage({ action = "resetMeter" })
    TriggerServerEvent("crimson_taxi:server:syncMeter", GetVehicleNumberPlateText(veh), self.fare, self.total)
end

function TaxiMeter:start()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not self.enabled or self.running or veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then 
        return 
    end
    local plate = GetVehicleNumberPlateText(veh)
    local manager = self.manager

    if not manager.rentedNetIds[plate] then
        return notify("Xe này không phải xe taxi hợp lệ!", "error")
    end

    self.running = true
    self.lastPos = GetEntityCoords(veh)
    SendNUIMessage({ action = "startMeter" })
end

function TaxiMeter:stop()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    self.running = false
    SendNUIMessage({ action = "stopMeter" })
end

function TaxiMeter:update()
    if not self.running then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end

    local pos = GetEntityCoords(veh)
    if self.lastPos then
        local d = #(pos - self.lastPos)
        self.buffer = (self.buffer or 0) + d

        if self.buffer >= 0.3 then
            self.total = self.total + self.buffer
            self.fare = self.fare + (self.pricePer100m / 100.0) * self.buffer
            self.buffer = 0

            SendNUIMessage({
                action = "updateMeter",
                meterData = { currentFare = self.fare, distanceTraveled = self.total }
            })
            TriggerServerEvent("crimson_taxi:server:syncMeter",
                GetVehicleNumberPlateText(veh), self.fare, self.total)
        end
    end
    self.lastPos = pos
end

--==================Doanh Nghiệp====================--
local TaxiManager = {
    companies = {},
    rental = nil,
    plates = {},
    rentedNetIds = {}
}

TaxiManager.meter = TaxiMeter:new(Config.MeterPrice and Config.MeterPrice.per100m or 50, TaxiManager)

local TaxiCompany = {}
TaxiCompany.__index = TaxiCompany

function TaxiCompany:new(id, data)
    return setmetatable({
        id = id,
        label = data.label,
        spawn = data.spawn,
        rentVehicles = data.rentVehicles or {},
        peds = data.peds or {},
        blip = data.blip
    }, TaxiCompany)
end

function TaxiCompany:openBossMenu()
    local ownerData = TaxiManager.owners and TaxiManager.owners[self.id]
    if not ownerData then
        notify("Dữ liệu chủ doanh nghiệp chưa được tải, vui lòng thử lại sau.", "error")
        return
    end

    local options = {
        {
            title = "Quản lý quỹ",
            icon = "dollar-sign",
            onSelect = function()
                TriggerServerEvent("crimson_taxi:server:openFundsMenu", self.id)
            end
        }
    }

    -- Nếu đang rao bán → hiển thị chỉnh giá và hủy
    if ownerData.sell_price and ownerData.sell_price > 0 then
        options[#options+1] = {
            title = ("Đang rao bán: $%s"):format(ownerData.sell_price),
            description = "Chọn để chỉnh lại giá bán",
            icon = "fa-solid fa-handshake",
            onSelect = function()
                local input = lib.inputDialog("Chỉnh giá bán", {
                    { type = "number", label = "Giá mới ($)", required = true, min = 1 }
                })
                if input and tonumber(input[1]) and tonumber(input[1]) > 0 then
                    TriggerServerEvent("crimson_taxi:server:sellCompany", self.id, tonumber(input[1]))
                end
            end
        }
        options[#options+1] = {
            title = "Huỷ rao bán",
            icon = "fa-solid fa-ban",
            onSelect = function()
                TriggerServerEvent("crimson_taxi:server:cancelSellCompany", self.id)
            end
        }

    -- Nếu chưa rao bán → hiển thị Bán Doanh Nghiệp
    else
        options[#options+1] = {
            title = "Bán Doanh Nghiệp",
            icon = "fa-solid fa-handshake",
            onSelect = function()
                local input = lib.inputDialog("Rao bán doanh nghiệp", {
                    { type = "number", label = "Giá bán ($)", required = true, min = 1 }
                })
                if input and tonumber(input[1]) and tonumber(input[1]) > 0 then
                    TriggerServerEvent("crimson_taxi:server:sellCompany", self.id, tonumber(input[1]))
                end
            end
        }
    end

    lib.registerContext({
        id = "taxi_boss_menu_" .. self.id,
        title = (self.label or self.id),
        options = options
    })
    lib.showContext("taxi_boss_menu_" .. self.id)
end


function TaxiCompany:openFundsMenu(funds)
    lib.registerContext({
        id = "taxi_funds_" .. self.id,
        title = "Quỹ Công Ty",
        options = {
            { title = "Số dư", description = ("%s $"):format(funds or 0), disabled = true },
            { title = "Nạp tiền", onSelect = function()
                local input = lib.inputDialog("Nạp vào quỹ", { { type = "number", label = "Số tiền", min = 1, required = true } })
                if input then TriggerServerEvent("crimson_taxi:server:depositFunds", self.id, tonumber(input[1])) end
            end },
            { title = "Rút tiền", onSelect = function()
                local input = lib.inputDialog("Rút quỹ", { { type = "number", label = "Số tiền", min = 1, required = true } })
                if input then TriggerServerEvent("crimson_taxi:server:withdrawFunds", self.id, tonumber(input[1])) end
            end }
        }
    })
    lib.showContext("taxi_funds_" .. self.id)
end

function TaxiCompany:openRentalMenu(rentalCache)
    local opts = {}
    if rentalCache then
        opts[#opts + 1] = {
            title = "Trả xe thuê", icon = "car",
            onSelect = function() TriggerServerEvent("crimson_taxi:server:returnTaxi", rentalCache.plate) end
        }
    end
    for i, v in ipairs(self.rentVehicles or {}) do
        opts[#opts + 1] = {
            title = v.label,
            description = ("%s$/giờ"):format(v.price or 0),
            icon = "car",
            disabled = v.rented,
            onSelect = function()
                if rentalCache then notify("Bạn đã thuê một xe khác rồi.", "error"); return end
                local input = lib.inputDialog("Thuê " .. v.label, { { type = "number", label = "Số giờ", min = 1, max = 4, required = true } })
                if input then
                    TriggerServerEvent("crimson_taxi:server:rentTaxi", self.id, v.model, i, tonumber(input[1]) or 1)
                end
            end
        }
    end
    lib.registerContext({ id = "taxi_rental_" .. self.id, title = "Thuê Xe - " .. (self.label or self.id), options = opts })
    lib.showContext("taxi_rental_" .. self.id)
end

function TaxiManager:getCompany(id)
    if not id then return nil end
    if not self.companies[id] and Config.Companies and Config.Companies[id] then
        self.companies[id] = TaxiCompany:new(id, Config.Companies[id])
    end
    return self.companies[id]
end

function TaxiManager:setRental(data)
    self.rental = data or nil
    if not self.rental then
        safeCall(function() self.meter:close() end)
    end
end

function TaxiManager:addRentedPlate(plate, netid)
    if plate and netid then
        self.rentedNetIds[plate] = netid
    end
end

function TaxiManager:deleteRentedPlate(plate)
    local netid = self.rentedNetIds[plate]
    if netid then
        local veh = NetworkGetEntityFromNetworkId(netid)
        if veh and DoesEntityExist(veh) then DeleteVehicle(veh) end
        self.rentedNetIds[plate] = nil
    end
end

function TaxiManager:isValidTaxiVehicle(veh)
    if not veh or veh == 0 then return false end
    local plate = string.gsub(GetVehicleNumberPlateText(veh) or "", "%s+", "")
    if not plate or plate == "" then return false end
    if self.rental and self.rental.plate == plate then
        return true
    end
    return false
end

function TaxiManager:isOwner(citizenid, companyId)
    if not self.owners or not self.owners[companyId] then return false end
    return self.owners[companyId].citizenid == citizenid
end

RegisterNetEvent("crimson_taxi:client:setOwners", function(owners)
    TaxiManager.owners = owners or {}
end)


--==================== Crimson Taxi NPC (CLIENT) ====================--
local TaxiNPC = {}
TaxiNPC.__index = TaxiNPC

function TaxiNPC:new()
    local self = setmetatable({}, TaxiNPC)
    self.currentOrder = nil 
    self.pending = nil    
    self.orders = {}
    self.ped = nil
    self.pickBlip = nil
    self.dropBlip = nil
    self.inProgress = false
    return self
end
function TaxiNPC:setOrders(orders)
    self.orders = orders or {}
end
function TaxiNPC:openMenu()
    if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    if not self.orders or next(self.orders) == nil then
        lib.notify({description="Không có đơn nào!", type="error"})
        return
    end
    local myServerId = GetPlayerServerId(PlayerId())
    local options = {}
    for id, order in pairs(self.orders) do
        local distance = #(order.pick.coords - order.drop.coords)
        local fare = math.floor(distance / 100 * (Config.MeterPrice and Config.MeterPrice.per100m or 50))
        local desc = ("%s - %s\nQuãng đường: %.1fm\nTiền: $%s"):format(order.pick.label, order.drop.label, distance, fare)
        local disabled = false

        if order.status == "available" then
            if self.currentOrder then disabled = true end
            if self.pending == id then
                desc = desc .. "\n[Đơn của bạn (đang chờ)]"
            end
        elseif order.status == "taken" then
            if order.taker == myServerId or (self.currentOrder and self.currentOrder.id == id) then
                desc = desc .. "\n[Đơn của bạn]"
            else
                disabled = true
                desc = desc .. "\n[Đã có người nhận]"
            end
        end
        options[#options+1] = {
            title = ("Đơn #%s"):format(id),
            description = desc,
            disabled = disabled,
            event = "crimson_taxi:client:selectOrder",
            args = id
        }
    end

    lib.registerContext({id = 'taxi_npc_menu', title = 'Danh sách khách hàng', options = options})
    lib.showContext('taxi_npc_menu')
end
function TaxiNPC:selectOrder(id)
    id = tonumber(id)
    local order = self.orders[id]
    if not order then return end
    if self.currentOrder and self.currentOrder.id == id then
        local confirm = lib.alertDialog({
            header = 'Đơn #'..id,
            content = 'Bạn có muốn hủy đơn này?',
            cancel = true,
            centered = true 
        })
        if confirm == 'confirm' then
            TriggerServerEvent('crimson_taxi:server:cancelOrder', id)
        end
        return
    end
    if self.currentOrder then return end
    self.pending = id
    if order.pick and order.pick.coords then
        self:createPickupBlip(order.pick.coords)
    end
    TriggerServerEvent('crimson_taxi:server:takeOrder', id)
end
function TaxiNPC:onTakeResult(success, reason, id)
    id = tonumber(id)
    if success then
        if self.pending == id then self.pending = nil end
    else
        if self.pending == id then
            self.pending = nil
            self:clear()
        end
    end
end
function TaxiNPC:updateOrder(order)
    if not order then return self:clear() end
    if order.status == "yours" then
        self.pending = nil
        self.currentOrder = order
        self.inProgress = true
        self:createPickupBlip(order.pick.coords)
        lib.notify({description="Tới điểm đón khách", type="info"})
    end
end
function TaxiNPC:createPickupBlip(coords)
    if self.pickBlip then RemoveBlip(self.pickBlip) end
    self.pickBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(self.pickBlip, 280); SetBlipColour(self.pickBlip, 2); SetBlipRoute(self.pickBlip, true)
end
function TaxiNPC:createDropBlip(coords)
    if self.dropBlip then RemoveBlip(self.dropBlip) end
    self.dropBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(self.dropBlip, 280); SetBlipColour(self.dropBlip, 5); SetBlipRoute(self.dropBlip, true)
end
function TaxiNPC:clear()
    self.currentOrder, self.pending, self.inProgress = nil, nil, false
    if self.ped and DoesEntityExist(self.ped) then DeleteEntity(self.ped) end
    self.ped = nil
    if self.pickBlip then RemoveBlip(self.pickBlip) end
    if self.dropBlip then RemoveBlip(self.dropBlip) end
    self.pickBlip, self.dropBlip = nil, nil
end
function TaxiNPC:onPickup()
    if not self.currentOrder or self.ped then return end
    if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    local coords = self.currentOrder.pick.coords

    RequestModel(`a_m_m_business_01`)
    local t0 = GetGameTimer()
    while not HasModelLoaded(`a_m_m_business_01`) and GetGameTimer() - t0 < 5000 do Wait(10) end
    if not HasModelLoaded(`a_m_m_business_01`) then return end

    self.ped = CreatePed(4, `a_m_m_business_01`, coords.x, coords.y, coords.z, 0.0, true, true)
    TaskEnterVehicle(self.ped, GetVehiclePedIsIn(PlayerPedId(), false), 10000, 2, 1.0, 1, 0)
    self:createDropBlip(self.currentOrder.drop.coords)
    lib.notify({title="Taxi", description="Khách đã lên xe, tới điểm trả", type="info"})
end
function TaxiNPC:onDropoff()
    if not self.currentOrder or not self.ped then return end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return end
    TaskLeaveVehicle(self.ped, veh, 0)
    Wait(1500)
    if self.ped and DoesEntityExist(self.ped) then DeleteEntity(self.ped) end
    self.ped = nil
    TriggerServerEvent("crimson_taxi:server:finishOrder", self.currentOrder.id)
    self:clear()
end
CreateThread(function()
    while true do
        Wait(800)
        local cl = TaxiNPC.Client
        if cl and (cl.currentOrder or cl.pending) then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local ord = cl.currentOrder or (cl.pending and cl.orders[cl.pending])
            if ord then
                if not cl.ped then
                    if #(pos - ord.pick.coords) < 20.0 and IsPedInAnyVehicle(ped, false) then
                        if cl.currentOrder or cl.pending == ord.id then
                            cl:onPickup()
                        end
                    end
                else
                    if #(pos - ord.drop.coords) < 20.0 and IsPedInAnyVehicle(ped, false) then
                        cl:onDropoff()
                    end
                end
            end
        end
    end
end)

TaxiNPC.Client = TaxiNPC:new()
RegisterNetEvent("crimson_taxi:client:setOrders",   function(orders) TaxiNPC.Client:setOrders(orders) end)
RegisterNetEvent("crimson_taxi:client:updateOrder", function(order)  TaxiNPC.Client:updateOrder(order) end)
RegisterNetEvent("crimson_taxi:client:selectOrder", function(id)     TaxiNPC.Client:selectOrder(id) end)
RegisterNetEvent("crimson_taxi:client:takeResult",  function(success, reason, id) TaxiNPC.Client:onTakeResult(success, reason, id) end)
RegisterNetEvent("crimson_taxi:client:cancelResult", function(success, reason) TaxiNPC.Client:clear() end)
RegisterNetEvent("crimson_taxi:client:completeResult", function(success, data) if success then print("[DEBUG] Paid:", data) end end)
RegisterNetEvent("crimson_taxi:client:clearRental", function()
    if TaxiNPC.Client.currentOrder then
        TriggerServerEvent('crimson_taxi:server:cancelOrder', TaxiNPC.Client.currentOrder.id)
    elseif TaxiNPC.Client.pending then
        TriggerServerEvent('crimson_taxi:server:cancelOrder', TaxiNPC.Client.pending)
    end
    TaxiNPC.Client:clear()
end)
--========================================--

RegisterNetEvent("crimson_taxi:client:notify", function(msg, type_) notify(msg, type_) end)
RegisterNetEvent("crimson_taxi:client:updateRentalState", function(companyId, idx, rented)
    local comp = TaxiManager:getCompany(companyId)
    if comp and comp.rentVehicles and comp.rentVehicles[idx] then
        comp.rentVehicles[idx].rented = rented
    end
    if TaxiManager.rental and TaxiManager.rental.companyId == companyId and TaxiManager.rental.index == idx and not rented then
        TaxiManager:setRental(nil)
    end
end)
RegisterNetEvent("crimson_taxi:client:setRental", function(data)
    TaxiManager:setRental(data)
end)
RegisterNetEvent("crimson_taxi:client:clearRental", function()
    TaxiManager:setRental(nil)
end)
RegisterNetEvent("crimson_taxi:client:returnTaxiResult", function(success, reason)
    if not success then return notify(reason or "Không thể trả xe.", "error") end
    TaxiManager:setRental(nil)
    notify("Trả xe thành công.", "success")
end)
RegisterNetEvent("crimson_taxi:client:rentTaxiResult", function(success, reason)
    if not success then return notify(reason or "Không thể thuê xe.", "error") end
    notify("Thuê xe thành công.", "success")
end)

RegisterNetEvent("crimson_taxi:client:spawnTaxi", function(plate, model, secs, companyId)
    local spawn = (Config.Companies[companyId] and Config.Companies[companyId].spawn and Config.Companies[companyId].spawn.coords)
    if not spawn then
        notify("Vị trí spawn không hợp lệ.", "error"); return
    end
    QBCore.Functions.SpawnVehicle(model, function(veh)
        if not veh then return notify("Không thể tạo xe", "error") end
        SetEntityHeading(veh, spawn.w)
        SetVehicleNumberPlateText(veh, plate)
        SetVehicleFuelLevel(veh, 100.0)
        SetVehicleEngineOn(veh, true, true)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        TaxiManager:addRentedPlate(plate, VehToNet(veh))
        notify(("Đã thuê xe %s"):format(plate), "success")
        local rentalCancel = false
        local left = secs
        RegisterNetEvent("crimson_taxi:client:cancelRental", function()
            rentalCancel = true
            if lib and lib.hideTextUI then lib.hideTextUI() end
        end)
        CreateThread(function()
            while left > 0 and DoesEntityExist(veh) and not rentalCancel do
                if lib and lib.showTextUI then
                    local h,m,s = left//3600, (left%3600)//60, left%60
                    lib.showTextUI(("Thời gian thuê xe còn lại - %02d:%02d:%02d"):format(h,m,s), { position="bottom-center" })
                end
                Wait(1000); left = left - 1
            end
            if not rentalCancel then
                if lib and lib.hideTextUI then lib.hideTextUI() end
                if DoesEntityExist(veh) then DeleteVehicle(veh) end
                TriggerServerEvent("crimson_taxi:server:returnTimeout", plate, model, companyId)
                TaxiManager:setRental(nil)
            end
        end)
    end, spawn, true)
end)

RegisterNetEvent("crimson_taxi:client:deleteRentedVehicle", function(plate)
    TaxiManager:deleteRentedPlate(plate)
end)

RegisterNetEvent("crimson_taxi:client:openFundsMenu", function(companyId, funds)
    local comp = TaxiManager:getCompany(companyId)
    if comp then comp:openFundsMenu(funds) end
end)
RegisterNetEvent("crimson_taxi:client:spawnTaxiMeter", function(data)
    TaxiManager.meter.fare = data.fare or 0
    TaxiManager.meter.total = data.total or 0
    TaxiManager.meter.pricePer100m = data.pricePer100m or TaxiManager.meter.pricePer100m
    SendNUIMessage({ action = "updateMeter", meterData = { currentFare = TaxiManager.meter.fare, distanceTraveled = TaxiManager.meter.total } })
end)
RegisterNetEvent("crimson_taxi:client:updateMeterData", function(fare, total)
    TaxiManager.meter.fare = fare or 0
    TaxiManager.meter.total = total or 0
    SendNUIMessage({ action = "updateMeter", meterData = { currentFare = TaxiManager.meter.fare, distanceTraveled = TaxiManager.meter.total } })
end)

local function spawnPeds()
    for id, compData in pairs(Config.Companies or {}) do
        local comp = TaxiManager:getCompany(id)
        for _, data in ipairs(comp.peds or {}) do
            RequestModel(data.model)
            while not HasModelLoaded(data.model) do Wait(0) end

            local c = data.coords
            local ped = CreatePed(4, data.model, c.x, c.y, c.z - 1, c.w, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)

            if data.scenario then 
                TaskStartScenarioInPlace(ped, data.scenario, 0, true) 
            end

            if data.blip then
                local blip = AddBlipForCoord(c.x, c.y, c.z)
                SetBlipSprite(blip, 198)
                SetBlipColour(blip, 5)
                SetBlipScale(blip, 0.6)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(comp.label or "Taxi")
                EndTextCommandSetBlipName(blip)
            end

            exports.ox_target:addLocalEntity(ped, {
                {
                    name = "taxi_menu_" .. comp.id,
                    label = "Dịch vụ Taxi",
                    icon = "fa-solid fa-taxi",
                    onSelect = function()
                        local PlayerData = QBCore.Functions.GetPlayerData()
                        local options = {}
                        local ownerData = TaxiManager.owners and TaxiManager.owners[comp.id]
                        if not ownerData or not ownerData.citizenid or ownerData.citizenid == "" then
                            local basePrice = comp.price or 500000
                            options[#options+1] = {
                                title = ("Mua doanh nghiệp ($%s)"):format(basePrice),
                                icon = "fa-solid fa-building",
                                onSelect = function()
                                    TriggerServerEvent("crimson_taxi:server:buyCompany", comp.id, basePrice)
                                end
                            }
                        elseif ownerData.sell_price and ownerData.sell_price > 0 then
                            options[#options+1] = {
                                title = ("Mua doanh nghiệp ($%s)"):format(ownerData.sell_price),
                                icon = "fa-solid fa-handshake",
                                onSelect = function()
                                    TriggerServerEvent("crimson_taxi:server:buyCompany", comp.id, ownerData.sell_price)
                                end
                            }
                        end
                        if ownerData and ownerData.citizenid and ownerData.citizenid == PlayerData.citizenid then
                            options[#options+1] = {
                                title = "Quản lý Taxi",
                                icon = "fa-solid fa-clipboard",
                                onSelect = function()
                                    comp:openBossMenu()
                                end
                            }
                        end
                        options[#options+1] = {
                            title = "Thuê xe Taxi",
                            icon = "fa-solid fa-car",
                            onSelect = function()
                                comp:openRentalMenu(TaxiManager.rental)
                            end
                        }
                        lib.registerContext({
                            id = 'taxi_menu_' .. comp.id,
                            title = comp.label or "Taxi",
                            options = options
                        })
                        lib.showContext('taxi_menu_' .. comp.id)
                    end
                }
            })
        end
    end
end

CreateThread(function() Wait(500); spawnPeds() end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if TaxiManager.meter and veh ~= 0 and TaxiManager:isValidTaxiVehicle(veh) then
            Wait(0)
            if IsControlJustPressed(0, 19) then
                safeCall(function() TaxiManager.meter:reset() end)
                if TaxiManager.meter.running then
                    TaxiManager.meter:stop()
                else
                    TaxiManager.meter:start()
                end
            end
            if IsControlJustPressed(0, Config.Keys and Config.Keys.toggleUI or 56) then
                if TaxiManager.meter.enabled then
                    TaxiManager.meter:close()
                else
                    TaxiManager.meter:open(false, true)
                end
            end
            if IsControlJustPressed(0, 311) then
                TaxiNPC.Client:openMenu()
            end
            if TaxiManager.meter.running then
                safeCall(function() TaxiManager.meter:update() end)
            end
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    local wasInVeh = false
    while true do
        Wait(300)
        if TaxiManager.meter.enabled and TaxiManager.meter.running then
            safeCall(function() TaxiManager.meter:update() end)
        end
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and not wasInVeh then
            wasInVeh = true
            local plate = GetVehicleNumberPlateText(veh)

            local isCompanyVehicle, vtype = false, nil
            if TaxiManager.rentedNetIds[plate] then
                isCompanyVehicle, vtype = true, "rental"
            end

            if isCompanyVehicle then
                local isPassenger = not (GetPedInVehicleSeat(veh, -1) == ped)
                if vtype == "rental" then TaxiManager.meter.renterPlate = plate end
                TaxiManager.meter:open(isPassenger, true)
                TriggerServerEvent("crimson_taxi:server:requestMeter", plate)
            end
        elseif veh == 0 and wasInVeh then
            wasInVeh = false
            TaxiManager.meter:close()
            TaxiManager.meter.renterPlate = nil
        end
    end
end)

function OpenBossMenu(companyId)
    local comp = TaxiManager:getCompany(companyId)
    if comp then comp:openBossMenu() end
end

function OpenRentalMenu(companyId)
    local comp = TaxiManager:getCompany(companyId)
    if comp then comp:openRentalMenu(TaxiManager.rental) end
end
