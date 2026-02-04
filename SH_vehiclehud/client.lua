-- Importation ESX sécurisée
local ESX = exports["es_extended"]:getSharedObject() 

-- Cache des valeurs de configuration
local isMetric = Config.SpeedUnit == 'kmh'
local conversionFactor = isMetric and 3.6 or 2.236936

-- Variables d'état
local seatbeltOn = false
local limiterActive = false 
local limiterSpeed = 0
local speedBuffer = {}
local velBuffer = {}
local alertActive = false
local editMode = false

local lastData = {
    speed = -1, fuel = -1, gear = -1, rpm = -1, seatbelt = nil, cruise = nil
}

-- Fonction pour cacher l'interface véhicule de base de GTA
function HideNativeHUD()
    HideHudComponentThisFrame(6)  -- Vehicle Name
    HideHudComponentThisFrame(7)  -- Area Name
    HideHudComponentThisFrame(8)  -- Vehicle Class
    HideHudComponentThisFrame(9)  -- Street Name
end


-- Cache pour la ressource d'essence
local fuelResource = nil
CreateThread(function()
    if GetResourceState("ox_fuel") == "started" then
        fuelResource = "ox_fuel"
    elseif GetResourceState("LegacyFuel") == "started" then
        fuelResource = "LegacyFuel"
    end
end)

-- Fonction pour obtenir l'essence
local function getFuel(vehicle)
    if not fuelResource then return math.floor(GetVehicleFuelLevel(vehicle)) end
    local success, result = pcall(function()
        if fuelResource == "ox_fuel" then
            return math.floor(GetVehicleFuelLevel(vehicle))
        else
            return math.floor(exports[fuelResource]:GetFuel(vehicle))
        end
    end)
    if success then return result else return math.floor(GetVehicleFuelLevel(vehicle)) end
end

-- Fonction pour jouer les sons via NUI
local function PlayGuiSound(soundName, volume)
    SendNUIMessage({
        type = 'playSound',
        sound = soundName,
        volume = volume or 0.5
    })
end

-- Callback pour fermer le mode édition via le bouton VALIDER de l'UI
RegisterNUICallback('closeEditMode', function(data, cb)
    editMode = false
    SetNuiFocus(false, false)
    ESX.ShowNotification("Position du HUD sauvegardée !")
    cb('ok')
end)

-- Commande pour déplacer le HUD
RegisterCommand('movehud', function()
    editMode = not editMode
    if editMode then
        SetNuiFocus(true, true)
        ESX.ShowNotification("Mode édition : Déplacez le HUD et cliquez sur VALIDER.")
    else
        SetNuiFocus(false, false)
    end
    SendNUIMessage({ type = 'toggleHudEdit' })
end, false)

-- Commande Ceinture
RegisterCommand('toggleseatbelt', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local class = GetVehicleClass(vehicle)
        if class ~= 8 and class ~= 13 and class ~= 14 then
            seatbeltOn = not seatbeltOn
            if seatbeltOn then
                PlayGuiSound('SeatbeltOnSound', 0.5)
                --ESX.ShowNotification("Ceinture attachée")
            else
                PlayGuiSound('SeatbeltOffSound', 0.5)
              --  ESX.ShowNotification("Ceinture détachée")
            end
        end
    end
end, false)
RegisterKeyMapping('toggleseatbelt', 'Mettre/Enlever la ceinture', 'keyboard', 'B')

-- Commande Limiteur
RegisterCommand('togglelimiter', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not IsPedInAnyVehicle(ped, false) or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    if limiterActive then
        limiterActive = false
        SetVehicleMaxSpeed(vehicle, 0.0) 
        ESX.ShowNotification("Limiteur désactivé")
    else
        local currentSpeed = GetEntitySpeed(vehicle)
        if currentSpeed > 0.5 then
            limiterActive = true
            limiterSpeed = currentSpeed
            ESX.ShowNotification("Limiteur fixé à " .. math.floor(currentSpeed * conversionFactor) .. " " .. Config.SpeedUnit)
        end
    end
end, false)
RegisterKeyMapping('togglelimiter', 'Activer/Désactiver le limiteur', 'keyboard', 'CAPITAL')

-- Petite fonction pour convertir le Heading (360°) en Direction (N, S, E, O)
local function getCardinalDirection(heading)
    if heading >= 315 or heading < 45 then return "N"
    elseif heading >= 45 and heading < 135 then return "O" -- Ouest (West)
    elseif heading >= 135 and heading < 225 then return "S"
    elseif heading >= 225 and heading < 315 then return "E" -- Est
    end
    return "N"
end

local function startVehicleUI(vehicle)
    seatbeltOn = false
    limiterActive = false
    lastData = { speed = -1, fuel = -1, gear = -1, rpm = -1, seatbelt = nil, cruise = nil, lock = -1, street = "", dir = "" }

    while DoesEntityExist(vehicle) and IsPedInAnyVehicle(PlayerPedId(), false) do
        HideNativeHUD()
        
        -- ... (votre code ceinture et limiteur existant) ...
        if seatbeltOn then DisableControlAction(0, 75, true) end
        if limiterActive then SetVehicleMaxSpeed(vehicle, limiterSpeed) else SetVehicleMaxSpeed(vehicle, 0.0) end

        -- Données existantes
        local speedRaw = GetEntitySpeed(vehicle) * conversionFactor
        local speed = math.floor(speedRaw)
        local fuel = getFuel(vehicle)
        local gear = GetVehicleCurrentGear(vehicle)
        local rpm = GetVehicleCurrentRpm(vehicle)

        -- AJOUTS DONNÉES
        local lockStatus = GetVehicleDoorLockStatus(vehicle) -- 1: Ouvert, 2: Fermé
        
        local coords = GetEntityCoords(PlayerPedId())
        local heading = GetEntityHeading(vehicle)
        local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = GetStreetNameFromHashKey(streetHash)
        local direction = getCardinalDirection(heading)

        -- Envoi optimisé
        if speed ~= lastData.speed or fuel ~= lastData.fuel or gear ~= lastData.gear or 
           rpm ~= lastData.rpm or seatbeltOn ~= lastData.seatbelt or limiterActive ~= lastData.cruise or
           lockStatus ~= lastData.lock or streetName ~= lastData.street or direction ~= lastData.dir then
            
            lastData = { 
                speed = speed, fuel = fuel, gear = gear, rpm = rpm, 
                seatbelt = seatbeltOn, cruise = limiterActive,
                lock = lockStatus, street = streetName, dir = direction 
            }
            
            SendNUIMessage({
                type = 'updateVehicleHud',
                speed = speed,
                fuel = fuel,
                gear = gear,
                rpm = rpm,
                seatbelt = seatbeltOn,
                cruise = limiterActive,
                -- NOUVEAUX CHAMPS
                lock = lockStatus,
                street = streetName,
                direction = direction,
                
                show = true
            })
        end
        Wait(50) -- Petit délai pour pas spammer les GetStreetName
    end
    
    if DoesEntityExist(vehicle) then SetVehicleMaxSpeed(vehicle, 0.0) end
    seatbeltOn = false
    limiterActive = false
    SendNUIMessage({ type = 'hideVehicleHud' })
end

-- Boucle Principale : Détection véhicule + Gestion Minimap automatique
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isPaused = IsPauseMenuActive()

        if IsPedInAnyVehicle(ped, false) then
            DisplayRadar(true)
            startVehicleUI(GetVehiclePedIsIn(ped, false))
        else
            -- Gestion de la minimap à pied
            if Config.AutoMinimap and not isPaused then
                DisplayRadar(false)
            else
                DisplayRadar(true)
                HideNativeHUD() -- On cache les barres même à pied si le radar est activé
            end
            Wait(0) -- On maintient Wait(0) même à pied si la map est là pour cacher les barres
        end
        Wait(0)
    end
end)

-- Boucle Alertes Ceinture (Bruitage et clignotement)
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and not seatbeltOn then
            local speed = GetEntitySpeed(vehicle) * 3.6
            -- Alerte au dessus de 20 km/h (sauf motos/vélos)
            if speed > 20.0 and GetVehicleClass(vehicle) ~= 8 and GetVehicleClass(vehicle) ~= 13 then
                PlayGuiSound('SeatbeltAlertSound', 0.2)
                SendNUIMessage({ type = 'seatbeltAlert', alert = true })
                alertActive = true
                Wait(800)
            else
                if alertActive then
                    SendNUIMessage({ type = 'seatbeltAlert', alert = false })
                    alertActive = false
                end
            end
        else
            if alertActive then
                SendNUIMessage({ type = 'seatbeltAlert', alert = false })
                alertActive = false
            end
        end
        Wait(500)
    end
end)

-- Gestion de l'éjection (Physique du choc)
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            local speed = GetEntitySpeed(vehicle)
            local vector = GetEntityVelocity(vehicle)
            
            if not speedBuffer[1] then speedBuffer[1] = speed end
            if not velBuffer[1] then velBuffer[1] = vector end

            speedBuffer[2] = speedBuffer[1]
            speedBuffer[1] = speed
            velBuffer[2] = velBuffer[1]
            velBuffer[1] = vector
            
            -- Éjection si choc brutal sans ceinture (> 100 km/h)
            if not seatbeltOn and speedBuffer[2] > (100 / 3.6) then
                if (speedBuffer[2] - speedBuffer[1]) > (speedBuffer[2] * 0.25) then
                   local coords = GetEntityCoords(ped)
                   local fw = GetEntityForwardVector(ped)
                   SetEntityCoords(ped, coords.x + fw.x, coords.y + fw.y, coords.z - 0.47, true, true, true)
                   SetEntityVelocity(ped, velBuffer[2].x, velBuffer[2].y, velBuffer[2].z)
                   SetPedToRagdoll(ped, 1000, 1000, 0, 0, 0, 0)
                end
            end
            Wait(10)
        else
            speedBuffer = {}
            velBuffer = {}
            Wait(1000)
        end
    end
end)

-- Gestion des Clignotants (Flèches) et Warnings (Haut)
CreateThread(function()
    local lastIndicatorState = -1
    
    while true do
        local ped = PlayerPedId()
        local sleep = 1000 -- Optimisation (dort 1s quand on est à pied)

        if IsPedInAnyVehicle(ped, false) then
            sleep = 0 -- Réactif en véhicule
            
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            -- Uniquement si on est conducteur
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                
                -- Touche GAUCHE (174) - Clignotant Gauche
                if IsControlJustPressed(0, 174) then
                    local lights = GetVehicleIndicatorLights(vehicle)
                    if lights == 1 then 
                        SetVehicleIndicatorLights(vehicle, 1, false) -- Éteindre
                    else 
                        SetVehicleIndicatorLights(vehicle, 1, true)  -- Allumer Gauche
                        SetVehicleIndicatorLights(vehicle, 0, false) -- Éteindre Droite
                    end
                end

                -- Touche DROITE (175) - Clignotant Droit
                if IsControlJustPressed(0, 175) then
                    local lights = GetVehicleIndicatorLights(vehicle)
                    if lights == 2 then 
                        SetVehicleIndicatorLights(vehicle, 0, false) -- Éteindre
                    else 
                        SetVehicleIndicatorLights(vehicle, 0, true)  -- Allumer Droite
                        SetVehicleIndicatorLights(vehicle, 1, false) -- Éteindre Gauche
                    end
                end

                -- Commande et Mapping pour les Warnings (W)
                RegisterCommand('togglewarnings', function()
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
        
                -- Uniquement le conducteur
                if GetPedInVehicleSeat(vehicle, -1) == ped then
                local lights = GetVehicleIndicatorLights(vehicle)
            
                if lights == 3 then -- Si déjà en warning (les deux allumés)
                SetVehicleIndicatorLights(vehicle, 1, false)
                SetVehicleIndicatorLights(vehicle, 0, false)
                else -- Sinon on active les deux
                SetVehicleIndicatorLights(vehicle, 1, true)
                SetVehicleIndicatorLights(vehicle, 0, true)
            end
            -- La synchronisation avec le HUD se fera automatiquement via la boucle principale
        end
    end
end, false)


RegisterKeyMapping('togglewarnings', 'Activer/Désactiver Warnings', 'keyboard', 'Z')
                
                -- Synchronisation avec le HUD
                local currentLights = GetVehicleIndicatorLights(vehicle) -- 0:Off, 1:Left, 2:Right, 3:Both
                if currentLights ~= lastIndicatorState then
                    lastIndicatorState = currentLights
                    -- Envoie l'info au JS : Si c'est 3 (Both), left et right seront true tous les deux
                    SendNUIMessage({
                        type = 'updateIndicators',
                        left = (currentLights == 1 or currentLights == 3),
                        right = (currentLights == 2 or currentLights == 3)
                    })
                end
            end
        else
            -- Reset si on sort du véhicule
            if lastIndicatorState ~= 0 then
                lastIndicatorState = 0
                SendNUIMessage({ type = 'updateIndicators', left = false, right = false })
            end
        end
        
        Wait(sleep)
    end
end)