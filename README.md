# Bucephalus

A notetaker for conversations that happen in person. Press record, put your iPhone on the table, lock it, and talk. When you stop, Bucephalus transcribes the recording on the phone and turns it into a clean summary.

Meeting notetakers like Granola cover calls on Zoom and Google Meet. Bucephalus covers the ones that happen in a room.

> Early v0. Built for personal use, not on the App Store.

## How it works

1. **Record.** Audio is written to disk continuously and keeps recording with the screen locked.
2. **Transcribe.** When you stop, Apple's on-device speech model (SpeechAnalyzer) transcribes the file. Audio never leaves the phone.
3. **Summarise.** The transcript text is sent to the model you choose, which returns an overview, key points, decisions and action items.

## Features

- Background recording that survives a locked screen and resumes after a phone call
- On-device transcription, offline after the first model download
- Summaries from OpenAI or Anthropic, using your own API key
- Model picker that lists the models available to your key
- Optional auto-generated meeting titles (5 words or fewer)
- Summary and full transcript for every meeting, with share
- A notes tab per meeting, with Markdown formatting as you type
- Long press a meeting to rename or delete it
- Retry for any failed step; the audio is always kept
- Everything stored locally: no account, no server, no cloud sync

## Requirements

- iPhone on iOS 26 or later
- Mac with Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- An OpenAI or Anthropic API key
- An Apple ID (a free personal team is enough)

## Setup

```sh
git clone https://github.com/Gagancreates/bucephalus.git
cd bucephalus
brew install xcodegen
xcodegen generate
open Bucephalus.xcodeproj
```

Then in Xcode:

1. Select the **Bucephalus** target → **Signing & Capabilities** → choose your team.
2. If the bundle identifier is taken, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and run `xcodegen generate` again.
3. Plug in your iPhone, select it as the run destination, and press **Run**.
4. On the phone, enable **Developer Mode** (Settings → Privacy & Security) and trust your developer profile (Settings → General → VPN & Device Management).

In the app, open **Settings**, pick a provider, paste your API key, and choose a model.

With a free Apple ID the app stops launching after 7 days. Run it from Xcode again to renew; your meetings are kept.

The simulator can run the interface and record, but on-device transcription needs a real iPhone.

## Privacy

- Audio and transcripts are stored only in the app's storage on your iPhone.
- The only data sent anywhere is the transcript text, to the provider you selected, to produce the summary.
- API keys are stored in the iOS Keychain.
- Deleting the app deletes all meetings.

Tell people before you record them. Recording laws vary by country and state.

## Project layout

```
project.yml                  XcodeGen project definition
Bucephalus/
  BucephalusApp.swift        App entry point
  Models/Meeting.swift       SwiftData model and summary type
  Services/
    AudioRecorder.swift      Background recording and level metering
    Transcriber.swift        On-device transcription (SpeechAnalyzer)
    Summarizer.swift         OpenAI and Anthropic clients, summary prompt
    MeetingProcessor.swift   Transcribe → summarise pipeline
    Keychain.swift           API key storage
  Views/                     Home, recording, meeting detail, notes, settings
  DemoData.swift             Sample meeting, added when launched with -demo
```

## Roadmap

- Speaker labels (who said what)
- Search across meetings
