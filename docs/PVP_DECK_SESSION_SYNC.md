# PvP session and deck synchronization

Deploy order (after review): apply `migrations/0009_pvp_deck_revision.sql` to the existing D1 database, deploy Pages API/Web, then deploy the live PvP Worker. Do not deploy the new Web client before the migration: its deck GET requires `revision`.

The migration adds a `revision` column with default 1 to existing decks and preserves each `cards_json` sequence. A missing deck has revision 0. Every PUT sends the revision seen by the client. D1 updates only the matching revision (or inserts only when absent); a stale writer receives HTTP 409 and the latest revision/cards. No automatic overwrite occurs.

The Web client reads cloud deck after authenticated cloud bootstrap and whenever Cards or Deck Builder opens. Local pending edits are stored by Firebase UID and remain marked unsynchronized until the API confirms a write. A conflict offers an explicit cloud reload; the pending edit remains until the user chooses it. Browser and Android WebView use this same Web client.

The lobby keeps one live socket per UID. A duplicate receives `account_session_active`, then only that new socket closes. The original search or match is not dropped and no history or reward is written for the duplicate attempt. The original socket is released on close/error or after heartbeat timeout.

Manual checks after staging deployment: use two devices with the same UID to attempt simultaneous search and verify the first stays in search/match; repeat with different UIDs; close the first session and verify reconnection; change a deck on A and reopen Cards on B, then reverse; edit both at once and verify the stale save displays conflict without changing the cloud order; test offline pending status and account switch. No production D1 migration or Worker deploy is part of this branch.
