# Upstream libpurple 2.14.x + Full ARC Migration

**Date:** 2026-07-08
**Status:** Approved design

## Goals

- Build against vanilla upstream libpurple 2.14.x from Pidgin — no Adium fork.
- Newest upstream versions of all dependencies; no old pinned versions.
- Fully in-tree build: pinned git submodules preferred, checked-in SHA256-recorded
  release tarballs otherwise. `git clone --recursive && build` with zero network
  fetches.
- Full ARC across all first-party targets.
- Universal binaries: arm64 + x86_64.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| libpurple version | Upstream 2.14.x (latest stable at plan time) | Same API family the existing AdiumLibpurple adapter speaks; purple3 is unreleased and would force an adapter rewrite |
| Protocols | Living only: XMPP, IRC, Bonjour, SIMPLE | Dead services (AIM, MSN, Yahoo, Gadu-Gadu, Sametime, MySpace, GTalk, LiveJournal, MobileMe) dropped, shrinking the dependency tree |
| Sequencing | Phase 1: deps + libpurple (MRR). Phase 2: ARC. | The reverted ARC attempt showed that mixing API deltas with memory-management changes makes every failure ambiguous |
| OTR | Keep | Flagship privacy feature; costs libotr + libgcrypt + libgpg-error, all clean universal builds |
| TLS | Port to Network.framework in this effort | SecureTransport (current ssl-cdsa.c) is deprecated since macOS 10.15; do the port now rather than carry deprecated API forward |
| Build architecture | Extend existing `Dependencies/build-phases/` pipeline | gettext → glib phases, meson cross files, framework packaging, and install_name rewriting already work; reuse them |

## End state

Adium builds universal entirely in-tree. libpurple is vanilla upstream with
Adium-specific behavior carried as in-tree purple plugins
(`Plugins/Purple Service/libpurple_extensions/`), never as fork patches.
All first-party targets compile with ARC. Checked-in prebuilt binaries in
`Frameworks/` are replaced by built-from-source frameworks or deleted.

## Phase 1 — dependency tree + upstream libpurple (MRR throughout)

### Vendoring

Per-dependency, decided at plan time by mirror availability:

- **Pinned git submodule** where an official git repo or mirror exists
  (glib and libxml2 on GitLab, gettext on Savannah, etc.).
- **Checked-in release tarball** with recorded SHA256 where not. Pidgin's
  canonical repo is Mercurial; the release tarball is the honest choice unless
  the GitHub mirror proves current and tag-pinned.

The existing `build-universal-deps.sh` phases stop downloading at build time
and read vendored sources instead.

### Build chain

Extends the existing gettext → glib phases with, in dependency order:

1. `libxml2` (XMPP parsing)
2. `libidn` (XMPP stringprep)
3. `cyrus-sasl` (XMPP SASL auth)
4. `libgpg-error` → `libgcrypt` → `libotr` (OTR)
5. `libpurple 2.14.x` with static prpls (jabber, irc, simple, bonjour)
   compiled into `libpurple.framework` — the shape the old fork shipped

Likely droppable, confirmed during planning: `json-glib`, `meanwhile` (served
dead protocols). Deleted outright: `Frameworks/libmeanwhile.framework`, the
meanwhile patches in `Dependencies/patches/`, and the ancient generated
autotools `Dependencies/Makefile`. Each remaining prebuilt binary framework is
deleted as its built-from-source replacement lands.

### Fork-delta audit

Compile Purple Service against vanilla 2.14 headers and catalogue every
missing symbol or behavior. Each delta is re-homed as exactly one of:

- (a) an in-tree purple plugin under `libpurple_extensions/`
- (b) Adium-side Objective-C code
- (c) dead code — delete

This is the step the reverted ARC commit tripped over; it is done
deliberately and completely before anything else in Purple Service changes.
This audit is the schedule wildcard for the whole effort.

### Dead-service cleanup

Delete Purple Service classes, nibs, and resources for dead services:
Oscar/AIM, MobileMe, GTalk, LiveJournal, Yahoo, MSN, MySpace, Sametime,
Gadu-Gadu (`AIPurpleOscar*`, `AIMobileMe*`, `AIGTalk*`, `AILiveJournal*`,
`oscar-adium.c`, `auth_gtalk.c`, and kin). Generic XMPP, IRC, Bonjour, and
SIMPLE support stays.

### TLS — Network.framework port

Replace `ssl-cdsa.c` with a new purple SSL-ops plugin backed by
`nw_connection` / `sec_protocol_options`:

- The Keychain-integrated trust UI (`AIPurpleCertificateTrustWarningAlert`)
  survives: `sec_protocol_verify_block` hands the `sec_trust` to the existing
  alert flow.
- `ssl-cdsa.c` and `ssl-openssl.c` are deleted once the new backend passes
  against live XMPP and IRC servers.
- Network.framework's proxy handling differs from SecureTransport's; Adium's
  proxy settings path gets explicit testing.

## Phase 2 — ARC, target by target

Conversion order (leaf dependencies first, C-callback hot spots last):

1. AIUtilities framework
2. Adium framework
3. Source / Adium.app
4. UI plugins
5. Purple Service / AdiumLibpurple

Mechanics per target:

- Flip `CLANG_ENABLE_OBJC_ARC = YES`, fix all errors and warnings.
- Audit every `void *` context pointer crossing into glib/libpurple callbacks
  for correct `__bridge` / `__bridge_retained` / `__bridge_transfer` pairing.
- One commit per target; each commit builds and launches.
- No `-fno-objc-arc` file exceptions unless justified with an inline comment.
- MMTabBarView submodule stays as upstream ships it.

## Verification

- CI builds both architectures and the merged universal app;
  `lipo -archs` asserted on every produced binary.
- Smoke test per milestone: app launches; XMPP and IRC accounts connect over
  TLS; OTR session establishes.
- Leaks/zombies instrumentation passes on Purple Service after its ARC flip.
- Existing unit test targets stay green.

## Risks

- **Fork-delta audit** is the schedule wildcard — unknown surface until run.
- **Pidgin 2.14 on current Xcode**: C from another era; expect targeted
  warning/deprecation suppression in the deps build (not in first-party code).
- **Network.framework proxy behavior** differs from SecureTransport;
  regression risk in Adium's proxy settings.

## Out of scope

- purple3 migration (possible later project; the adapter boundary stays clean
  to keep it feasible).
- Third-party prpl plugin support beyond not breaking the plugin loading path.
- ARC conversion of third-party submodule code.
