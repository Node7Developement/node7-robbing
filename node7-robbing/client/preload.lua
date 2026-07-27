Node7RobbingCore = nil

local function loadCore()
    while GetResourceState('node7-core') ~= 'started' do
        Wait(100)
    end

    while type(Node7RobbingCore) ~= 'table' do
        local ok, core = pcall(function()
            return exports['node7-core']:GetCoreObject()
        end)

        if ok and type(core) == 'table' then
            Node7RobbingCore = core
            return
        end

        Wait(100)
    end
end

loadCore()
