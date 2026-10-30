import { Composition } from "remotion";
import { LoopTutorial } from "./LoopTutorial";

export const Root = () => {
  return (
    <Composition
      id="LoopTutorial"
      component={LoopTutorial}
      durationInFrames={1890}
      fps={30}
      width={1280}
      height={720}
    />
  );
};
