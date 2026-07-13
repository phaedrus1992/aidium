# XMPP Compliance Sprint — Implementation Plan

Global constraints:
- **MRC (Manual Reference Counting):** This is pre-ARC Objective-C. Use `retain`/`release`/`dealloc`, `[super dealloc]`, `NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; [pool drain];`
- **Three-letter class prefix:** `AMP` for all new classes
- **Header nullability:** Wrap headers in `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`
- **Line length:** 100 characters max
- **Function length:** ≤100 lines, complexity ≤8
- **No categories for helpers:** Use C functions instead (ObjC rules)
- **No YAGNI:** Build exactly what's specified, nothing more
- **TDD required:** Write failing test first, then minimal implementation

---

## Task 1: XEP-0352 Client State Indication (CSI)

**Issue:** [#103](https://github.com/phaedrus1992/AdiumY/issues/103)

**Namespace:** `urn:xmpp:csi:0`

**Description:** Implement Client State Indication per XEP-0352. CSI lets the client signal whether it's `active` or `inactive` to the server, allowing the server to optimize traffic (e.g., defer push notifications, stanzas). The client sends `<active/>` when it's in the foreground and `<inactive/>` when backgrounded.

**Files to create:**
- `Plugins/Purple Service/AMPurpleJabberCSI.h` — header with `+initialize` feature registration, `initWithAccount:`, `-refreshState`
- `Plugins/Purple Service/AMPurpleJabberCSI.m` — implementation

**Files to modify:**
- `Plugins/Purple Service/ESPurpleJabberAccount.h` — add `@class AMPurpleJabberCSI;` in forward declarations and `AMPurpleJabberCSI *csiController;` ivar
- `Plugins/Purple Service/ESPurpleJabberAccount.m` — add `csiController` initialization in `initAccount` (after correctionController)

**Implementation details:**

1. **+initialize:** Register CSI feature by calling `jabber_add_feature("urn:xmpp:csi:0", NULL);` — this must be done so the account advertises CSI support in disco#info.

2. **initWithAccount:** Store the weak `_account` reference. Do NOT connect any libpurple signal — CSI sends stanzas proactively rather than reacting to incoming stanzas.

3. **refreshState:** This is the core method. It checks whether the app is in the background. If it is and we previously sent `<active/>`, send `<inactive/>` and update state. If it is in the foreground and we previously sent `<inactive/>`, send `<active/>` and update state.

   Send raw XML via:
   ```c
   PurpleConnection *gc = [(CBPurpleAccount *)_account purpleConnection];
   jabber_prpl_send_raw(gc, xmlString.UTF8String, -1);
   ```

   The CSI stanza format:
   ```xml
   <iq type="set" id="csi1">
     <csi xmlns="urn:xmpp:csi:0">
       <active/>
     </csi>
   </iq>
   ```

4. **Listen for app state changes:** Register for `NSApplicationWillResignActiveNotification` and `NSApplicationDidBecomeActiveNotification` to trigger `-refreshState`.

5. **Initial state on connect:** After the account connects (listen for `AIAccountDidConnectNotification`), send `<active/>` as the initial CSI state.

**dealloc:**
- Remove notification observers
- `purple_signals_disconnect_by_handle((__bridge void *)self);`
- Release ivars
- `[super dealloc]`

**Spec references:**
- [XEP-0352](https://xmpp.org/extensions/xep-0352.html)
- Namespace: `urn:xmpp:csi:0`
- Features: `<active/>` and `<inactive/>` as child elements of `<csi/>` in an IQ-set

**Test strategy:**
- Unit test: Verify that when `appDidBecomeActiveNotification:` fires, `jabber_prpl_send_raw` is called with `<active/>` in the XML.
- Unit test: Verify that when `appDidResignActiveNotification:` fires, `jabber_prpl_send_raw` is called with `<inactive/>` in the XML.
- Since these are Objective-C tests, write them as SenTestingKit/XCTest tests following the existing test patterns in the project.

---

## Task 2: XEP-0048 Bookmarks

**Issue:** [#104](https://github.com/phaedrus1992/AdiumY/issues/104)

**Namespace:** `storage:bookmarks` (private XML storage, XEP-0048 v1)

**Description:** Implement Bookmarks per XEP-0048. This allows storing and retrieving conference room bookmarks using private XML storage (XEP-0049). Bookmarks are stored as a `<storage>` element in the `storage:bookmarks` namespace via Private XML Storage.

**Files to create:**
- `Plugins/Purple Service/AMPurpleJabberBookmarks.h` — header
- `Plugins/Purple Service/AMPurpleJabberBookmarks.m` — implementation

**Files to modify:**
- `Plugins/Purple Service/ESPurpleJabberAccount.h` — add `@class AMPurpleJabberBookmarks;` and `AMPurpleJabberBookmarks *bookmarksController;` ivar
- `Plugins/Purple Service/ESPurpleJabberAccount.m` — add initialization

---

## Task 3: XEP-0402 PubSub Bookmarks

**Issue:** [#105](https://github.com/phaedrus1992/AdiumY/issues/105)

**Namespace:** `urn:xmpp:bookmarks:1` (PEP-based, XEP-0402 v1)

**Description:** Implement PEP-based PubSub Bookmarks per XEP-0402. This supersedes XEP-0048 v1 and stores bookmarks via PubSub (PEP) on the user's server.

**Files to create:**
- `Plugins/Purple Service/AMPurpleJabberPubsubBookmarks.h` — header
- `Plugins/Purple Service/AMPurpleJabberPubsubBookmarks.m` — implementation

---

## Task 4: XEP-0393 Message Styling

**Issue:** [#106](https://github.com/phaedrus1992/AdiumY/issues/106)

**Namespace:** `urn:xmpp:message-styling:0`

**Description:** Implement Message Styling per XEP-0393. This provides a standardized way to include simple rich-text styling in XMPP messages, intended as a replacement for XEP-0071 XHTML-IM.

**Files to create:**
- `Plugins/Purple Service/AMPurpleJabberMessageStyling.h` — header
- `Plugins/Purple Service/AMPurpleJabberMessageStyling.m` — implementation
