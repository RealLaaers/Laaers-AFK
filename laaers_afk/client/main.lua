local idleTimer = 0
local lastPosition = vector3(0.0, 0.0, 0.0)
local lastHeading = 0.0
local isAnimating = false

local function HasPlayerMoved(playerPed)
    local currentPosition = GetEntityCoords(playerPed)
    local moved = #(currentPosition - lastPosition) > 0.5
    if moved then lastPosition = currentPosition end
    return moved
end

local function HasPlayerMovedCamera(playerPed)
    local currentHeading = GetEntityHeading(playerPed)
    local changed = math.abs(currentHeading - lastHeading) > 1.0
    if changed then lastHeading = currentHeading end
    return changed
end

-- Diverse controls, i kan tilføje flere såfremt det lyster.
local movementControls = {32, 33, 34, 35, 21, 22, 44, 73} -- Diverse controls til at afbryde animationen.
local function IsMovementInputPressed()
    for _, key in ipairs(movementControls) do
        if IsControlPressed(0, key) then return true end
    end
    return false
end

local function CancelIdleIfAnimating(playerPed)
    if isAnimating then
        ClearPedTasks(playerPed)
        isAnimating = false
    end
end

local function ShouldCancelIdle(playerPed)
    return HasPlayerMoved(playerPed) or HasPlayerMovedCamera(playerPed) or IsMovementInputPressed()
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local playerPed = PlayerPedId()

        if not DoesEntityExist(playerPed) or IsEntityDead(playerPed) or IsPedInAnyVehicle(playerPed, false) then
            idleTimer = 0
            CancelIdleIfAnimating(playerPed)
            if DoesEntityExist(playerPed) then
                lastPosition = GetEntityCoords(playerPed)
                lastHeading = GetEntityHeading(playerPed)
            end
        elseif ShouldCancelIdle(playerPed) then
            idleTimer = 0
            CancelIdleIfAnimating(playerPed)
        else
            idleTimer = idleTimer + 500
            if idleTimer >= Config.IdleTime and not isAnimating then
                PlayIdleAnimation(playerPed)
            end
        end
    end
end)

-- Her startes animationen.
function PlayIdleAnimation(ped)
    isAnimating = true
    Citizen.CreateThread(function()
        local animation = Config.Animations[math.random(#Config.Animations)]
        RequestAnimDict(animation.dict)
        local timeout = 2000
        while not HasAnimDictLoaded(animation.dict) and timeout > 0 do
            Citizen.Wait(100)
            timeout = timeout - 100
        end

        if HasAnimDictLoaded(animation.dict) and isAnimating then
            local duration = animation.duration or 10000
            TaskPlayAnim(ped, animation.dict, animation.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
            local timeWaited = 0
            while timeWaited < duration and isAnimating do
                Citizen.Wait(100)
                if ShouldCancelIdle(ped) then break end
                timeWaited = timeWaited + 100
            end
            ClearPedTasks(ped)
            RemoveAnimDict(animation.dict)
        end
        isAnimating = false
    end)
end