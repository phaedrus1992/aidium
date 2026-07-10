# Design: Reliable framework generation in the dependency build

- **Issue:** [#55 — Dependencies build system needs to create proper macOS frameworks](../../../../issues/55)
- **Status:** Proposed
- **Scope:** `Dependencies/build-universal-deps.sh`, `Dependencies/build-common.sh`, `Dependencies/build-phases/*.sh`, two xcconfig/project references

## 1. Problem

A full `Dependencies/build-universal-deps.sh` run does not reliably produce the
framework bundles the Xcode project needs. Current on-disk state after the last
run(s):

| Framework | State |
|---|---|
| libgcrypt.framework | missing entirely (blocks Adium target: libotr's `context.h` includes `gcrypt.h`) |
| libffi.framework | missing entirely (referenced 7× in `Adium.xcodeproj/project.pbxproj`) |
| glib.framework | partial: `Headers/` only — no binary, no `Resources/`, no `Info.plist`; top-level `glib` symlink dangles |
| libgio/libgmodule/libgobject/libgthread.framework | partial: `Versions/A/Headers/` only — no binary, no symlinks, no plist |
| libotr.framework | binary present but links `Dependencies/sandbox-*/lib/libgcrypt.20.dylib` and `libgpg-error.0.dylib` — **those files no longer exist**; framework cannot load |
| libpurple.framework | binary present but links six sandbox-absolute dylibs (glib family, libintl, libxml2) — unloadable outside this checkout, and dangling as soon as another phase nukes the sandbox |
| libintl.framework | binary OK, but `Headers/` contains a symlink to the absolute path `$REPO/Dependencies/build/include/libintl.h` (breaks on `--clean`, breaks relocatability) and is contaminated with glib/gio headers |
| libgpg-error, libpcre2-8, libxml2 | binary + deps OK |

All of these frameworks are in `.gitignore` (regenerated artifacts), so a fresh
clone cannot build Adium until this script completes correctly end-to-end.

## 2. Root cause analysis

### 2.1 Why frameworks go missing: fail-late architecture

The script is `bash -eu` fail-fast, but the two steps that make frameworks
*usable* run only **after every phase has succeeded**
(`build-universal-deps.sh:80-88`):

```
phase1 … phase9  →  rewrite_dependency_links  →  cleanup_build_dirs  →  summary
```

Any single phase failure (observed: gcrypt's x86_64 build — `sandbox-x86_64/lib`
has no `libgcrypt.20.dylib` while `build/lib/libgcrypt.20.dylib` from an older
run exists) aborts the whole script. Consequences:

- No framework is created for the failed phase or any later phase.
- `rewrite_dependency_links` never runs, so **every** framework built earlier in
  that run keeps absolute sandbox paths.
- `cleanup_build_dirs` never runs — which is the only reason the sandbox paths
  in `libotr`/`libpurple` resolved at all for a while.

The on-disk state (sandboxes still present, `libotr` pointing at deleted sandbox
files, missing gcrypt/ffi frameworks) is exactly the fingerprint of an aborted
run. This answers the issue's "why aren't all frameworks being created?".

### 2.2 Ephemeral sandboxes are baked into binaries

`build_for_archs` (`build-common.sh:73-117`) does `rm -rf "$SANDBOX"` at the
start of **every phase, per arch**. But autotools/meson record install names as
`$SANDBOX/lib/libfoo.N.dylib`, so every consumer built in a later phase embeds a
path that the *same run* is about to delete. The design depends entirely on the
end-of-run rewrite — which, per 2.1, frequently never executes.

### 2.3 `rewrite_dependency_links` is structurally fragile (`build-common.sh:194-242`)

- Matches deps by **substring against framework directories that happen to
  exist** — a dep whose framework wasn't created yet (libgcrypt today) is
  silently skipped and stays absolute, forever.
- `install_name_tool … 2>/dev/null || true` swallows every failure.
- Runs once, globally, at the end (see 2.1).
- Rewrites to `@executable_path/../Frameworks/…` while other frameworks in the
  tree use `@rpath/…` IDs (libintl, libotr were hand-fixed; Sparkle/FriBidi are
  `@rpath`) — two conventions, neither enforced.

### 2.4 `build_framework` is not idempotent (`build-common.sh:121-188`)

- Never removes a stale bundle; it layers `cp` over whatever exists. Partial
  bundles from earlier script revisions (glib and the four sub-frameworks)
  persist indefinitely — the issue's "not regenerated when built dylibs change".
- `cp -R` **preserves symlinks**, which is how an absolute symlink to
  `Dependencies/build/include/libintl.h` ended up *inside* a framework's
  `Headers/`.
- Header sources are wrong in two ways:
  - gettext passes `$BUILD_DIR/include` — the *shared* include dir, so on
    re-runs libintl.framework swallows glib/libxml2/libotr headers
    (`build-phases/build-gettext.sh:38`).
  - libxml2 and libotr pass `$SANDBOX_X86_64/include/...` — an ephemeral dir
    (`build-libxml2.sh:36`, `build-libotr.sh:36`).
- `install_name_tool -id … 2>/dev/null || true` — silent failure again.
- No re-sign after `install_name_tool`; arm64 slices with invalidated
  signatures are killed by dyld at load.

### 2.5 Name mismatches with the Xcode project

- Build creates `libgpg-error.framework`; `Frameworks/AIUtilities/xcconfigs/Adium.xcconfig:4`
  and the AIUtilities pbxproj reference `libgpgerror.framework` (no hyphen).
- The end-of-script summary probes `Versions/A/$name` **or** `Versions/A/lib$name`
  and prints "(no binary)" without failing — a broken tree still exits 0.

## 3. Design

### Goals

1. One successful phase ⇒ one complete, loadable, relocatable framework —
   independent of whether later phases succeed.
2. Deterministic regeneration: re-running a phase always produces the same
   bundle from scratch.
3. Loud failure: the script exits non-zero when any expected framework is
   missing or broken, and says which.

### Non-goals

- Changing which libraries are built, their versions, or the vendored-tarball
  scheme (works fine).
- arm64 slices for the *tracked* prebuilt frameworks (FriBidi, LMX, Sparkle) —
  separate issue.

### 3.1 Make each phase self-contained (fixes 2.1, 2.2)

Move dependency rewriting **into `build_framework`**, executed per phase,
instead of a global end-of-run pass. Phase order already follows the dependency
graph (libffi → gettext → … → libpurple), so by the time a consumer is built,
every framework it needs already exists. After this change,
`rewrite_dependency_links` is deleted and `--only=<phase>` regenerates that
phase's framework completely.

### 3.2 Explicit dylib→framework map (fixes 2.3)

Replace substring matching with a declarative table in `build-common.sh`
(bash-3.2-compatible parallel strings):

```
# dylib basename        framework      binary
libffi.8.dylib          libffi         libffi
libintl.8.dylib         libintl        libintl
libglib-2.0.0.dylib     glib           glib
libgmodule-2.0.0.dylib  libgmodule     libgmodule
libgobject-2.0.0.dylib  libgobject     libgobject
libgthread-2.0.0.dylib  libgthread     libgthread
libgio-2.0.0.dylib      libgio         libgio
libpcre2-8.0.dylib      libpcre2-8     libpcre2-8
libxml2.16.dylib        libxml2        libxml2
libgpg-error.0.dylib    libgpg-error   libgpg-error
libgcrypt.20.dylib      libgcrypt      libgcrypt
libotr.5.dylib          libotr         libotr
libpurple.0.dylib       libpurple      libpurple
```

Rewrite rule inside `build_framework`, applied to every non-system dep of the
copied binary:

- basename in map → `install_name_tool -change <old> @rpath/<fw>.framework/Versions/A/<bin>`
- basename **not** in map → **fail the phase** with the unmapped path. No
  `2>/dev/null`, no `|| true`.

### 3.3 One install-name convention: `@rpath` (fixes 2.3 mixed conventions)

- `LC_ID_DYLIB`: `@rpath/<name>.framework/Versions/A/<binary>` (replaces the
  current `@executable_path/...` id at `build-common.sh:142-144`).
- Consumers already carry the needed rpaths:
  `LD_RUNPATH_SEARCH_PATHS = @executable_path/../Frameworks` (Adium app,
  AdiumLibpurple) and `@loader_path/../Frameworks` (unit tests) — verified in
  `Frameworks/AIUtilities/xcconfigs/*.xcconfig`.
- This matches Sparkle/FriBidi and the two hand-fixed frameworks (libintl,
  libotr), which are already `@rpath`.

### 3.4 Idempotent, complete `build_framework` (fixes 2.4)

New sequence, atomic per bundle:

1. `rm -rf` the target `.framework`; rebuild layout from scratch
   (`Versions/A/{Headers,Resources}`, binary, `Info.plist`, the four standard
   symlinks).
2. Copy headers with **`cp -RL`** (dereference symlinks — no more absolute
   symlinks inside bundles). Each phase passes a header source that contains
   *only its own* headers:
   - gettext: stage exactly `libintl.h` into `$BUILD_DIR/staging/libintl/` and
     pass that (not all of `build/include`).
   - libxml2, libotr: persist headers from the sandbox into
     `$BUILD_DIR/staging/<name>/` during the phase, pass the staged copy.
   - libgcrypt, libgpg-error: pass their staged headers too — the Adium target
     needs `gcrypt.h`/`gpg-error.h` via
     `libgcrypt.framework/Headers` (`Adium.xcconfig:3-4`), so the current empty
     `""` header args for those two phases are a bug.
3. Set `@rpath` id, apply the map-driven dep rewrite (3.2).
4. **`codesign -f -s - <binary>`** — mandatory last step after any
   `install_name_tool` edit.
5. `Info.plist`: set `CFBundleShortVersionString`/`CFBundleVersion` from the
   phase's package version (e.g. `1.12.2`), not the literal `A`; `plutil -lint`
   it.

### 3.5 Verification gate replaces the cosmetic summary

Replace the tail of `build-universal-deps.sh` (lines 94-109) with a check that
**fails the build** unless, for every framework in the map:

- `Versions/A/<binary>` exists as a regular file with archs `x86_64 arm64`;
- `otool -L` contains no `/Users/`, `sandbox-`, or `Dependencies/build` paths;
- `codesign --verify --strict` passes;
- top-level `<name>`, `Headers`, `Resources`, `Versions/Current` symlinks
  resolve.

When run under `--only=<phase>`, verify only that phase's frameworks.

### 3.6 Project-reference fixes

- `Frameworks/AIUtilities/xcconfigs/Adium.xcconfig:4`: `libgpgerror.framework`
  → `libgpg-error.framework`; same rename in
  `Frameworks/AIUtilities/AIUtilities.xcodeproj/project.pbxproj`.
  (Keep the hyphenated name: it matches the dylib and the framework already on
  disk.)
- Delete `Dependencies/copy_frameworks.sh` — dead upstream script referencing
  a `libgstreamer.framework` and `Dependencies/Frameworks/*.subproj` layout
  that no longer exist.

### 3.7 Minor cleanups (same PR, one-liners)

- `build_for_archs` symlink loop (`build-common.sh:106-115`) re-processes
  symlinks it just created (`-f` is true for symlinks-to-files), producing junk
  chains like `libglib-2.dylib → libglib-2.0.dylib`. Guard with `[ ! -L ]`.
- Add `-Wl,-headerpad_max_install_names` to `LDFLAGS` in `set_build_env` so
  install-name rewrites can never hit load-command space limits regardless of
  path length.

## 4. Implementation order

1. `build-common.sh`: map table; rewrite-in-`build_framework`; `rm -rf` +
   `cp -RL` + re-sign; delete `rewrite_dependency_links`; symlink-loop guard;
   headerpad flag.
2. Phases: header staging for gettext/libxml2/libotr; add header args to
   gcrypt/gpg-error; pass package version to `build_framework`.
3. `build-universal-deps.sh`: verification gate.
4. xcconfig/pbxproj `libgpgerror` rename; delete `copy_frameworks.sh`.
5. Full `--clean` run; verification gate green; build the Adium target.

## 5. Related findings out of scope for #55

- `FriBidi.framework` and `LMX.framework` (git-tracked, prebuilt) are
  `x86_64 + i386` — no arm64 slice; blocks a universal app link. Tracked
  separately (see follow-up issue).
- `Sparkle.framework` is x86_64-only — resolved by the Sparkle 2.x upgrade
  (#7).
- `Frameworks/Growl.framework` is a zero-byte placeholder file.
