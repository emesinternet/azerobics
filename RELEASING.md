# Release guide

Use this guide when preparing or publishing an Azerobics release.

## How publication works

This project has an automatic connection from GitHub to CurseForge.
The following behavior was observed on November 9, 2026:

| GitHub action | CurseForge result |
| --- | --- |
| Push commit `b98847e` to `main` | Build `b98847e-alpha`, type Alpha, approved |
| Create tag `v1.2.0` for that commit | Build `v1.2.0`, type Release, approved |

The signed-in CurseForge author file list showed both builds. No manual
CurseForge upload or author API token was used for this release.
There is no GitHub Actions workflow in this checkout. The external connection
settings were not inspected during this release.

Use the automatic connection for normal releases. A GitHub source push can
produce an alpha build; the version tag produces the release build.
Check existing and pending files before any manual upload, so the same version
is not uploaded twice. An API token is needed only if using the
[CurseForge upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api).
A signed-in upload through the author website does not need that token.

## Prepare a release

1. Review the changes and choose the next unused version.
   Set `## Version` in `Azerobics/Azerobics.toc` to that version.
   Keep the current game interface number unless a client change requires it.
2. Update the player guide and write the release notes.
3. Run the checks needed for the changed behavior. For a bug fix, reproduce
   the fault before the change, then confirm that the check passes after it.
   On this machine, `python work/check-premium-ui.py` runs the Lua checks.
   The `work` folder is local and is not tracked by Git. If that check is not
   available, use an equivalent check and report what was tested.
   Lua mocks do not confirm game rendering or native mouse input.
4. Build a fresh ZIP from the current `Azerobics` folder. It must contain one
   top-level `Azerobics/` folder with the TOC, Lua, art, sounds, guide, and license.
   Check the archive contents and TOC version before uploading it.

Example PowerShell commands, run from the project root. Replace `1.2.1` with
the version being released:

```powershell
$releaseVersion = "1.2.1"
New-Item -ItemType Directory -Path outputs -Force | Out-Null
Compress-Archive -LiteralPath .\Azerobics -DestinationPath ".\outputs\Azerobics-$releaseVersion.zip"
```

Use a new archive path. The old `work/package-release.py` script is stale:
it expects 28 files, version 1.0.0, and the former `_classic_beta_` install.
It must be updated before reuse.

## Push and publish

1. Confirm that `git branch --show-current` prints `main` in this checkout.
   Review `git status --short` and `git diff`. Stage only the release changes.
   Check the staged changes before committing.
2. Commit and push to `origin/main`. Continue only after the push succeeds.
   This can start a CurseForge alpha build.
3. Create the matching version tag and GitHub release once. Attach the checked
   ZIP and the release notes. The command below creates the tag if needed;
   a separate tag push is not needed for this method.

```powershell
git diff --cached --check
git commit -m "Release Azerobics $releaseVersion"
git push origin main
$releaseCommit = git rev-parse origin/main
gh release create "v$releaseVersion" "outputs/Azerobics-$releaseVersion.zip" --repo emesinternet/azerobics --target $releaseCommit --title "Azerobics $releaseVersion" --notes-file "work/release-notes-$releaseVersion.md"
```

Create the notes file before running the command. Use GitHub CLI authentication
for GitHub publication. Do not create a second release tag to retry a slow build.

## Confirm completion

- GitHub: `main` and the version tag point to the intended commit. The release
  is published, and its ZIP asset is fully uploaded.
- CurseForge: open the project's Files page in the signed-in author dashboard.
  Confirm the version, type **Release (R)**, status **Approved**, and supported
  game version. For 1.2.0, the game version was Forever **1.60.1**.
  A cached public page can show the previous release after the author dashboard
  shows approval. Check the current author file list before reporting a failure.
- If a build is pending or missing, check its status and the external GitHub
  connection first. Use a manual upload only after confirming that it will not
  duplicate an existing or pending file.

The `.pkgmeta` file controls CurseForge packaging. Keep development notes,
local work files, output archives, and screenshots out of the addon package.

## Project links

- [GitHub repository](https://github.com/emesinternet/azerobics)
- [GitHub 1.2.0 release](https://github.com/emesinternet/azerobics/releases/tag/v1.2.0)
- [CurseForge project](https://www.curseforge.com/wow/addons/azerobics), project ID `1737495`
- [CurseForge author dashboard](https://authors.curseforge.com/)
