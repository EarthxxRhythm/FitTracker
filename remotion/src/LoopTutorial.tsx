import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { RingBar, Verdict } from "./components/RingBar";
import { Terminal } from "./components/Terminal";

const FPS = 30;
const INTRO_FRAMES = 90; // 开场 3s
const SCENE_FRAMES = 150; // 每场景 5s
const OUTRO_FRAMES = 600; // 结尾 20s

type Scene = {
  cmd: string;
  out: string[];
  ok: boolean;
  stage: string;
  seal: Verdict | null;
  note: string;
};

const SCENES: Scene[] = [
  {
    cmd: 'node tools/loop/state.mjs open --task ft-xxx --title "修 xxx"',
    out: ["已建任务 ft-xxx（stage=req）"],
    ok: true,
    stage: "req",
    seal: null,
    note: "第 1 步 · 开一个任务，落在需求环",
  },
  {
    cmd: "node tools/loop/verify.mjs --stage req --task ft-xxx",
    out: ["[verify] stage=req task=ft-xxx", "结论：passed（FAIL 0 / WARN 0）"],
    ok: true,
    stage: "req",
    seal: "pass",
    note: "第 2 步 · 需求环门禁通过（PRD 已带声明 + 零死引用）",
  },
  {
    cmd: "node tools/loop/state.mjs advance --task ft-xxx --to design",
    out: ["任务 ft-xxx 已推进到 design"],
    ok: true,
    stage: "design",
    seal: null,
    note: "第 3 步 · 上一环 pass 才放行，推进到设计环",
  },
  {
    cmd: "node tools/loop/verify.mjs --stage design --task ft-xxx",
    out: ["结论：passed（FAIL 0 / WARN 0）"],
    ok: true,
    stage: "design",
    seal: "pass",
    note: "设计环：契约影响 + 双端清单 + check-specs 全绿",
  },
  {
    cmd: "node tools/loop/verify.mjs --stage dev --task ft-xxx",
    out: ["结论：passed（check-gates 8 步全绿）"],
    ok: true,
    stage: "dev",
    seal: "pass",
    note: "开发环：check-gates 真实编译通过才过",
  },
  {
    cmd: "node tools/loop/verify.mjs --stage test --task ft-xxx",
    out: [
      "[check] unit-green: 3 of 3 groups passed",
      "[check] device: 鸿蒙 SKIP（模拟器未起，不计通过）",
      "结论：passed",
    ],
    ok: true,
    stage: "test",
    seal: "pass",
    note: "测试环：SKIP 不等于 PASS，全 SKIP 会被拦",
  },
  {
    cmd: "node tools/loop/state.mjs advance --task ft-xxx --to release",
    out: ["任务 ft-xxx 已推进到 release"],
    ok: true,
    stage: "release",
    seal: null,
    note: "推进到上线环",
  },
  {
    cmd: "node tools/loop/verify.mjs --stage release --task ft-xxx",
    out: [
      "[FAIL] readiness-green：本机无签名材料",
      "[FAIL] manual-dossier：缺 6 项人工签核",
      "结论：failed（FAIL 4 / WARN 1）",
    ],
    ok: false,
    stage: "release",
    seal: "fail",
    note: "上线环如实停在「无签名材料」——闭环该停的地方就停，等人工",
  },
];

const ORDER = ["req", "design", "dev", "test", "release", "ops"];

function computeVerdicts(upToSceneIndex: number): Record<string, Verdict> {
  const verdicts: Record<string, Verdict> = {};
  for (const id of ORDER) {
    verdicts[id] = "pending";
  }
  // 已结束的场景：应用 seal（跳过当前场景本身）
  for (let i = 0; i < upToSceneIndex; i += 1) {
    const s = SCENES[i];
    if (s.seal) {
      verdicts[s.stage] = s.seal;
    }
  }
  // 当前场景：活跃环
  if (upToSceneIndex < SCENES.length) {
    const current = SCENES[upToSceneIndex];
    verdicts[current.stage] = "active";
  }
  return verdicts;
}

export const LoopTutorial: React.FC = () => {
  const frame = useCurrentFrame();

  // 开场
  if (frame < INTRO_FRAMES) {
    const fade = interpolate(frame, [0, 30], [0, 1], {
      extrapolateRight: "clamp",
    });
    return (
      <AbsoluteFill
        style={{ background: "#0b0e13", justifyContent: "center", alignItems: "center", display: "flex", flexDirection: "column", gap: 20 }}
      >
        <div style={{ opacity: fade, fontSize: 54, fontWeight: 800, color: "#e2e8f0" }}>
          六环闭环 agent 体系
        </div>
        <div style={{ opacity: fade, fontSize: 26, color: "#34d399" }}>
          需求 → 设计 → 开发 → 测试 → 上线 → 运维
        </div>
        <div style={{ opacity: fade, fontSize: 18, color: "#64748b" }}>
          操作步骤教程 · 三条命令跑通一条流水线
        </div>
      </AbsoluteFill>
    );
  }

  const rel = frame - INTRO_FRAMES;

  // 结尾
  if (rel >= SCENES.length * SCENE_FRAMES) {
    const outroFrame = rel - SCENES.length * SCENE_FRAMES;
    const fade = interpolate(outroFrame, [0, 20], [0, 1], { extrapolateRight: "clamp" });
    return (
      <AbsoluteFill
        style={{ background: "#0b0e13", justifyContent: "center", alignItems: "center", display: "flex", flexDirection: "column", gap: 26 }}
      >
        <div style={{ opacity: fade, fontSize: 38, fontWeight: 800, color: "#e2e8f0" }}>
          就这三条命令
        </div>
        {[
          "node tools/loop/state.mjs open    —— 开任务",
          "node tools/loop/verify.mjs         —— 门禁（0 过 / 1 拦 / 2 无证据）",
          "node tools/loop/state.mjs advance  —— 通过才推进",
        ].map((line, i) => (
          <div
            key={line}
            style={{
              opacity: interpolate(outroFrame, [20 + i * 20, 40 + i * 20], [0, 1], { extrapolateRight: "clamp" }),
              fontSize: 22,
              color: "#94a3b8",
              fontFamily: "'JetBrains Mono', 'Consolas', monospace",
            }}
          >
            {line}
          </div>
        ))}
        <div
          style={{
            opacity: interpolate(outroFrame, [100, 130], [0, 1], { extrapolateRight: "clamp" }),
            marginTop: 24,
            fontSize: 22,
            color: "#34d399",
          }}
        >
          门禁不绿就停 · 停下来的地方就是问题
        </div>
      </AbsoluteFill>
    );
  }

  // 主场景
  const sceneIndex = Math.floor(rel / SCENE_FRAMES);
  const sceneFrame = rel % SCENE_FRAMES;
  const scene = SCENES[sceneIndex];
  const verdicts = computeVerdicts(sceneIndex);

  const stepFade = interpolate(sceneFrame, [0, 12], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      style={{ background: "#0b0e13", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 44 }}
    >
      <div style={{ fontSize: 20, color: "#64748b", letterSpacing: 2 }}>
        六环闭环 · 操作教程
      </div>

      <div style={{ opacity: stepFade }}>
        <RingBar verdicts={verdicts} />
      </div>

      <Terminal
        command={scene.cmd}
        output={scene.out}
        ok={scene.ok}
        frame={sceneFrame}
      />

      <div style={{ fontSize: 22, color: "#cbd5e1", opacity: stepFade }}>
        {scene.note}
      </div>
    </AbsoluteFill>
  );
};
