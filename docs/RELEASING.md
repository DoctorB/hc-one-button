# GitHub → CurseForge releases

The `CurseForge release` workflow builds the addon and submits its ZIP and the
GitHub Release body to CurseForge project **1666468**. It does not change the
addon version, create tags/releases, push commits or update the project's main
description. The changelog belongs to the uploaded file, not the project page.

## Authorized publishers

Only the GitHub logins **DoctorB** and **DoctorCalibano** are allowed to start
this workflow, including manual validation. The job is skipped for other users
and bots before any runner or upload secret is provided. Both the original
initiator (`github.actor`) and the current initiator (`github.triggering_actor`,
which can differ on reruns) must belong to this exact two-account allowlist.

The Python script independently checks the same identities and the event sender
before preparing or uploading. Missing identities fail closed. GitHub login
capitalization is ignored, but prefixes/lookalikes are not accepted. The Release
draft's author is not used for authorization. Successful receipts record both
initiators; the no-upload-on-reruns rule still applies even to authorized users.

This does not grant GitHub permissions: DoctorCalibano must already have the
repository access needed to publish a release or run Actions.

**Security boundary:** a checked-in allowlist cannot stop someone who can change
the workflow or use the repository secret from another workflow. Keep repository
Write/Admin access and CurseForge upload rights restricted to these two people.
If additional writers are needed, use a protected GitHub environment with its
secret, release-ref restrictions and approval by DoctorB/DoctorCalibano, together
with protected workflow changes and no unauthorized bypass rights. Do not leave
a duplicate repository-level token available. This requires GitHub settings;
adding this file does not configure those protections. A server-side approval
gate adds a confirmation step before upload. Repository administrators must
remain trusted, because they can alter these protections.

## One-time setup

1. In `DoctorB/hc-one-button`, open **Settings → Secrets and variables → Actions**.
   Create a **repository secret** named `CF_API_TOKEN`, containing the author's
   CurseForge **upload API token**. No GitHub environment or extra GitHub PAT is
   needed. Never commit the token or paste it into an issue, changelog or chat.
2. Commit and push `.github/workflows/curseforge-release.yml`,
   `scripts/curseforge_release.py`, `tests/test_release_pipeline.py` and this guide.
   The workflow must also be present in the commit selected for a release tag.
3. Allow GitHub Actions to run in the repository. The workflow uses read-only
   repository permission, pinned checkout/artifact actions and no stored Git
   credentials. The CurseForge secret is available only to the upload step.
4. Open **Actions → CurseForge release → Run workflow** on `main`. This manual
   run performs the tests and creates a downloadable artifact without touching
   CurseForge or using its token. Check the ZIP and notes before the first release.

No upload API token is needed for the manual validation run. A missing/invalid
token will be discovered only at the first genuine upload. Local tests do not
prove the account has upload rights or that CurseForge is currently reachable.

## Publish a version

1. Complete the in-game checks, update the TOC/runtime/fallback version and
   root/package documentation together, then commit and push the intended code.
2. In GitHub **Releases → Draft a new release**, select that commit with a tag
   exactly matching `v` plus the TOC version, e.g. `v1.29.4` for version `1.29.4`.
   Use a new version/tag for new releases; do not move or recycle published tags.
3. Paste the user-facing Markdown release notes into the release body. This is
   the exact text uploaded to the CurseForge file's changelog. A blank body
   blocks the upload. The title is not used as a substitute for the changelog.
   The CurseForge display name is always `HCOneButton v<version>`, for example
   `HCOneButton v1.29.4`, regardless of the GitHub Release title or ZIP filename.
   No `ClassicEra`, date or `.zip` suffix is added to the display name.
4. Choose the release type:
   - ordinary GitHub release → CurseForge **Release**;
   - GitHub prerelease → CurseForge **Beta**;
   - a tag such as `v1.29.4-alpha.1`, marked as a GitHub prerelease → **Alpha**.
   Alpha/beta suffixes must also be present in the TOC/runtime version. A tag
   ending in `-beta.1` must be marked as a prerelease; inconsistent flags fail.
5. Click **Publish release**. This is the action that authorizes the upload.
   A normal commit push, tag push alone, draft save or release edit does not
   publish to CurseForge. Publishing either a stable release or prerelease does.
6. Open the workflow run. It checks metadata, runs the offline release tests and
   all Lua 5.1 harnesses, builds/verifies the ZIP, saves its artifact, then uploads.
   Check the final CurseForge file and its approval status before announcing it.

The workflow checks out the event's exact commit, not the latest moving `main`.
An old tag without this workflow does not acquire it retroactively. Already
published releases are not automatically backfilled when the workflow is added.

## CurseForge changelog format

Use curated, English, user-facing release notes in the approved format, not a
raw commit list or the complete historical `CHANGELOG.md`:

1. `# HCOneButton v<version>`.
2. A short benefit-led headline, a bold blockquote highlighting the release,
   and a brief introduction.
3. `New — …`, `Improved — …` and `Fixed — …` sections as applicable, with clear
   bullets and a concrete gameplay example. Do not invent changes to fill a section.
4. `Upgrade and safety`, including preservation/reset guidance and useful commands.
5. `Validation and limitations`, with verified checks and any pending in-game
   validation stated honestly; never copy another version's results as current.
6. `Compatibility Target`, followed by `Author` (`DoctorB`).

For 1.29.4, the version-controlled public notes are in
[`releases/1.29.4.md`](releases/1.29.4.md). Paste that document into
the GitHub Release body: the upload code sends the body unchanged as Markdown.
The manual-run artifact's changelog extract is only a technical preview, not
the curated public release text. Formatting these notes does not publish them.

## What is packaged

- `HCOneButton/` is the only root directory inside the ZIP.
- The TOC, all its referenced files, README, CHANGELOG and LICENSE are included.
  There are currently 52 files. Future assets must be explicitly supported in
  the packaging allowlist; the repository coverage test detects omissions.
- Tests, workflows, local artifacts, development docs and unreferenced local
  files never enter the package. Missing/duplicate/unsafe paths stop the build.
- Tag, TOC, runtime/fallback and documentation versions must agree. ZIP contents
  are verified by SHA256; metadata and changelog are rechecked immediately before
  upload. ZIP timestamps/order are deterministic for identical input bytes.
- The CurseForge game version is resolved from the TOC, e.g. `11509` → `1.15.9`,
  and must have exactly one matching **Classic Era** catalog entry. There is no
  silent fallback to Retail, another Classic flavor or a different patch.

The ZIP, standalone Markdown and verification manifest are retained as a GitHub
Actions artifact for 30 days. A successful API response produces a separate
receipt (project/file/release IDs and ZIP hash), retained for 90 days, and a run
summary. They are workflow artifacts, not automatically attached Release assets.

The ignored local `release/` directory is not fetched from the developer's PC.
GitHub builds its own `release/ci/` directory. Manual validation uses only the
current version's `CHANGELOG.md` section as preview notes; genuine publication
uses the GitHub Release body instead, preserving its Markdown and Unicode.

Manual-run summaries explicitly say **Validation only: no upload to CurseForge**.
The skipped upload/receipt steps are expected. Test mocks are isolated from the
runner's summary/output/environment files: a simulated file ID (such as `999`)
must never appear in the real summary. Package preparation reports only that
the package is ready; a real upload acceptance message requires a successful
API response and its receipt. Checkout/artifact actions are pinned Node 24
versions, not Node 20 actions relying on a forced runtime override.

### 1.29.4 in-game pre-publication check

Status: pending. Use the current checklist in
[`ADAPTIVE_REVIEW.md`](ADAPTIVE_REVIEW.md#1294-in-game-gate-before-publication).
Verify grouped/expandable tuning rows, saved settings, Warrior queued-strike
attribution, a caster's natural cast/interrupt path, status and `/hcob errors`.
Update the pending-validation statements in the public notes and root/package
documentation only after the actual in-game result is available.

After validation, commit/push the final documentation and code, optionally run
**Actions → CurseForge release → Run workflow** for a validation-only package,
then publish GitHub tag `v1.29.4` with the curated notes as the release body.
Use display title **HCOneButton v1.29.4**. No workflow or secret changes are
needed. Preparing local artifacts, committing, pushing or saving a draft does
not upload anything; only publishing the release triggers the authorized upload.

### Archived 1.29.3 aggro-meter smoke test

Status: the user tested the aggro meter in game and confirmed it works. This is
a reported smoke-test result, not a claim that every case below was exercised.
Keep this checklist for future regressions.

1. Verify the DPS / aggro row at HUD scales 0.7, 1.0 and 1.6 without overlap
   with DPS, Action Panel or Survival strip; drag, `/reload` and check position.
2. On ordinary safe fights, verify `AGGRO` while solo tanking and threat/status
   updates in a group. Do not deliberately provoke dangerous Hardcore pulls.
3. On Hunter/Warlock, let the pet engage a safe target first: `PET` may appear
   with `THREAT --` until the player has threat. Confirm available percentages
   refer to the player; verify `HIGH / PET` only if it occurs naturally.
4. Switch targets, clear target, end combat, target a friendly/player/corpse:
   no old percentage should remain. If the client lacks data, expect `--`.
5. Disable Combat logger: live threat must still work. Hide/show the combined
   meter and `/reload`: the choice persists. Check with Advisor hidden too.
6. Check `/hcob errors` and confirm normal secure actions/pixel behavior.
   After this passes, commit/push and publish `v1.29.3` with its release notes.

## Failures and reruns

Tests, invalid versions, empty notes, missing secrets or a missing exact game
version stop before the upload POST. The token is sent in an HTTPS header, never
in the URL or artifact. Redirects are refused and remote error bodies are not
printed, to prevent credential exposure.

An upload is **not automatically retried**: a timeout might occur after CurseForge
has accepted the file. Upload steps on GitHub workflow reruns are also blocked
(`GITHUB_RUN_ATTEMPT > 1`). Tests/builds can still be rerun. This is conservative
duplicate prevention, not a guarantee of API-level idempotency.

If a run fails:

1. Inspect **CurseForge → Files** and the run's receipt/artifacts first.
2. If the file exists, do not resubmit it; approval may still be pending.
3. If no file exists and only the upload failed, use the validated ZIP/Markdown
   artifact for a manual upload after resolving the credential/service problem.
4. If code or metadata is wrong, fix it and prepare a new version/release. Do not
   delete/recreate a release just to bypass the rerun guard: that is a new event
   and could duplicate an already accepted upload.

Editing an already published GitHub Release does not update CurseForge's copy.
Correct that file's changelog on CurseForge if needed. The workflow does not
bypass CurseForge moderation; a returned file ID confirms upload acceptance,
not necessarily immediate public availability.

## Local verification

```powershell
./tests/run.ps1
python -B -m unittest discover -s tests -p 'test_release_pipeline.py' -v
```

The Python tests use temporary fixture directories and mocked HTTP responses;
they never read the real token or contact either service. Python 3.9+ is needed.
GitHub uses Ubuntu 24.04's Python and Lua 5.1, plus PowerShell for the existing
Lua runner. The addon itself has no new runtime dependency.

## References

- [CurseForge upload API: token, Markdown and release metadata](https://support.curseforge.com/support/solutions/articles/9000197321)
- [Current WoW version endpoint and Classic catalog type, used by BigWigs Packager](https://github.com/BigWigsMods/packager/blob/master/release.sh)
- [GitHub release events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release)
- [Repository secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#creating-secrets-for-a-repository)
- [Original and rerun actor identities](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#github-context)
- [GitHub security boundaries for repository secrets and workflow changes](https://docs.github.com/en/actions/reference/security/secure-use)
