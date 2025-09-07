Charity Burn Contract

📖 Overview

The Charity Burn Contract allows users to “burn” STX tokens in a unique way: instead of simply destroying tokens, the burned amount is automatically redirected as a donation to a designated charity address. A small percentage fee is applied to each burn, which goes to the contract owner for operational costs.

This contract promotes transparent charitable giving on the Stacks blockchain while maintaining auditable records of all burns and donations.

✨ Features

Charity Donations via Burning
Users can donate STX by burning tokens, with the donation automatically sent to the configured charity address.

Fee System
A configurable fee percentage (default 1%) is applied to each burn and forwarded to the contract owner.

Configurable Charity
The contract owner can set or change the charity address. The full history of charities is preserved.

Pause/Unpause Controls
The contract owner can pause/unpause the contract or activate an emergency pause to halt operations.

Event Tracking & Reporting

Burn events are logged with details (amount, burner, charity, block, timestamp).

Daily statistics are recorded for monitoring community engagement.

Users can query their impact reports (total burned, donation impact, and activity count).

Advanced Burn Methods

Burn with message: Users can attach a short message (max 280 chars).

Batch burn: Users can burn multiple amounts in one transaction.

Fee Management
The contract owner can withdraw collected fees when needed.

🔐 Access Control

Owner-only functions:

set-charity-address

pause-contract / unpause-contract / emergency-pause

withdraw-fees

transfer-ownership

Public functions:

burn-for-charity

burn-for-charity-with-message

batch-burn-for-charity

get-user-impact-report

📊 Data Tracked

Global stats: total burned, total donated, total fees collected.

Per-user stats: total burned amount, burn count.

Per-charity stats: total received, last set block.

Daily stats: total burned per day (by block height).

Event log: detailed record of each burn with metadata.

⚠️ Error Codes

err-owner-only (u100): Caller not authorized.

err-insufficient-balance (u101): User has insufficient STX.

err-invalid-amount (u102): Burn amount invalid.

err-contract-paused (u103): Contract is paused.

err-charity-not-set (u104): No charity configured.

err-min-burn-amount (u105): Burn amount below minimum (1 STX).

err-max-burn-exceeded (u106): Burn amount exceeds maximum (100,000 STX).

err-charity-same-as-current (u107): New charity cannot equal current.

🚀 Example Workflow

Owner sets a charity address via set-charity-address.

User calls burn-for-charity with a valid amount.

Contract:

Transfers net donation to the charity.

Transfers fee to the owner.

Updates global and user stats.

Records a burn event.

Anyone can query:

Total burned/donated.

Individual user contributions.

Daily burn stats.

Charity history.

📌 Usage Scenarios

Transparent donation tracking for charitable organizations.

Community-driven fundraising campaigns.

Gamified philanthropy (leaderboards, user ranks).

Proof-of-impact applications.

🛠️ Development Notes

Contract is initialized with no charity set (none).

Only the contract owner can configure the charity or withdraw fees.

Rank calculation is currently simplified (u1) and can be expanded.