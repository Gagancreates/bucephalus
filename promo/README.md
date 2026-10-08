# Launch video

A [Remotion](https://www.remotion.dev) project for the Bucephalus launch video (1080×1350, ~43 s).

```sh
npm install
python3 music/compose.py          # writes public/music.wav (original, synthesised)
npm run render                    # writes out/bucephalus-launch.mp4
```

The app clips in `public/clips/` are screen recordings of the real app in the iOS Simulator, driven by
demo launch arguments (`-demo -tourMeeting`, `-cycleDrawer`, `-tourRecord -fakeLevels`, `-record`), recorded with
`xcrun simctl io booted recordVideo`. They aren't committed; re-record them to render.
