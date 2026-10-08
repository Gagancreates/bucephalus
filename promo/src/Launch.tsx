import { loadFont } from "@remotion/google-fonts/Inter";
import { loadFont as loadSerif } from "@remotion/google-fonts/InstrumentSerif";
import {
  AbsoluteFill,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";

const { fontFamily: sans } = loadFont();
const { fontFamily: serif } = loadSerif();

const BG = "#F4F0EC";
const INK = "#1B1714";
const MUTED = "#7A706A";
const MAROON = "#731628";

// Scene lengths in frames (30 fps).
const SCENES = [
  { id: "hook", length: 105 },
  { id: "intro", length: 90 },
  { id: "record", length: 105 },
  { id: "lock", length: 105 },
  { id: "speakers", length: 105 },
  { id: "summary", length: 95 },
  { id: "classroom", length: 140 },
  { id: "end", length: 105 },
] as const;

export const LAUNCH_FRAMES = SCENES.reduce((sum, s) => sum + s.length, 0);

const start = (id: (typeof SCENES)[number]["id"]) => {
  let at = 0;
  for (const s of SCENES) {
    if (s.id === id) return at;
    at += s.length;
  }
  return at;
};
const length = (id: (typeof SCENES)[number]["id"]) => SCENES.find((s) => s.id === id)!.length;

/** Fades and lifts content in, and fades it out at the end of its scene. */
const useEnter = (delay = 0, sceneLength?: number) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame: frame - delay, fps, config: { damping: 200 } });
  const exit = sceneLength
    ? interpolate(frame, [sceneLength - 12, sceneLength], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })
    : 1;
  return {
    opacity: enter * exit,
    transform: `translateY(${interpolate(enter, [0, 1], [28, 0])}px)`,
  };
};

const Headline = ({ children, delay = 0, sceneLength, size = 76 }: { children: React.ReactNode; delay?: number; sceneLength: number; size?: number }) => (
  <div style={{ ...useEnter(delay, sceneLength), fontFamily: serif, fontSize: size, lineHeight: 1.08, color: INK, textAlign: "center", letterSpacing: -0.5 }}>
    {children}
  </div>
);

const Caption = ({ children, delay = 0, sceneLength }: { children: React.ReactNode; delay?: number; sceneLength: number }) => (
  <div style={{ ...useEnter(delay, sceneLength), fontFamily: sans, fontSize: 34, lineHeight: 1.35, color: MUTED, textAlign: "center", fontWeight: 500 }}>
    {children}
  </div>
);

/** A phone with a screenshot, rising in with a gentle spring and a slow drift. */
const Phone = ({ src, delay = 0, sceneLength, height = 900 }: { src: string; delay?: number; sceneLength: number; height?: number }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame: frame - delay, fps, config: { damping: 18, stiffness: 90 } });
  const exit = interpolate(frame, [sceneLength - 12, sceneLength], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const drift = interpolate(frame, [0, sceneLength], [0, -18]);
  const width = height * 0.46;
  return (
    <div
      style={{
        width,
        height,
        borderRadius: height * 0.075,
        overflow: "hidden",
        opacity: Math.min(1, enter * 1.4) * exit,
        transform: `translateY(${interpolate(enter, [0, 1], [160, 0]) + drift}px) scale(${interpolate(enter, [0, 1], [0.94, 1])})`,
        boxShadow: "0 40px 90px rgba(60, 30, 25, 0.22), 0 0 0 10px #1B1714",
      }}
    >
      <Img src={staticFile(src)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
    </div>
  );
};

const Feature = ({ sceneLength, title, caption, phone }: { sceneLength: number; title: string; caption: string; phone: string }) => (
  <AbsoluteFill style={{ alignItems: "center", paddingTop: 96, gap: 22 }}>
    <Headline sceneLength={sceneLength} size={64}>{title}</Headline>
    <Caption sceneLength={sceneLength} delay={6}>{caption}</Caption>
    <div style={{ marginTop: 34 }}>
      <Phone src={phone} sceneLength={sceneLength} delay={8} height={860} />
    </div>
  </AbsoluteFill>
);

const Hook = () => {
  const n = length("hook");
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 26, padding: 90 }}>
      <Headline sceneLength={n}>Your online meetings<br />have notetakers.</Headline>
      <Headline sceneLength={n} delay={28}>
        <span style={{ color: MAROON, fontStyle: "italic" }}>The ones in a room don't.</span>
      </Headline>
    </AbsoluteFill>
  );
};

const Intro = () => {
  const n = length("intro");
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: frame - 4, fps, config: { damping: 14 } });
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 30 }}>
      <div
        style={{
          width: 150,
          height: 150,
          borderRadius: 75,
          background: MAROON,
          transform: `scale(${pop})`,
          opacity: interpolate(frame, [n - 12, n], [1, 0], { extrapolateLeft: "clamp" }),
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: "0 24px 60px rgba(115, 22, 40, 0.35)",
        }}
      >
        <div style={{ width: 46, height: 46, borderRadius: 23, background: "#fff" }} />
      </div>
      <Headline sceneLength={n} delay={10} size={110}>Bucephalus</Headline>
      <Caption sceneLength={n} delay={20}>A notetaker for conversations in person.</Caption>
    </AbsoluteFill>
  );
};

const Classroom = () => {
  const n = length("classroom");
  const frame = useCurrentFrame();
  const bar = (target: number, delay: number) =>
    interpolate(frame, [delay, delay + 40], [0, target], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const rows = [
    { label: "Apple's built-in model", words: 16, color: "#B9AEA7", delay: 30 },
    { label: "Whisper large-v3", words: 235, color: "#B9AEA7", delay: 42 },
    { label: "Parakeet, on-device", words: 563, color: MAROON, delay: 54 },
  ];
  const fade = interpolate(frame, [n - 12, n], [1, 0], { extrapolateLeft: "clamp" });
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 26, padding: 90 }}>
      <Headline sceneLength={n} size={64}>Even from the back of the class.</Headline>
      <Caption sceneLength={n} delay={8}>Same lecture, recorded 10 m away. Words captured:</Caption>
      <div style={{ width: "100%", marginTop: 40, display: "flex", flexDirection: "column", gap: 34, opacity: fade }}>
        {rows.map((r) => (
          <div key={r.label} style={{ fontFamily: sans }}>
            <div style={{ display: "flex", justifyContent: "space-between", fontSize: 30, color: INK, marginBottom: 12, fontWeight: 600 }}>
              <span>{r.label}</span>
              <span style={{ fontVariantNumeric: "tabular-nums", color: r.color === MAROON ? MAROON : MUTED }}>
                {Math.round(bar(r.words, r.delay))}
              </span>
            </div>
            <div style={{ height: 22, borderRadius: 11, background: "#E7E0DA", overflow: "hidden" }}>
              <div style={{ width: `${(bar(r.words, r.delay) / 563) * 100}%`, height: "100%", background: r.color, borderRadius: 11 }} />
            </div>
          </div>
        ))}
      </div>
    </AbsoluteFill>
  );
};

const End = () => {
  const n = length("end");
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 28 }}>
      <Headline sceneLength={n} size={110}>Bucephalus</Headline>
      <Caption sceneLength={n} delay={8}>Open source · iPhone · on-device</Caption>
      <div style={{ ...useEnter(18, n), marginTop: 20, fontFamily: sans, fontSize: 34, fontWeight: 600, color: "#fff", background: MAROON, padding: "20px 38px", borderRadius: 999 }}>
        github.com/Gagancreates/bucephalus
      </div>
    </AbsoluteFill>
  );
};

export const Launch = () => (
  <AbsoluteFill style={{ background: BG }}>
    <Sequence from={start("hook")} durationInFrames={length("hook")}><Hook /></Sequence>
    <Sequence from={start("intro")} durationInFrames={length("intro")}><Intro /></Sequence>
    <Sequence from={start("record")} durationInFrames={length("record")}>
      <Feature sceneLength={length("record")} title="Press record. Lock your phone." caption="It keeps listening in your pocket or on the table." phone="recording.png" />
    </Sequence>
    <Sequence from={start("lock")} durationInFrames={length("lock")}>
      <Feature sceneLength={length("lock")} title="Pause and stop from the lock screen." caption="Or start it with the Action Button." phone="live-activity.png" />
    </Sequence>
    <Sequence from={start("speakers")} durationInFrames={length("speakers")}>
      <Feature sceneLength={length("speakers")} title="Knows who said what." caption="Transcribed on your iPhone. Audio never leaves it." phone="transcript.png" />
    </Sequence>
    <Sequence from={start("summary")} durationInFrames={length("summary")}>
      <Feature sceneLength={length("summary")} title="A clean summary, instantly." caption="Key points, decisions, action items." phone="summary.png" />
    </Sequence>
    <Sequence from={start("classroom")} durationInFrames={length("classroom")}><Classroom /></Sequence>
    <Sequence from={start("end")} durationInFrames={length("end")}><End /></Sequence>
  </AbsoluteFill>
);
