Node7RobbingServerCore = nil

local function loadCore()
    while GetResourceState('node7-core') ~= 'started' do
        Wait(100)
    end

    while type(Node7RobbingServerCore) ~= 'table' do
        local ok, core = pcall(function()
            return exports['node7-core']:GetCoreObject()
        end)

        if ok and type(core) == 'table' then
            Node7RobbingServerCore = core
            return
        end

        Wait(100)
    end
end

loadCore()
