# Design: Migrate SUUpdater (Sparkle 1.x API) to SPUStandardUpdaterController

- **Issue:** [#69 — Migrate SUUpdater API usage to Sparkle 2.x SPUUpdater](../../../../issues/69)
- **Status:** Proposed
- **Scope:** `Source/AIAdium.h`, `Source/AIAdium.m`, `Resources/MainMenu.xib`, sanity check of `Plugins/General Preferences/ESGeneralPreferences.m`

## 1. Current state

The app uses the Sparkle 1.x `SUUpdater` API, which Sparkle 2.9.4 (vendored at
`Frameworks/Sparkle.framework`) still supports only through a deprecated
compatibility shim:

- `Resources/MainMenu.xib:620` — a custom object (`id="7246"`) with
  `customClass="SUUpdater"`. The "Check for Updates…" menu item sends
  `checkForUpdates:` to it (`MainMenu.xib:35`), and it is connected to AIAdium's
  outlet.
- `Source/AIAdium.h:27,39` — `@class … SUUpdater;` and
  `IBOutlet SUUpdater *updater;`
- `Source/AIAdium.h:17` — `#import <Sparkle/SUVersionComparisonProtocol.h>`
- `Source/AIAdium.m:1137` —
  `- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater sendingSystemProfile:(BOOL)sendProfileInfo`
  (appends profile/beta query parameters to the feed request)
- `Source/AIAdium.m:1232` —
  `- (id<SUVersionComparison>)versionComparatorForUpdater:(SUUpdater *)updater`
  (returns Adium's custom version comparator)

Preferences (`Plugins/General Preferences/ESGeneralPreferences.m:88,159-165`)
toggle Sparkle behavior by writing `SUEnableAutomaticChecks` and
`SUSendProfileInfo` directly to `NSUserDefaults` — Sparkle 2 reads the same keys,
so this code is compatible as-is.

Note: the active `Resources/Info.plist` currently carries no `SUFeedURL` /
`SUPublicEDKey`; those are handled by issue #70. This migration is purely the
runtime API.

## 2. Design

Use `SPUStandardUpdaterController`, which is Sparkle 2's drop-in replacement
designed for exactly this nib-instantiated pattern.

### 2.1 `Resources/MainMenu.xib`

1. Change the custom object's class from `SUUpdater` to
   `SPUStandardUpdaterController` (object `id="7246"`, `userLabel` update too).
2. The menu item's `checkForUpdates:` action target stays the same object —
   `SPUStandardUpdaterController` implements `-checkForUpdates:` and
   automatically validates the menu item.
3. Add a connection for the controller's `updaterDelegate` outlet → the AIAdium
   object (the app delegate object in the same xib). This replaces however the
   old `SUUpdater` delegate was wired (verify: if the xib had a `delegate`
   outlet on the old object, replace it; if delegate was never wired, wire
   `updaterDelegate` now — the two delegate methods in AIAdium.m only ever fire
   via this connection).

Edit the xib as XML (it is flat-XML format); keep the same object id so the
existing outlet connections need minimal touching.

### 2.2 `Source/AIAdium.h`

```objc
// before
#import <Sparkle/SUVersionComparisonProtocol.h>
@class AICorePluginLoader, AICoreComponentLoader, SUUpdater;
    IBOutlet SUUpdater *updater;

// after
#import <Sparkle/Sparkle.h>
@class AICorePluginLoader, AICoreComponentLoader, SPUStandardUpdaterController;
    IBOutlet SPUStandardUpdaterController *updaterController;
```

Declare AIAdium as conforming to `<SPUUpdaterDelegate>` (in the class extension
in AIAdium.m is fine if the header should stay lean).

### 2.3 `Source/AIAdium.m`

1. `feedParametersForUpdater:sendingSystemProfile:` — same selector exists in
   `SPUUpdaterDelegate`; only the parameter type changes:

   ```objc
   - (NSArray<NSDictionary<NSString *, NSString *> *> *)feedParametersForUpdater:(SPUUpdater *)updater
                                                          sendingSystemProfile:(BOOL)sendingProfile
   ```

   Body unchanged (the defaults migration + profile/beta params logic at
   lines ~1107-1230).

2. `versionComparatorForUpdater:` — same selector in `SPUUpdaterDelegate`,
   parameter becomes `SPUUpdater *`. Body unchanged.

3. Any direct use of the `updater` ivar elsewhere in AIAdium.m: reach the
   underlying updater as `updaterController.updater` (type `SPUUpdater`).
   As of this writing the ivar's only purpose is the xib connection — verify
   with `rg -n '\bupdater\b' Source/AIAdium.m` and adjust survivors.

### 2.4 Behavior notes for the implementer

- `SPUStandardUpdaterController` starts the updater automatically on nib load
  (`startsUpdater=YES` default). No code change needed for startup checks; the
  `SUCheckAtStartup`/`SUScheduledCheckInterval` behavior is governed by
  defaults/Info.plist keys as before.
- `SUEnableAutomaticChecks` / `SUSendProfileInfo` defaults keys are read by
  Sparkle 2 unchanged — `ESGeneralPreferences.m` needs no edits. Confirm at
  runtime (toggle the pref, relaunch, inspect `SPUUpdater.automaticallyChecksForUpdates`).
- Sparkle 2 requires EdDSA keys or Apple code signing for update validation at
  actual update time; that's #70's problem, not a blocker for compiling and
  wiring this API.

## 3. Verification

1. Build with zero Sparkle deprecation warnings
   (`rg "SUUpdater" Source/ Resources/MainMenu.xib` → no matches).
2. Launch app: "Check for Updates…" menu item is enabled and triggers a check
   (against a missing feed this shows Sparkle's "can't load appcast" alert —
   that proves the wiring; the feed itself is #70).
3. Set a breakpoint / NSLog in `feedParametersForUpdater:` and confirm it fires
   during a check (proves `updaterDelegate` connection).
4. Toggle "Automatically check for updates" in General preferences; confirm
   `SPUUpdater.automaticallyChecksForUpdates` follows it.

## 4. Out of scope

- Appcast generation/EdDSA keys (#70), crash reporter Sparkle usage (#68).
- Localized `GeneralPreferences.nib` designable files mentioning Sparkle headers —
  stale generated metadata, harmless.
