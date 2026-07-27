[README.md](https://github.com/user-attachments/files/30429094/README.md)
# node7-robbing

Secure player robbery integration for NODE7 RedM servers.

## Integration

- Automatically adds **Rob Player** as its own root option in `node7-radialmenu`.
- It is not placed under **User** or another submenu.
- Uses `exports['node7-inventory']:OpenInventoryById(robber, target)`.
- Uses NODE7 Core player data and NODE7 Core notifications.
- Re-registers after either `node7-robbing` or `node7-radialmenu` restarts.
- Removes its radial option automatically when the resource stops.
- Includes `client/preload.lua` so NODE7 Core is loaded before the main client script.

## Security checks

Every player may attempt a robbery. No ACE permission is used.

The server still validates:

- Different source and target players.
- Both NODE7 player objects are loaded.
- Same routing bucket.
- Server-calculated distance.
- Attempt cooldown.
- The robber is not incapacitated or restrained.
- The target is dead, incapacitated, restrained, handcuffed, or hogtied.
- NODE7 Inventory busy/session protection.

## Installation

```cfg
ensure node7-core
ensure node7-inventory
ensure node7-radialmenu
ensure node7-robbing
```

Do not add or execute a robbery `permissions.cfg`; this resource has no ACE permissions.

## Controls

- Radial root: **Rob Player**
- Fallback command: `/rob`

## Restraint and hands-up integration

Another client resource can mark its local player as robbable:

```lua
exports['node7-robbing']:SetRobbable(true, 'hands-up')
```

Clear it with:

```lua
exports['node7-robbing']:SetRobbable(false)
```

Optional timed state:

```lua
exports['node7-robbing']:SetRobbable(true, 'restrained', 10000)
```

## Server export

```lua
local allowed, reason = exports['node7-robbing']:CanRobPlayer(source, targetId)
```
