import { Composition } from "remotion";
import { Launch, LAUNCH_FRAMES } from "./Launch";

export const Root = () => (
  <Composition id="Launch" component={Launch} durationInFrames={LAUNCH_FRAMES} fps={30} width={1080} height={1350} />
);
