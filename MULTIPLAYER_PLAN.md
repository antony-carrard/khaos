# Multiplayer Implementation Plan

**Created:** 2026-01-04
**Status:** Not Started (Complete endgame first)

This document outlines the roadmap for adding multiplayer support to the game.

---

## Overview

**Architecture:** Client-hosted (like Stardew Valley)
- One player hosts the game (runs full game logic)
- Other players connect and send actions
- No dedicated server required

**Phases:**
1. Hot-seat (local, same device)
2. LAN/VPN testing (same network or virtual network)
3. Internet play with NAT traversal

---

## Phase 1: Hot-Seat Multiplayer

**Goal:** 2-4 players can play on the same device, passing turns

**Estimated Time:** 4-6 hours

### Features to Implement

**God Selection Screen**
- UI for each player to choose their god (Bicéphales, Augia, Rakun, Le Bâtisseur)
- Visual preview of god powers
- Player color assignment

**Player Management**
```gdscript
# board_manager.gd changes
var players: Array[Player] = []  # 2-4 players
var current_player_index: int = 0

func switch_to_next_player() -> void:
    current_player_index = (current_player_index + 1) % players.size()
    current_player = players[current_player_index]
    # Emit signal for UI updates
    player_changed.emit(current_player)
```

**Turn Indicator UI**
- Show whose turn it is
- Show player's god and color
- "Pass Turn" or "End Turn" triggers switch

**Village Visual Variants**
- 4 different colors/materials for villages (one per god)
- Instantiate correct variant based on `player.god_type`

### Initial Setup (from rules.md lines 46-66)
- Each player places 1 starting tile + village
- First player places first, then clockwise
- All players draw 3 tiles after setup

### Testing Checklist
- [ ] 2 players can complete a full game
- [ ] Turn switching works correctly
- [ ] Each player only sees/controls their own resources
- [ ] Villages are colored per player
- [ ] End game scoring works for all players

---

## Phase 2: Network Multiplayer (Testing)

**Goal:** Play with friends online during development

**Estimated Time:** 4-6 hours for basic networking + chosen NAT solution

### Step 1: Basic Networking (LAN)

**Lobby Scene**
```gdscript
# lobby.gd
extends Control

@onready var ip_input: LineEdit = $IPInput
@onready var host_button: Button = $HostButton
@onready var join_button: Button = $JoinButton

func _on_host_pressed():
    var peer = ENetMultiplayerPeer.new()
    peer.create_server(7777)  # Port 7777
    multiplayer.multiplayer_peer = peer
    print("Hosting on: ", get_local_ip())
    go_to_game()

func _on_join_pressed():
    var peer = ENetMultiplayerPeer.new()
    peer.create_client(ip_input.text, 7777)
    multiplayer.multiplayer_peer = peer
    print("Connecting to: ", ip_input.text)
    go_to_game()

func get_local_ip() -> String:
    # Helper to show host's IP
    return IP.get_local_addresses()[0]
```

**Game Logic Changes**
```gdscript
# board_manager.gd
var is_multiplayer: bool = false
var is_host: bool = false
var local_player_id: int = -1

func _ready():
    if multiplayer.multiplayer_peer:
        is_multiplayer = true
        is_host = multiplayer.is_server()
        local_player_id = multiplayer.get_unique_id()

        # Connect signals
        multiplayer.peer_connected.connect(_on_peer_connected)
        multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Example: Tile placement over network
func place_tile_from_hand(hand_index: int):
    if is_multiplayer and not is_host:
        # Client sends action to host
        rpc_id(1, "_host_place_tile", local_player_id, hand_index)
    else:
        # Host or local game executes directly
        _execute_place_tile(hand_index)

@rpc("any_peer", "call_remote", "reliable")
func _host_place_tile(player_id: int, hand_index: int):
    # Only host processes this
    if not is_host:
        return

    # Validate and execute
    var player = get_player_by_network_id(player_id)
    if player == current_player:
        _execute_place_tile(hand_index)
        # Broadcast state to all clients
        rpc("_sync_game_state", get_game_state())

@rpc("authority", "call_remote", "reliable")
func _sync_game_state(state: Dictionary):
    # All clients receive and apply state
    apply_game_state(state)
```

### Step 2: Choose NAT Traversal Solution

**For Testing with Friends (Pick One):**

#### Option A: Radmin VPN (Recommended for Testing) ⭐

**Setup:**
1. Both download Radmin VPN (free): https://www.radmin-vpn.com/
2. Host creates network: "MyGameTest"
3. Friend joins network
4. Use Radmin IPs (26.x.x.x format) in game

**Code Changes:** None! Just use the LAN code above

**Pros:**
- ✅ No code changes
- ✅ Works instantly
- ✅ Free forever
- ✅ Works in .exe or Godot editor

**Cons:**
- ❌ Both need Radmin installed
- ❌ Only for friend testing

#### Option B: ngrok (No VPN Required)

**Setup:**
1. Host downloads ngrok: https://ngrok.com/
2. Run: `ngrok tcp 7777`
3. Copy URL: `tcp://0.tcp.ngrok.io:12345`
4. Friend enters that in game

**Code Changes:**
```gdscript
# Support hostname:port format in join
func _on_join_pressed():
    var parts = ip_input.text.split(":")
    var host = parts[0]
    var port = int(parts[1]) if parts.size() > 1 else 7777

    var peer = ENetMultiplayerPeer.new()
    peer.create_client(host, port)
    multiplayer.multiplayer_peer = peer
```

**Pros:**
- ✅ Friends don't need software
- ✅ Works in .exe or editor

**Cons:**
- ❌ Host needs ngrok running
- ❌ Free tier has limits
- ❌ URL changes each session

#### Option C: ZeroTier

Similar to Radmin but more reliable, better cross-platform support

**Setup:** https://www.zerotier.com/

---

## Phase 3: Production Solutions

**Goal:** Easy connection for public players (after game is polished)

**Estimated Time:** 6-10 hours

### Option A: Steam Networking (If Releasing on Steam)

**Requirements:**
- Steamworks account (free)
- $100 Steam Direct fee (one-time)
- Godot-Steam plugin: https://github.com/GodotSteam/GodotSteam

**Code Example:**
```gdscript
# With GodotSteam plugin
func _on_host_pressed():
    Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)

func _on_lobby_created(result: int, lobby_id: int):
    if result == 1:  # Success
        Steam.setLobbyJoinable(lobby_id, true)
        print("Lobby created: ", lobby_id)

func _on_join_pressed():
    Steam.joinLobby(lobby_id_from_friend)

# Automatic NAT traversal via Steam
```

**Pros:**
- ✅ Automatic NAT traversal
- ✅ Steam friends integration
- ✅ Invite system built-in
- ✅ Achievements, leaderboards, etc.

**Cons:**
- ❌ $100 fee
- ❌ Players must have Steam
- ❌ More complex setup

### Option B: Small Relay Server (For Standalone/Itch.io)

**Deploy a relay to free hosting:**

**Server Code (Python + WebSockets):**
```python
# relay_server.py
import asyncio
import websockets

clients = {}  # game_id -> set of websockets

async def relay(websocket, path):
    game_id = path.strip('/')

    if game_id not in clients:
        clients[game_id] = set()

    clients[game_id].add(websocket)

    try:
        async for message in websocket:
            # Forward to all clients in same game except sender
            for client in clients[game_id]:
                if client != websocket:
                    await client.send(message)
    finally:
        clients[game_id].remove(websocket)

asyncio.run(websockets.serve(relay, "0.0.0.0", 8765))
```

**Deploy to Railway.app or Render.com (free tier)**

**Godot Client:**
```gdscript
var ws = WebSocketPeer.new()

func _on_host_pressed():
    var game_id = generate_game_code()  # e.g., "ABCD1234"
    ws.connect_to_url("wss://your-relay.railway.app/" + game_id)
    show_game_code(game_id)

func _on_join_pressed():
    var game_id = game_code_input.text
    ws.connect_to_url("wss://your-relay.railway.app/" + game_id)
```

**Pros:**
- ✅ Works everywhere
- ✅ Simple 6-character game codes
- ✅ No VPN needed
- ✅ ~$5/month or free tier

**Cons:**
- ❌ Need to deploy/maintain server
- ❌ Small monthly cost (can use free tier)

### Option C: WebRTC (Advanced)

Full peer-to-peer with built-in NAT traversal. More complex but most flexible.

Godot has WebRTC support: https://docs.godotengine.org/en/stable/classes/class_webrtcpeerdataconnection.html

---

## Implementation Order

1. ✅ Complete endgame & victory system first
2. **Phase 1:** Hot-seat multiplayer (2-4 players, same device)
3. **Phase 2:** Add networking with Radmin VPN for testing
4. Polish the game, get feedback
5. **Phase 3:** Add production NAT solution based on distribution plan

---

## Networking Best Practices for Turn-Based Games

### State Synchronization

**Host is authoritative:**
```gdscript
# Host validates everything
func _host_place_tile(player_id: int, hand_index: int):
    var player = get_player_by_network_id(player_id)

    # Validate it's their turn
    if player != current_player:
        return

    # Validate they can afford it
    var tile_def = player.hand[hand_index]
    if not player.can_place_tile(tile_def, true, true):
        return

    # Execute and broadcast
    _execute_place_tile(hand_index)
    rpc("_sync_game_state", get_game_state())
```

**Clients are display-only:**
- Don't modify game state locally
- Send actions to host
- Receive and display state updates

### What to Sync

**Full State (at turn end):**
```gdscript
func get_game_state() -> Dictionary:
    return {
        "players": serialize_players(),
        "tiles": tile_manager.serialize_tiles(),
        "villages": village_manager.serialize_villages(),
        "current_player_index": current_player_index,
        "current_phase": current_phase,
        "tile_pool_remaining": tile_pool.get_remaining_count()
    }
```

**Delta Updates (during turn):**
- Only send what changed
- "tile_placed", "village_built", "resource_changed", etc.

### Disconnect Handling

```gdscript
func _on_peer_disconnected(id: int):
    if is_host:
        # Pause game, show "Player disconnected"
        # Option to: wait, replace with AI, or end game
        pause_game()
        show_disconnect_dialog(get_player_name(id))
    else:
        # Client lost connection to host
        show_error("Lost connection to host")
        return_to_lobby()
```

---

## Testing Checklist (Network)

### Basic Connectivity
- [ ] Host can start game
- [ ] Client can join with IP
- [ ] Both see each other connect
- [ ] Disconnect handling works

### Gameplay
- [ ] Turn switching syncs correctly
- [ ] Tile placement syncs to all clients
- [ ] Village building syncs
- [ ] Resource changes sync
- [ ] Hand updates sync
- [ ] Harvest phase syncs
- [ ] End turn syncs

### Edge Cases
- [ ] Client disconnects mid-turn
- [ ] Host disconnects (game should end gracefully)
- [ ] Player tries to act out of turn (rejected)
- [ ] Multiple rapid actions (queuing/debouncing)

### Performance
- [ ] No noticeable lag on LAN
- [ ] Acceptable lag on internet (<200ms for turn-based is fine)
- [ ] Game state stays in sync after 10+ turns

---

## Resources

**Godot Multiplayer Docs:**
- High-level: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- RPCs: https://docs.godotengine.org/en/stable/tutorials/networking/rpc.html

**Godot-Steam Plugin:**
- https://github.com/GodotSteam/GodotSteam

**NAT Traversal Tools:**
- Radmin VPN: https://www.radmin-vpn.com/
- ZeroTier: https://www.zerotier.com/
- ngrok: https://ngrok.com/

**Free Hosting for Relay:**
- Railway: https://railway.app/
- Render: https://render.com/
- Fly.io: https://fly.io/

---

## Cost Estimate

| Phase | Hosting Cost | One-Time Cost | Total |
|-------|--------------|---------------|-------|
| Hot-seat | $0 | $0 | $0 |
| LAN/VPN Testing | $0 | $0 | $0 |
| Steam Release | $0 | $100 | $100 |
| Relay Server | $0-5/mo | $0 | $0-60/year |

---

## Next Steps

After completing endgame system:

1. Start with hot-seat multiplayer
2. Test locally with 2-4 players
3. Add basic networking (ENet)
4. Test with friend using Radmin VPN
5. Polish based on feedback
6. Choose production NAT solution

Good luck! 🎮
