import { loadFont } from "@remotion/google-fonts/Inter";
import { loadFont as loadSerif } from "@remotion/google-fonts/InstrumentSerif";
import {
  AbsoluteFill,
  Audio,
  Img,
  OffthreadVideo,
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
  { id: "hook", length: 100 },
  { id: "intro", length: 80 },
  { id: "record", length: 170 },
  { id: "island", length: 120 },
  { id: "meeting", length: 200 },
  { id: "ondevice", length: 140 },
  { id: "classroom", length: 135 },
  { id: "cost", length: 125 },
  { id: "drawer", length: 110 },
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
const Phone = ({ src, video, startFrom = 0, delay = 0, sceneLength, height = 900 }: { src?: string; video?: string; startFrom?: number; delay?: number; sceneLength: number; height?: number }) => {
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
      {video ? (
        <OffthreadVideo src={staticFile(video)} startFrom={startFrom} muted style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      ) : (
        <Img src={staticFile(src!)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      )}
    </div>
  );
};

const Feature = ({ sceneLength, title, caption, phone, video, startFrom }: { sceneLength: number; title: string; caption: string; phone?: string; video?: string; startFrom?: number }) => (
  <AbsoluteFill style={{ alignItems: "center", paddingTop: 96, gap: 22 }}>
    <Headline sceneLength={sceneLength} size={64}>{title}</Headline>
    <Caption sceneLength={sceneLength} delay={6}>{caption}</Caption>
    <div style={{ marginTop: 34 }}>
      <Phone src={phone} video={video} startFrom={startFrom} sceneLength={sceneLength} delay={8} height={860} />
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
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 22 }}>
      <Headline sceneLength={n} size={124}>Bucephalus</Headline>
      <Caption sceneLength={n} delay={10}>A notetaker for conversations in person.</Caption>
    </AbsoluteFill>
  );
};

const Pill = ({ children, delay, sceneLength, strong = false }: { children: React.ReactNode; delay: number; sceneLength: number; strong?: boolean }) => (
  <div
    style={{
      ...useEnter(delay, sceneLength),
      fontFamily: sans,
      fontSize: 34,
      fontWeight: 600,
      color: strong ? "#fff" : INK,
      background: strong ? MAROON : "#E9E2DC",
      padding: "20px 34px",
      borderRadius: 999,
    }}
  >
    {children}
  </div>
);

const OnDevice = () => {
  const n = length("ondevice");
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 24, padding: 80 }}>
      <Headline sceneLength={n} size={70}>Everything runs<br /><span style={{ color: MAROON, fontStyle: "italic" }}>on your iPhone.</span></Headline>
      <Caption sceneLength={n} delay={8}>Open models on the Neural Engine. No uploads, works offline.</Caption>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 18, marginTop: 30 }}>
        <Pill sceneLength={n} delay={18}>Parakeet · speech to text</Pill>
        <Pill sceneLength={n} delay={26}>Speaker detection · who said what</Pill>
        <Pill sceneLength={n} delay={34} strong>Your audio never leaves the phone</Pill>
      </div>
    </AbsoluteFill>
  );
};

const CostRow = ({ label, value, note, delay, sceneLength, highlight = false }: { label: string; value: string; note: string; delay: number; sceneLength: number; highlight?: boolean }) => (
  <div style={{ ...useEnter(delay, sceneLength), width: "100%", display: "flex", alignItems: "baseline", justifyContent: "space-between", padding: "26px 0", borderBottom: "2px solid #E3DBD4", fontFamily: sans }}>
    <div>
      <div style={{ fontSize: 36, fontWeight: 600, color: INK }}>{label}</div>
      <div style={{ fontSize: 26, color: MUTED, marginTop: 6 }}>{note}</div>
    </div>
    <div style={{ fontFamily: serif, fontSize: 80, color: highlight ? MAROON : INK }}>{value}</div>
  </div>
);

const Cost = () => {
  const n = length("cost");
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 20, padding: 90 }}>
      <Headline sceneLength={n} size={70}>And it costs almost nothing.</Headline>
      <div style={{ width: "100%", marginTop: 30 }}>
        <CostRow sceneLength={n} delay={10} label="Transcription" note="On-device, unlimited" value="$0" highlight />
        <CostRow sceneLength={n} delay={18} label="Speaker labels" note="On-device, unlimited" value="$0" highlight />
        <CostRow sceneLength={n} delay={26} label="Summary" note="Your own OpenAI or Anthropic key" value="~1¢" />
        <CostRow sceneLength={n} delay={34} label="Subscription" note="Open source" value="None" />
      </div>
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
      <Caption sceneLength={n} delay={8}>Open source · on-device · for iPhone</Caption>
      <div style={{ ...useEnter(18, n), marginTop: 20, fontFamily: sans, fontSize: 34, fontWeight: 600, color: "#fff", background: MAROON, padding: "20px 38px", borderRadius: 999 }}>
        github.com/Gagancreates/bucephalus
      </div>
    </AbsoluteFill>
  );
};

export const Launch = () => {
  const frame = useCurrentFrame();
  // Music sits low under everything, ducking slightly during the busiest screens.
  const music = interpolate(frame, [0, 20, LAUNCH_FRAMES - 45, LAUNCH_FRAMES], [0, 0.6, 0.6, 0], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill style={{ background: BG }}>
      <Audio src={staticFile("music.wav")} volume={music} />
      <Sequence from={start("hook")} durationInFrames={length("hook")}><Hook /></Sequence>
      <Sequence from={start("intro")} durationInFrames={length("intro")}><Intro /></Sequence>
      <Sequence from={start("record")} durationInFrames={length("record")}>
        <Feature sceneLength={length("record")} title="Press record. Lock your phone." caption="It keeps listening, and tucks away while you browse." video="clips/record.mov" startFrom={105} />
      </Sequence>
      <Sequence from={start("island")} durationInFrames={length("island")}>
        <Feature sceneLength={length("island")} title="Use your phone as normal." caption="The recording lives in the Dynamic Island." video="clips/island.mov" startFrom={15} />
      </Sequence>
      <Sequence from={start("meeting")} durationInFrames={length("meeting")}>
        <Feature sceneLength={length("meeting")} title="Summary, speakers, notes." caption="Knows who said what. Transcribed on-device." video="clips/meeting.mov" startFrom={75} />
      </Sequence>
      <Sequence from={start("ondevice")} durationInFrames={length("ondevice")}><OnDevice /></Sequence>
      <Sequence from={start("classroom")} durationInFrames={length("classroom")}><Classroom /></Sequence>
      <Sequence from={start("cost")} durationInFrames={length("cost")}><Cost /></Sequence>
      <Sequence from={start("drawer")} durationInFrames={length("drawer")}>
        <Feature sceneLength={length("drawer")} title="Search and star everything." caption="Every meeting stays on your phone." video="clips/drawer.mov" startFrom={70} />
      </Sequence>
      <Sequence from={start("end")} durationInFrames={length("end")}><End /></Sequence>
    </AbsoluteFill>
  );
};
