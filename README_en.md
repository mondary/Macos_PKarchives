# PKarchives

![PKarchives — A consistently clean Desktop](store/media/banner-1544x500.png)

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

**Project version: 2026.10.53** · Available app: 2026.10.27 · [Changelog](CHANGELOG.md) · [MIT License](LICENSE)

Archive your Desktop to Google Drive via rclone, with a macOS app and a CLI/TUI.

![Animated PKarchives demonstration](store/media/03-interface-dynamic.gif)

## Structure

```text
src/
├── macos/       # SwiftUI/menu bar app
├── cli/         # Go/TUI application
└── shared/      # Shared archive script

release/
├── macos/       # PKarchives-<YYYY.MM.PATCH>.app
└── cli/         # pkarchives binary
```

## ✅ Features

- Native macOS menu bar (SwiftUI)
- Go CLI/TUI interface
- Upload to Google Drive via rclone
- Automatic monthly archiving (`YYYY_MM_month`)
- Auto-delete after upload
- Files and folders support
- Real-time progress bar
- Native settings with search, language selection, PK project library, support, and version information
- About compares the installed app with the latest Stable and Dev builds, showing per-channel status and manually checking a freshly fetched feed
- Dedicated Credits & Inspirations settings section linking to tools, dependencies, and reference projects
- macOS Folders mode (Dev, unpublished): ⇄/↑/↓ sync, dry-run previews, content verification and replayable history

![Main view: Desktop archived to Google Drive](store/media/01-promo-vue-principale.png)

## 🧠 Usage

### First-time setup (automated)

```bash
./scripts/setup.sh
```

The interactive script guides you through:
1. Entering your Google Drive Folder ID
2. Configuring the folder to archive (default: `~/Desktop`)
3. Setting the rclone remote name (default: `gdrive`)
4. Verifying rclone is installed and configured
5. Building and launching the app

### The app

After installing from the DMG or `.pkg` (see below), the app lives in the menu bar.
To build it yourself: `./scripts/build.sh`.

![Yearly archiving history](store/media/02-promo-historique-annuel.png)

### Synced folders — local Dev build

The new mode is available in the sources and Dev build, **not yet in the Stable downloads below**. Desktop archiving remains a separate mode; the CLI/TUI does not offer folder sync yet.

1. The app starts on **Archives**, the first tab (**⌘1**), for monthly Desktop cleanup. **Archives / Synchronization / Settings** are grouped on the right, separate from the PKarchives title, with matching styling for all three buttons. Choose **Synchronization**, marked “In the background” (**⌘2**), then **Create a pair**. Sync jobs continue independently of the displayed tab. **Linked folders** lists the Mac folders connected to Drive; **View history** opens reports without a segmented tab control.
2. The screen starts with a **single status block**: state title, **Refresh all** (compare every pair, no transfer) and **Sync all** buttons, a condensed live-run section (one metrics line, one done line, a bar), **last verified check and next automatic check on one line**, then the cadence as a fine footnote — long explanations move to a tooltip on the title. Runs in the background via the 📦 icon as long as PKarchives is active: Mac changes checked 45 s after modification, Drive about hourly and on wake; with launch at login (**Settings → General**), sync can replace the Google Drive app. Below, **pairs sort by state**: the running pair first, then the queue, then pairs needing action, then pairs at rest. The **From / To** panels retain upload, download and deletion counts with file details on click; **Refresh files** compares without transferring, **Sync now** starts a real run (the initial merge requires explicit confirmation). After a verified check, counts show zero as of that check; otherwise “—” means unknown, and an obsolete preview is never revived as pending transfers. Runs report files sent, received and deleted separately. Inventory and pair management live under **Settings → Synchronization**.
   **Desktop and archiving**: the Desktop and its subfolders can be linked to a pair — a synchronized workspace — while monthly archiving keeps clearing the Desktop into its `YYYY_MM_month` folders. Archiving and syncing never run at the same time (shared lock, including `archive.sh` started from a terminal). After an archive, the pair switches to “reconcile working copy”: **Refresh files** lists the deliberate deletions, then a single confirmation propagates that cleanup to the Drive copy — removed files go to the recovery folder, and a fully emptied Desktop is reconciled by mirroring. Monthly archives stay in a separate destination, necessarily different from the working Drive folder, and are never modified by sync.
2. In the **Create a pair** form, choose a dedicated Mac folder and name the pair. Under **Google Drive destination**, keep the usual rclone connection (`gdrive`), click **Open Google Drive**, open the destination folder, copy its **full address from the browser bar**, and paste it into **Folder link**. Example: `https://drive.google.com/drive/folders/FOLDER_IDENTIFIER`. The app extracts the ID: do not paste the folder name, `gdrive:gdrive` or a file link. The browser must use the same Google account as the rclone connection; pasting a link does not grant additional access. Saving creates the pair without starting a transfer.
   **rclone path (advanced)** still accepts a relative path such as `Sync/Documents`, without the `gdrive:` prefix. It starts at the remote root, **not** the `PKARCHIVES_DRIVE_FOLDER_ID` archive folder. Selecting a folder link does not change rclone configuration.
3. Choose **two-way**, **Mac to Drive** or **Drive to Mac**, exclusions and a conflict policy.
4. **Preview only** is enabled by default for every new pair: automatic and global runs remain previews. **Refresh files** performs this comparison on demand, with **Preview all** in the global menu when multiple pairs exist. Neither side’s files nor the live bisync listings are changed. Only local reports and isolated preview listings are written. A preview never declares a backup verified or enables real transfers.
5. Inspect the counters and their detail drawers, then choose **Sync now** for this pair (or disable “Preview only” in its settings). The first two-way merge always requires explicit confirmation. **View history** retains reports and retries.

![Linked folders and history access in the Dev build with temporary sample data](store/media/04-sync-dev.png)

![Sync panels side by side at the minimum window width with sample data](store/media/08-sync-narrow-dev.png)

![File details opened directly from the send counter with sample data](store/media/09-sync-detail-dev.png)

![Drive folder selection by pasting its full link, with instructions and an Open Drive button](store/media/05-drive-folder-dev.png)

**Run feedback**: during a sync, a banner shows the current direction, files done / planned, volume and percentage, speed, elapsed time and rclone’s estimated remaining time, plus planned and completed operations per direction (↑ push, ↓ pull, deletions). During a preview nothing is transferred, but the comparison and its volumes stay visible.

**Menu bar**: left-click, right-click or a 550 ms hover opens the native panel, directly on Synchronization when pairs are configured. Expand each row for Mac ↔ Drive locations, actual state, preview, sync and the latest report. Active runs show progress, speed, remaining files, ETA and a stop action. **Sync all** respects each pair’s preview mode. Hover never starts a transfer; disable automatic opening under **…** or **Settings → General**.

**Settings → General**: launch at login (in the background, with macOS approval if needed) and menu bar display: **Transfer speed**, **Remaining files** or **Icon only**. Numbers come from the current run’s rclone stats, updated roughly every 5 s; queued pairs are excluded and totals may change during scanning. Scanning, preview and verification have distinct states; only the icon remains when idle. Archiving shows the remaining item count.

**Sync pairs**: the **From / To** panels stay side by side and the same size even at the minimum window width. Their paths occupy matching rows and their open buttons align along the bottom; the upper content rearranges to remain readable. After a preview, click any upload, download or deletion count to open a side drawer with the affected file paths, direction and reason (new, replaced or propagated deletion). Inventory stays separate; there is no second “Show details” click. During a real transfer, the connection and native progress indicator animate with the actual run state; Finder, Drive and Drive mounting remain available outside test mode.

**Settings → Synchronization**: global pause of all pairs (1 h), default “Preview only” mode for new pairs, and the pair list with enable/preview switches and the full form. These settings drive the sync engine; archiving configuration stays in its own section.

The full installed version (including its Dev suffix) is visible and selectable under **PKarchives** in the icon’s panel, whichever tab is selected.

![Icon panel showing the installed version in the local Dev build](store/media/06-menu-version-dev.png)

![General settings: launch at login and menu bar activity metric](store/media/08-general-dev.png)

![Panel progress during a real rclone transfer between temporary test folders](store/media/09-menu-transfer-dev.png)

**Verification and recovery**

- Successful transfers are followed by `rclone check`: size and hashes of included contents. A failed check, unavailable hashes or local changes during verification prevent a **Verified** status. The displayed date is the last successful check, not a permanent guarantee about Drive.
- One-way mode replaces differing destination files from the source, without deleting additional destination files. Two-way mode propagates changes **and deletions**. Sync is not an immutable backup.
- Replaced/deleted versions are retained in `.PKarchives-recovery/<pair>/<run>/` on Drive and `~/Library/Application Support/PKarchives/recovery/` on the Mac. For folder-link destinations, this reserved directory lives inside the selected Drive folder and is always excluded from transfers/checks; for traditional rclone paths, it lives at the remote root. No automatic purge: monitor disk/quota usage.
- Each failure leaves a report and can be retried from **Activity**. Other pairs continue. Transient errors retry at 2, 5, 15, 30, then 60 min; initial merges, repairs requiring `resync`, manual stops and access/authorization/folder/safety issues await a user decision or correction. A retry reconciles the current configuration, not an obsolete command.
- A Google **API request quota** error (403/429) shows its actual cause, distinct from full Drive storage: the affected connection waits 15 min before retrying, including previews. There is no automatic merge to bypass this error, nor a switch from preview to real transfer. Persistent blocks may require separately reviewing the OAuth project configuration; the app does not change credentials or Google quotas.
- Terminal color codes are hidden. Technical details and general explanations stay collapsed. Historical raw reports are preserved; **View report** generates a clean reading copy (`rapport-lecture.md`) with the corrected diagnosis.
- Abrupt termination leaves a state requiring a new check. If the previous process is still running, the engine blocks rather than launching concurrent transfers. Unreadable configuration or inaccessible logs also block the engine.
- Folders overlapping the Drive mount, app data or another pair are rejected; the Desktop is allowed with dedicated coordination. A Drive folder identical to the monthly archive root is rejected. Excluded files are not backed up.
- Local paths and directly comparable destinations are checked for overlap. Different Drive IDs do not reveal their parent/child relationship without a remote query: choose distinct, non-nested Drive folders across pairs.
- Symbolic links are not followed: a link skipped by rclone prevents a Verified status. Two-way deletions exceeding 50% of the listing are blocked by the bisync safety guard, without automatic force.
- Bisync may also stop when all files on one side have changed (including a folder with just one modified file). The error stays visible; there is no automatic `--force` bypass. This behavior still needs improvement before Stable.

**Resource usage and limits**: one rclone at a time, 2 transfers/2 checkers, small buffers, no required rclone/RC/FUSE daemon. FSEvents batches local changes over 45 s; remote checks are hourly and after wake. The app must stay open. Pause delays new runs without stopping the current transfer. Listings still scale with file count and verification reads local files to compute hashes: this is neither instantaneous remote sync nor a hard RAM limit. Current validation uses rclone **1.74.4**, isolated local remotes and a small real Google Drive pair (preview, initial merge, two-way reconciliation and a zero-difference check). Large folders, expired OAuth and network interruptions still need testing before a Stable release.

Normal launch opens Archiving. The `--background` argument starts the app without a window or archive UI for menu-bar-only use.

**Inspectable files**:

- Configuration: `~/Library/Application Support/PKarchives/sync.json`.
- Per-connection API cooldowns: `~/Library/Application Support/PKarchives/cooldowns.json` (no OAuth tokens).
- Per-pair counts (Status inventory): `~/Library/Application Support/PKarchives/inventories.json`.
- Readable journal: `~/Library/Logs/PKarchives/sync.log` (512 KiB rotation).
- Reports: `~/Library/Logs/PKarchives/runs/<id>/rapport.md`, `operations.log` (readable operations/errors), `run.json`, `rclone.jsonl`, `verification.txt`. The UI retains the latest 80 runs; detailed reports remain on disk. These contain filenames and paths: review them before sharing.

## Installation — Apple Silicon Mac

- **DMG**: [Download PKarchives for Mac](https://github.com/mondary/Macos_PKarchives/releases/latest/download/PKarchives.dmg), then open the DMG and drag the app to Applications.
- **Direct installer**: [Download the .pkg installer](https://github.com/mondary/Macos_PKarchives/releases/latest/download/PKarchives.pkg), then double-click the file.
- **Homebrew**: `brew install --cask mondary/tap/pkarchives`
- **curl**: `curl -fL https://github.com/mondary/Macos_PKarchives/releases/latest/download/PKarchives.pkg -o "$HOME/Downloads/PKarchives.pkg"`

The published build targets Apple Silicon (arm64). The app and installer are not notarized; macOS may ask you to approve the installation and first launch.

### CLI/TUI, from anywhere in Terminal

Run this once, then use `pkarchives` from any folder:

```bash
curl -fsSL https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/scripts/install-cli.sh | sh
pkarchives
```

## ⚙️ Configuration

Configuration is automatically generated by `scripts/setup.sh` in `secrets/.env`.

### Available variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PKARCHIVES_DRIVE_FOLDER_ID` | *(required)* | Google Drive folder ID |
| `PKARCHIVES_DESKTOP_PATH` | `~/Desktop` | Folder to archive |
| `PKARCHIVES_DESKTOP_LINK_NAME` | `DesktopArchive` | Mounted volume name |
| `PKARCHIVES_RCLONE_REMOTE` | `gdrive` | rclone remote name |
| `PKARCHIVES_AUTO_MOUNT` | `0` | Optional mount at launch and after archiving (`1` to enable) |

Manual mounting remains available in the archive interface: `~/DesktopArchive` (Finder volume “DesktopArchive”, outside the Desktop). It is disabled by default and never required for sync. Mounts already started by an older build are not automatically unmounted.

## 🧾 Requirements

- macOS 14.0+
- rclone (`brew install rclone`)
- rclone remote configured

## 📦 Build

```bash
./scripts/build.sh
```

Dev build: `PK_DEV_BUILD=1 ./scripts/build.sh`. With CLT 27 missing SwiftUIMacros, the script uses SDK 26.5 if already installed; `PK_MACOS_SDK` explicitly selects a compatible SDK.

Isolated local tests, without accessing your Drive account or user configuration:

```bash
bash scripts/test-sync.sh
```

Tests run real rclone against a remote alias backed by temporary folders, alongside injected failure cases. Coverage includes previews, push/pull/bisync, verification, conflicts, recovery, replay, cancellation, pause, locks and FSEvents.

## License

PKarchives is distributed under the [MIT License](LICENSE), which permits commercial use and redistribution provided the copyright and license notice are retained.

## 📋 See [CHANGELOG](CHANGELOG.md) for full history

## 🔗 Links

- [Landing page](store/website/index.html) · [product film](store/media/ultracrea2-promo.mp4) · [previous versions](store/archive)
- [Google Drive](https://drive.google.com)
- [rclone](https://rclone.org/)
- ❤️ Support this project on [Ko-fi](https://ko-fi.com/pouark)
