# Design: Renovate dependency updates

- **Issue:** [#1 — Renovate Support](../../../../issues/1)
- **Status:** Proposed
- **Scope:** `.github/renovate.json5` (new), `# renovate:` annotations in `Dependencies/build-phases/*.sh` and `Dependencies/get-sparkle.sh`

## 1. Problem

No automated dependency updates. The repo has two kinds of dependencies:

1. **GitHub Actions** — `.github/workflows/ci.yml`, actions pinned to SHA + version
   comment (repo convention).
2. **Vendored source tarballs** — `Dependencies/vendor/*.tar.*`, fetched by
   `Dependencies/vendor-fetch.sh` and consumed by `Dependencies/build-phases/*.sh`.
   Each build-phase script declares the version and SHA256 as shell variables, e.g.
   `Dependencies/build-phases/build-glib.sh:5-6`:

   ```sh
   BUILD_GLIB_VERSION="2.88.2"
   BUILD_GLIB_FILE="glib-${BUILD_GLIB_VERSION}.tar.xz"
   ```

   plus a `BUILD_GLIB_SHA256=` line. `Dependencies/get-sparkle.sh` pins the Sparkle
   framework version the same way.

Reference configs to model after (per the issue): `llmenv/.github/renovate.json5`
and `servarr-operator/.github/renovate.json5`. Their shared shape: `config:recommended`
+ `:configMigration` + semantic commits, `minimumReleaseAge`, `prCreation:
"not-pending"`, `prHourlyLimit: 0`, `branchConcurrentLimit: 5`,
`internalChecksFilter: "strict"`, `labels: ["dependencies"]`, automerge for
non-major, grouped non-major GitHub Actions, and `vulnerabilityAlerts` with a
`security` label.

## 2. Design

### 2.1 `.github/renovate.json5`

```json5
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  extends: [
    "config:recommended",
    ":configMigration",
    ":semanticCommits",
  ],
  dependencyDashboard: false,
  assigneesFromCodeOwners: true,
  baseBranchPatterns: ["main"],
  branchConcurrentLimit: 5,
  internalChecksFilter: "strict",
  labels: ["dependencies"],
  minimumReleaseAge: "7 days",   // repo convention: 7-day cooldown
  prCreation: "not-pending",
  prHourlyLimit: 0,
  rangeStrategy: "bump",
  rebaseWhen: "behind-base-branch",
  semanticCommitType: "chore",
  semanticCommitScope: "deps",

  packageRules: [
    // merge policy only — grouping owned by rules below
    { matchUpdateTypes: ["!major"], automerge: true },
    {
      groupName: "non-major GitHub Actions",
      groupSlug: "github-actions-non-major",
      matchManagers: ["github-actions"],
      matchUpdateTypes: ["minor", "patch", "pin", "digest"],
    },
    // vendored C deps: never automerge — a bump requires a successful
    // Dependencies/build-universal-deps.sh run and new tarball committed,
    // which Renovate cannot do. The PR is a notification + version/sha edit.
    {
      matchManagers: ["custom.regex"],
      automerge: false,
      groupName: null,
    },
  ],

  vulnerabilityAlerts: {
    labels: ["dependencies", "security"],
  },

  customManagers: [
    {
      customType: "regex",
      description: "Vendored dependency versions in build-phase scripts",
      managerFilePatterns: [
        "/^Dependencies/build-phases/.+\\.sh$/",
        "/^Dependencies/get-sparkle\\.sh$/",
      ],
      matchStrings: [
        "# renovate: datasource=(?<datasource>[a-z-.]+) depName=(?<depName>\\S+)( versioning=(?<versioning>\\S+))?( extractVersion=(?<extractVersion>\\S+))?\\n[A-Z_]*VERSION=\"(?<currentValue>[^\"]+)\"",
      ],
    },
  ],
}
```

Notes for the implementer:

- Renovate ships GitHub-side (app) — no workflow file needed. If the repo instead
  wants self-hosted Renovate, that's a separate decision; this doc assumes the app.
- Actions in `ci.yml` are SHA-pinned with version comments; `config:recommended`
  handles digest pinning updates natively (`github-actions` manager reads the
  `# vX.Y.Z` comment).

### 2.2 Annotate the build-phase scripts

Above each `BUILD_*_VERSION=` line add a `# renovate:` comment naming a datasource.
Mapping:

| Script | depName / datasource |
|---|---|
| build-glib.sh | `datasource=gitlab-tags registryUrl=https://gitlab.gnome.org depName=GNOME/glib` (strip non-numeric via `extractVersion` if tag format needs it) |
| build-libxml2.sh | `datasource=gitlab-tags registryUrl=https://gitlab.gnome.org depName=GNOME/libxml2` |
| build-pcre2.sh | `datasource=github-releases depName=PCRE2Project/pcre2` `extractVersion=^pcre2-(?<version>.*)$` |
| build-libffi.sh | `datasource=github-releases depName=libffi/libffi` `extractVersion=^v(?<version>.*)$` |
| build-fribidi.sh | `datasource=github-releases depName=fribidi/fribidi` `extractVersion=^v(?<version>.*)$` |
| build-gcrypt.sh | `datasource=custom.gnupg` or `github-tags depName=gpg/libgcrypt` `extractVersion=^libgcrypt-(?<version>.*)$` |
| build-gpg-error.sh | `github-tags depName=gpg/libgpg-error` `extractVersion=^libgpg-error-(?<version>.*)$` |
| build-gettext.sh | GNU ftp has no clean datasource; use `custom.html` datasource against https://ftp.gnu.org/gnu/gettext/ or leave unannotated with a comment saying so |
| build-libotr.sh | upstream (otr.im) is effectively frozen at 4.1.1; leave unannotated with a comment |
| build-libpurple.sh (pidgin) | `datasource=github-releases depName=pidgin/pidgin` if mirrored, else sourceforge RSS via `custom.html`; pidgin 2.x is near-frozen — acceptable to leave unannotated |
| build-lmx.sh | Adium-local fork, version `1.0` is ours; leave unannotated |
| get-sparkle.sh | `datasource=github-releases depName=sparkle-project/Sparkle` |

Example annotation (build-libffi.sh):

```sh
# renovate: datasource=github-releases depName=libffi/libffi extractVersion=^v(?<version>.*)$
BUILD_LIBFFI_VERSION="3.6.0"
```

Where a datasource is listed as "leave unannotated", add a plain comment
(`# no renovate: upstream frozen / no queryable datasource`) so the omission reads
as deliberate.

**Important limitation to state in the PR:** Renovate can only edit the version
string. It cannot update `BUILD_*_SHA256` or fetch the new tarball into
`Dependencies/vendor/`. A human (or follow-up automation, out of scope) must run
`Dependencies/vendor-fetch.sh <new-url> <new-sha>` and update the SHA line before
the PR can merge. That is why the custom-manager rule disables automerge. CI will
fail on a version/sha/tarball mismatch, which is the desired guard.

## 3. Verification

1. `npx --yes renovate-config-validator .github/renovate.json5` passes.
2. Open the Renovate dashboard/log after install: the `github-actions` manager
   detects `ci.yml`; the regex manager lists each annotated `BUILD_*_VERSION`.
3. Force one known-stale dep (any annotated one behind upstream) and confirm a PR
   appears editing only the version string, labeled `dependencies`, non-automerge.

## 4. Out of scope

- Automation that re-downloads tarballs and recomputes SHA256 on Renovate PRs
  (`postUpgradeTasks` needs self-hosted Renovate). File a follow-up issue if wanted.
- Sparkle *framework binary* update mechanics beyond bumping the version in
  `get-sparkle.sh`.
