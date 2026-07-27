Node7RobbingConfig = {}
Config = Node7RobbingConfig

Config.Debug = false
Config.MaxDistance = 2.5
Config.ServerDistanceTolerance = 0.75
Config.AttemptCooldownMs = 1500
Config.Command = 'rob'

-- Standalone root option. It is not placed inside User or any other submenu.
Config.Radial = {
    Handle = 'node7-robbing:root-option',
    ItemId = 'node7_robbing',
    Title = 'Rob Player',
    Icon = 'hand',
}

Config.Robbable = {
    RequireTargetState = true,
    AllowDead = true,
    AllowHogtied = true,
    AllowCoreMetadata = true,
    StateKey = 'node7Robbable',
    ReasonStateKey = 'node7RobbableReason',
    PollIntervalMs = 500,
    HeartbeatMs = 3000,
    ReportTimeoutMs = 7000,
    MetadataKeys = {
        'isdead',
        'inlaststand',
        'ishandcuffed',
        'isHandcuffed',
        'hogtied',
        'ishogtied',
    },
}

Config.NotifyTarget = true
Config.NotifyDuration = 4500
