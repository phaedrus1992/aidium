# Design: XEP-0313 message archive management (MAM)

- **Issue:** [#24 — XEP-0313: message archive management (MAM)](../../../../issues/24)
- **Status:** Proposed
- **Depends on:** carbons (#23) implemented first — MAM backfills gaps; carbons carry the live traffic. Without carbons, MAM would be papering over a hole it can't close.
- **Scope:** `Plugins/Purple Service/` (new MAM sync class), routing of fetched history into chats as context, per-account sync-state storage

## 1. Problem

No server-side history: messages sent/received while Adium was offline, or
handled on another device before carbons were enabled, never appear. Adium
only has its local transcript logs.

## 2. Protocol summary

Namespace `urn:xmpp:mam:2` (check the server's disco; `:2` is the floor worth
supporting).

- Query: `<iq type='set'><query xmlns='urn:xmpp:mam:2' queryid='…'>
  <x xmlns='jabber:x:data'>…</x><set xmlns='http://jabber.org/protocol/rsm'>…</set></query></iq>`
  with data-form fields (`with`, `start`, `end`, `after-id`).
- Results arrive as individual `<message>` stanzas containing
  `<result xmlns='urn:xmpp:mam:2' queryid='…' id='<archive id>'>` wrapping a
  `<forwarded xmlns='urn:xmpp:forward:0'>` with `<delay/>` timestamp + the
  original message. The iq result carries an RSM `<set>` for paging and a
  `complete` attribute.
- **XEP-0359 stanza ids** are the dedup currency: servers annotate live
  messages with `<stanza-id xmlns='urn:xmpp:sid:0' id='<archive id>'
  by='<own bare JID>'/>`. Only trust `stanza-id` where `by` == own bare JID.

## 3. Design

### 3.1 Sync strategy (keep it dumb)

Per account, persist one value: `lastArchiveID` (account preference via the
existing account-preference machinery in `CBPurpleAccount`/`AIAccount`).

- On signed-on: if `lastArchiveID` exists, query the account archive with
  `after-id = lastArchiveID`, page forward (RSM `after`) until `complete`.
  If it doesn't exist (first run), fetch only the last page
  (`<set><max>50</max><before/></set>`) — do **not** slurp years of archive.
- During the session: for every live incoming/outgoing-carbon message, record
  its trusted `stanza-id` as the new `lastArchiveID` (they arrive in archive
  order). This keeps the watermark current so the next login fetches only the
  gap.
- No timestamp-based queries — `after-id` sidesteps clock skew entirely.

### 3.2 New class `AMPurpleJabberMAM` (Purple Service)

Same ownership pattern as the other `AMPurpleJabber*` helpers (one per
`ESPurpleJabberAccount`, wired to the xmlnode signals; raw IQ send via the
XML-console `send_raw` mechanism):

1. Disco own bare JID for `urn:xmpp:mam:2` on signed-on; bail quietly if
   unsupported.
2. Run the 3.1 query; collect results matching its `queryid` from the
   `jabber-receiving-xmlnode` signal and swallow those stanzas (they must not
   hit the normal live-message path).
3. Session watermark tracking (3.1) also lives here — it's already looking at
   every incoming stanza.

### 3.3 Dedup + display

For each fetched result:

- **Drop** if its archive id ≤ the pre-query `lastArchiveID` set (defensive;
  `after-id` should prevent this) or if the archive id was already seen live
  this session.
- **Local-log dedup for the first-run backfill:** the last-page bootstrap
  overlaps local transcript logs. Rather than parsing logs to compare, dedup
  by (sender, body, timestamp rounded to the minute) against messages already
  displayed in the open chat, and accept that closed-chat first-run backfill
  may write near-duplicate lines into logs once. Say so in the PR. (Log
  parsing for exact dedup is real complexity for a one-time cosmetic issue —
  the `stanza-id` watermark makes every subsequent sync exact.)
- **Display:** route fetched messages as *history*, not live content — Adium
  already has a content type for previous-conversation context
  (`AIContentContext`, used by the message-history-on-open feature; see how
  `AILoggerPlugin`/message history inserts context). History content must not
  fire sounds, notifications, or unread badges.
- **Logging:** fetched messages are appended to transcript logs like normal
  content (that's the point — the local archive becomes complete). Outgoing
  messages from other devices get logged as outgoing.
- Order: within a chat, insert paged results oldest-first before marking the
  chat ready; simplest is to buffer a chat's results until the query
  completes, then emit in order.

### 3.4 Preference

Per-account checkbox "Fetch message history from server", default on, in
`ESPurpleJabberAccountViewController` next to the carbons pref from #23.

## 4. Verification

- Unit tests: query IQ construction (`after-id`, RSM paging), result
  unwrapping, `by`-attribute trust check on stanza-ids, watermark advance
  logic, dedup rules. All xmlnode-level, headless.
- Manual (two devices, MAM-enabled server):
  1. Quit Adium; converse from phone; relaunch Adium → missed messages appear
     in the chat as context and in the transcript log, no notification storm.
  2. Relaunch again immediately → nothing duplicates (watermark works).
  3. First-run on an account with server history → last ~50 messages appear
     once.

## 5. Out of scope

- MUC archives (groupchat MAM) — different `to`, different dedup, later issue.
- Full-history import/backfill UI.
- OMEMO-encrypted archived messages (undecryptable until #27; they render as
  the standard "encrypted message" body — acceptable).
- Log-viewer integration beyond what normal transcript logging provides.
