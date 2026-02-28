# Bulletrain
Barebones Roblox FPS framework scaffold.

## Project goals
- Simple server-driven gameplay loop: Intermission -> Voting -> Match -> End -> repeat.
- First-person shooter foundation with two weapons (Shotgun, Knife).
- Sliding only during Combat.
- Barebones: no UI creation (only `-- need ui implementation here` markers).
- Networking uses exactly one `RemoteEvent` (reliable), one `UnreliableRemoteEvent`, and one `RemoteFunction`.

## Getting Started
Build the place from scratch:

```bash
rojo build -o "Bulletrain.rbxlx"
```

Open `Bulletrain.rbxlx` in Roblox Studio and start Rojo:

```bash
rojo serve
```

## Rojo / folder layout
`default.project.json` maps folders into Roblox services:
- `ReplicatedFirst` <- `src/replicated`
- `ReplicatedStorage`
  - `Core` <- `src/core` (shim used by bundled FastCast)
  - `Shared` <- `src/shared`
  - `Framework` <- `src/framework`
- `ServerScriptService`
  - `Server.server.lua` <- `src/server/Server.server.luau`
  - `Core` <- `src/server/Core`

## Boot process
### Server
Entry: `ServerScriptService/Server.server.lua` (`src/server/Server.server.luau`)
1. Requires `ReplicatedStorage.Shared.Network.Network` and calls `Network:Init()`.
   - On server, this creates `ReplicatedStorage/Remotes/{RemoteEvent,UnreliableRemoteEvent,RemoteFunction}`.
2. Recursively requires all ModuleScripts under `ServerScriptService.Core`.
3. If a required module returns a table with `Initialize()`, it is called.

### Client
Entry: `ReplicatedFirst/ClientLoader.client.lua` (`src/replicated/ClientLoader.client.luau`)
1. Recursively requires all ModuleScripts under `ReplicatedStorage.Framework`.
2. If a required module returns a table with `Initialize()`, it is called.

## How player state replication works (Menu/Combat)
The server does NOT send an explicit “SetState” packet.

Instead, the server sets a Player Attribute:
- `player:SetAttribute("State", "Menu" | "Combat")`

Player Attributes replicate automatically from server -> client.

On the client, `Framework/Services/PlayerStateController.luau` listens to:
- `LocalPlayer:GetAttributeChangedSignal("State")`

When it changes:
- `Menu`:
  - `CameraMode = Classic`
  - disables viewmodel, combat input, and slide
- `Combat`:
  - `CameraMode = LockFirstPerson`
  - enables viewmodel, combat input, and slide

## Gameplay loop (server)
Implemented in `Server/Core/Services/GameLoopService.luau`.
High-level flow:
1. Intermission (Menu state)
2. Voting window (server receives votes via networking; no UI yet)
3. Match starts (map loads), but players still stay in Menu until they join
4. Players press Space to join (manual join)
5. Match ends (time or kill limit)
6. Everyone is forced back to lobby and set to Menu

## Manual join (Space)
- Client: `Framework/Services/MatchJoinService.luau` listens for Space.
- If the match is running AND player state is Menu, it fires:
  - `Network:FireRemoteToServer("RequestJoinMatch")`
- Server: `GameLoopService` receives `RequestJoinMatch` and spawns the player into the active match + sets `State = Combat`.

## Networking
Shared API: `ReplicatedStorage.Shared.Network.Network`

### Instances
Created in `ReplicatedStorage/Remotes`:
- `RemoteEvent` (reliable)
- `UnreliableRemoteEvent`
- `RemoteFunction`

### Conventions
All messages are “packets”:
- First argument is `packetName`
- Remaining args are payload

Server -> client:
- `Network:FireRemoteToClient(player, "PacketName", ...)`
- `Network:FireRemoteToAllClients("PacketName", ...)`

Client -> server:
- `Network:FireRemoteToServer("PacketName", ...)`

Subscribe:
- Server: `Network:SubscribeToPacket("PacketName")` yields a signal that passes `(player, ...)`
- Client: `Network:SubscribeToPacket("PacketName")` yields a signal that passes `(...)`

## Weapons
### Server-authoritative
`Server/Core/Services/CombatService.luau`
- Shotgun: server performs raycasts per pellet for damage.
- Knife: server performs a short raycast.
- Both only work when player state is `Combat`.

### Client cosmetic projectiles
`Framework/Classes/Weapons/Shotgun.luau`
- Fires a server packet for damage.
- Uses FastCast locally for cosmetic pellets only.

FastCast is vendored at `Shared/ThirdParty/FastCast`.

## Sliding
Client-only and Combat-only:
- `Framework/Services/SlideService.luau`
- Settings in `Shared/MovementSettings.luau`

## Adding new features (guidelines)
### 1) Decide the layer
- Server gameplay rules, validation, damage, match flow: add to `src/server/Core/Services/*`.
- Client presentation, input, viewmodels, camera, local movement: add to `src/framework/Services/*` or `src/framework/Classes/*`.
- Shared config/data/utilities: add to `src/shared/*`.

### 2) Wire initialization
If your new module needs to run on boot:
- Return a table with `Initialize()`.
- Place it under:
  - Server: `src/server/Core/...`
  - Client: `src/framework/...`
The loaders will auto-require and call `Initialize()`.

### 3) Networking rules
- Do NOT create additional RemoteEvents/RemoteFunctions.
- Add a new packet name and subscribe to it.
- Keep payloads small; use `UnreliableRemoteEvent` for frequent cosmetic updates.

### 4) UI policy
Do not create UI Instances yet.
Use markers like:
- `-- need ui implementation here`

### 5) Security / authority
- Never trust client hits.
- Client can request actions; server validates state + performs raycasts/damage.

For more help, check out the Rojo documentation: https://rojo.space/docs
