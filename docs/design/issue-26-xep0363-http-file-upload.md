# Design: XEP-0363 HTTP file upload

- **Issue:** [#26 — XEP-0363: HTTP file upload](../../../../issues/26)
- **Status:** Proposed
- **Scope:** `Plugins/Purple Service/` (new `AMPurpleJabberHTTPUpload` + `ESPurpleJabberAccount` send-path hook), no changes to the legacy SI/SOCKS5/IBB stack

## 1. Problem

Adium's XMPP file transfer is the p2p stack only (SI/0096 + SOCKS5/0065 +
IBB/0047, all in libpurple). Modern mobile clients (Conversations, Monal,
Siskin) are HTTP-upload-only, so sending a file to them simply fails. XEP-0363
must become the default send path; the legacy stack stays as receive support
and fallback. (The issue mentions superseding the imgur/imageshack image
uploading plugin — that plugin is already gone from the tree; nothing to
remove.)

## 2. Protocol summary

Namespace `urn:xmpp:http:upload:0`.

1. **Discover:** on login, disco#items the server, disco#info each item; the
   upload service advertises `urn:xmpp:http:upload:0` and (in its disco form)
   `max-file-size`.
2. **Request a slot:** `<iq type='get' to='<upload service>'>
   <request xmlns='urn:xmpp:http:upload:0' filename='…' size='…'
   content-type='…'/></iq>` → response contains `<slot>` with a `<put>` URL
   (plus optional headers to copy: only `Authorization`, `Cookie`, `Expires`
   are allowed — ignore others) and a `<get>` URL.
3. **Upload:** HTTP PUT the file bytes to the put URL with the given headers
   and content-type. Expect 201.
4. **Share:** send a normal `<message>` whose `<body>` is the get URL and add
   `<x xmlns='jabber:x:oob'><url><get URL></url></x>`.

## 3. Design

### 3.1 Where it hooks in

Adium's send-file flow: `Source/ESFileTransferController` creates an
`ESFileTransfer` (`Frameworks/Adium/Source/ESFileTransfer.h`) and hands it to
the account; `CBPurpleAccount` normally routes it into a libpurple
`PurpleXfer` (bridged by `Plugins/Purple Service/adiumPurpleFt.m`).

Override the send in `ESPurpleJabberAccount`: if the account's server has a
discovered upload service **and** the file fits `max-file-size`, take the HTTP
path; otherwise fall through to `super` (legacy PurpleXfer path). Receiving
legacy transfers is untouched.

### 3.2 New class `AMPurpleJabberHTTPUpload` (Purple Service)

One instance per `ESPurpleJabberAccount` (same ownership pattern as
`AMPurpleJabberAdHocServer`). Responsibilities:

- **Discovery** on signed-on; cache service JID + max size on the instance.
  Reuse the existing disco machinery in `AMPurpleJabberNode` /
  `AMPurpleJabberServiceDiscoveryBrowsing` if it fits; otherwise raw IQs.
- **Raw stanza I/O:** send the slot-request IQ and match its reply. Use the
  same raw-send mechanism as the XML console
  (`AMXMLConsoleController.m` — the jabber prpl's `send_raw`), and the
  `jabber-receiving-xmlnode` signal to catch the result IQ by id.
- **Upload** with `NSURLSession` uploadTask (`PUT`, `Content-Type`,
  whitelisted slot headers only, `Content-Length` = exact file size).
  Sandbox/ATS note: put URLs are HTTPS in practice; if a server hands out
  http://, let ATS block it rather than adding exceptions.
- **Progress:** drive the originating `ESFileTransfer` object from the
  session delegate's didSendBodyData callback so the existing transfer-
  progress window works unchanged. Map completion/failure onto the transfer's
  normal complete/cancel states (see how `adiumPurpleFt.m` updates progress
  for the state names).
- **Share message:** on 201, send the message via the account's normal
  message-send path with the get URL as the body, then append the
  `jabber:x:oob` element via the `jabber-sending-xmlnode` hook (match on the
  just-sent body/URL — or send the whole stanza raw; implementer's choice,
  raw is simpler and self-contained).

### 3.3 Failure handling

Every failure (no slot, IQ error, HTTP non-201, timeout) must surface on the
`ESFileTransfer` as a failed transfer with the server's error text — never
silently fall back to the legacy path mid-transfer (peer expectations differ;
a clean error beats a mystery SI offer). Fallback to legacy happens only at
the routing decision in 3.1, before anything is attempted.

### 3.4 Received URLs

Incoming 0363 shares are ordinary messages with a URL body (+oob). Adium
already renders URLs as links — ship that. Inline image preview is a separate
feature; do not build it here.

## 4. Verification

- Unit tests: slot-request IQ construction (filename escaping, size,
  content-type), slot-response parsing (headers whitelist, malformed
  responses), max-size routing decision, error mapping. Stanza handling is
  xmlnode C API — testable headlessly; mock the HTTP layer at NSURLSession
  boundary.
- Manual against a real server (Prosody/ejabberd with mod_http_upload):
  1. Send an image to Conversations — arrives as downloadable media.
  2. Send a file larger than `max-file-size` — legacy path or clean error.
  3. Send to a contact on a server without upload — legacy p2p still works.
  4. Kill network mid-upload — transfer window shows failure, no ghost
     message sent.

## 5. Out of scope

- OMEMO-encrypted uploads (`aesgcm://`, XEP-0454) — belongs to #27.
- Inline media display of received URLs.
- Group chat: v1 may simply allow it (upload+URL works in MUC) but MUC disco
  gating is untested; note actual behavior in the PR.
- Removing the legacy SI/SOCKS5/IBB stack — it stays as fallback.
