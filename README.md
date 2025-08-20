# ⏰ Time-Based Access NFTs

Grant and expire access permissions at exact block heights using NFT technology on the Stacks blockchain.

## 🚀 Features

- 🎫 **Mint Time-Access NFTs** - Create NFTs with defined access windows
- ⏳ **Automatic Expiration** - Access automatically expires at specified block heights
- 🔐 **Permission Management** - Grant/revoke access to specific users
- 📅 **Flexible Timing** - Set start and end blocks for access periods
- 🛡️ **Owner Controls** - Only NFT owners can manage access permissions
- ⚡ **Real-time Verification** - Check access status at any time

## 📋 Contract Functions

### Public Functions

#### `mint-time-access-nft`
```clarity
(mint-time-access-nft recipient title description image start-block end-block)
```
Mints a new time-based access NFT with specified access window.

#### `grant-access` / `revoke-access`
```clarity
(grant-access token-id user)
(revoke-access token-id user)
```
Grant or revoke access permissions for specific users.

#### `verify-access`
```clarity
(verify-access token-id)
```
Verify if caller has active access to the NFT.

#### `extend-access`
```clarity
(extend-access token-id new-end-block)
```
Extend the access window end time (owners only).

### Read-Only Functions

#### `has-access`
```clarity
(has-access token-id user)
```
Check if a user has active access to an NFT.

#### `is-access-active`
```clarity
(is-access-active token-id)
```
Check if the NFT's access window is currently active.

#### `get-access-window`
```clarity
(get-access-window token-id)
```
Get the complete access window information including current status.

## 🛠️ Usage Examples

### Deploy the Contract
```bash
clarinet deploy
```

### Mint a Time-Access NFT
```bash
clarinet console
```

```clarity
(contract-call? .time-based-access-nfts mint-time-access-nft 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  "Event Access"
  "Access to exclusive event"
  "https://example.com/image.png"
  u1000
  u2000)
```

### Grant Access to User
```clarity
(contract-call? .time-based-access-nfts grant-access u1 'ST1EXAMPLE...)
```

### Verify Access
```clarity
(contract-call? .time-based-access-nfts has-access u1 'ST1EXAMPLE...)
```

## 🏗️ Development Setup

1. Install [Clarinet](https://github.com/hirosystems/clarinet)
2. Clone this repository
3. Run tests:
   ```bash
   clarinet test
   ```
4. Check contract:
   ```bash
   clarinet check
   ```

## 📊 Use Cases

- 🎪 **Event Tickets** - Temporary access to events
- 📚 **Content Subscriptions** - Time-limited content access
- 🏢 **Facility Access** - Building or room access permissions
- 🎮 **Gaming Passes** - Limited-time game features
- 📋 **Service Licenses** - Temporary service authorizations

## 🔒 Security Features

- Only contract owner can mint NFTs
- Only NFT owners can manage permissions
- Automatic time-based access control
- Pause/unpause functionality for emergencies
- Built on proven Stacks NFT standards

## 📄 License

MIT License - feel free to use in your projects!
