# ShadowCast

A macOS app for language shadowing practice. Watch OBS meeting recordings with a synchronized word-highlighted transcript — every spoken word highlighted as it plays, click any word to seek, copy text for drilling.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![Local only](https://img.shields.io/badge/transcription-local%20only-green)

---

## Features

- **Local Whisper transcription** — no internet, no API key, no cost
- **Word-level highlight** synced to video playback in real time
- **Click any word** to seek the video to that exact moment
- **MKV support** — auto-converts OBS recordings (requires ffmpeg)
- **Playback speed** — 0.5× to 1.5×
- **Transcript persisted** as `.transcript.json` next to each video — never re-transcribes
- **Keyboard shortcuts** — Space (play/pause), ← → (seek ±5s)
- **Right-click** transcript → Copy All Text

---

## Requirements

| Requirement | How to install |
|-------------|---------------|
| macOS 14+ | — |
| Swift Command Line Tools | `xcode-select --install` |
| Homebrew | `brew install ffmpeg` |
| ffmpeg | Required for MKV/OBS recordings |

---

## Install from source

```bash
# 1. Clone the repo
git clone https://github.com/PepoBJ/ShadowCast
cd shadowcast/ShadowCast

# 2. Install to /Applications (requires password)
sudo make install

# OR install to your user Applications (no password needed)
make bundle
cp -r .build/ShadowCast.app ~/Applications/
```

Then open **Spotlight** (`Cmd+Space`) and search for **ShadowCast**.

> **First launch**: macOS may show "unidentified developer". Right-click the app → **Open** → **Open anyway**.

---

## Makefile commands

```bash
make install    # build release binary + .app bundle + install to /Applications
make bundle     # build .app bundle only (in .build/ShadowCast.app)
make release    # create ShadowCast.zip for sharing / GitHub Releases
make uninstall  # remove from /Applications
make clean      # remove all build artifacts
```

---

## First-time setup

1. **Launch ShadowCast**
2. Click the **folder icon** (top toolbar) → select the folder containing your video files
3. The app remembers this folder across relaunches

---

## Transcribing a video

1. Click a video in the sidebar
2. Click the **Transcribe** button on the right
3. First run: downloads the selected Whisper model (see sizes below)
4. Progress shows in the transcript pane: *Converting → Downloading model → Extracting audio → Transcribing*
5. When done, the transcript appears automatically — no restart needed

The transcript is saved as `<videoname>.transcript.json` **next to your video file**. Future launches load it instantly.

### MKV files (OBS default format)

OBS records in `.mkv` by default. AVFoundation (Apple's media framework) cannot play MKV natively. ShadowCast auto-converts MKV to MP4 using ffmpeg when you click **Transcribe** or **Convert & Play**. The converted file is stored in `~/Library/Caches/ShadowCast/remuxed/` — your original MKV is never modified.

---

## Whisper model sizes

Select in the **bottom-left picker** before transcribing:

| Model | Download size | Speed (M2) | Quality |
|-------|-------------|-----------|---------|
| Base | ~75 MB | ~10× realtime | Good for clear speech |
| Small | ~500 MB | ~5× realtime | Better accuracy |
| Medium | ~1.5 GB | ~2× realtime | Best accuracy |

**Recommendation:** Start with **Base** for testing. Use **Small** or **Medium** for important recordings.

Models are downloaded once to `~/Library/Application Support/ShadowCast/models/` and reused.

---

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `←` | Seek back 5 seconds |
| `→` | Seek forward 5 seconds |
| Click word | Seek to that word |
| Right-click transcript | Copy All Text |

---

## Where files are stored

| File | Location |
|------|----------|
| Transcript JSON | Next to each video: `<videoname>.transcript.json` |
| Whisper models | `~/Library/Application Support/ShadowCast/models/` |
| Remuxed MKV cache | `~/Library/Caches/ShadowCast/remuxed/` |
| Last watched folder | `UserDefaults` (restored on launch) |

---

## Troubleshooting

**"MKV conversion stuck"**
Run `brew install ffmpeg` and restart the app. ffmpeg must be at `/opt/homebrew/bin/ffmpeg`.

**"No transcript after transcribing"**
Check that the `.transcript.json` file exists next to your video. If it's in a cloud folder (Google Drive, iCloud), the transcript is saved locally next to the original — make sure the folder is accessible.

**"App not detected by window manager (Amethyst etc.)"**
Install via `make install` as a proper `.app` bundle, not `swift run`. The bundled app registers correctly with macOS.

**Transcription crashed**
If using the **Medium** model, ensure you have enough free RAM (~2GB). Try **Small** or **Base** instead.

---

## Tech stack

- **Swift 6.3** / **SwiftUI** — strict concurrency, `@Observable`
- **AVFoundation** — video playback, audio extraction (16kHz PCM)
- **whisper.cpp v1.8.4** — local transcription via XCFramework binary SPM target
- **GCD DispatchSource** — folder watching (FSEvents)
- **ffmpeg** (external) — MKV → MP4 remux via `posix_spawn`
- **No internet required** after initial model download

---

## License

MIT
