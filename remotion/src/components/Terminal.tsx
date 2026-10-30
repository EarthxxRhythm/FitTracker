import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";

// 打字机：给定场景内相对帧，返回应显示的命令字符数与输出字符数。
export const useTypewriter = (
  frame: number,
  cmdLen: number,
  outLen: number
) => {
  const cmdChars = Math.floor(
    interpolate(frame, [0, 55], [0, cmdLen], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    })
  );
  const outChars = Math.floor(
    interpolate(frame, [62, 117], [0, outLen], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    })
  );
  return { cmdChars, outChars };
};

const PROMPT = "$ ";

export const Terminal: React.FC<{
  command: string;
  output: string[];
  ok: boolean;
  frame: number;
}> = ({ command, output, ok, frame }) => {
  const { cmdChars, outChars } = useTypewriter(
    frame,
    command.length,
    output.join("\n").length
  );

  const shownCmd = command.slice(0, cmdChars);
  const shownOut = output.join("\n").slice(0, outChars);

  return (
    <div
      style={{
        width: 980,
        minHeight: 300,
        borderRadius: 12,
        background: "#11151d",
        border: "1px solid #2a3140",
        boxShadow: "0 12px 40px rgba(0,0,0,0.45)",
        overflow: "hidden",
        fontFamily: "'JetBrains Mono', 'Consolas', 'Courier New', monospace",
      }}
    >
      <div
        style={{
          height: 40,
          background: "#1a2028",
          display: "flex",
          alignItems: "center",
          gap: 8,
          paddingLeft: 16,
          borderBottom: "1px solid #2a3140",
        }}
      >
        <div
          style={{ width: 12, height: 12, borderRadius: 6, background: "#f87171" }}
        />
        <div
          style={{ width: 12, height: 12, borderRadius: 6, background: "#fbbf24" }}
        />
        <div
          style={{ width: 12, height: 12, borderRadius: 6, background: "#34d399" }}
        />
        <span style={{ marginLeft: 12, fontSize: 14, color: "#64748b" }}>
          fittracker · 六环闭环
        </span>
      </div>

      <div style={{ padding: "28px 32px", fontSize: 20, lineHeight: 1.65 }}>
        <div style={{ display: "flex", gap: 10 }}>
          <span style={{ color: "#34d399", fontWeight: 700 }}>{PROMPT}</span>
          <span style={{ color: "#e2e8f0", whiteSpace: "pre-wrap" }}>
            {shownCmd}
            {cmdChars < command.length && (
              <span
                style={{
                  color: "#34d399",
                  animation: "blink 1s steps(1) infinite",
                }}
              >
                ▊
              </span>
            )}
          </span>
        </div>
        {outChars > 0 && (
          <div
            style={{
              marginTop: 10,
              paddingLeft: 26,
              color: ok ? "#94a3b8" : "#f87171",
              whiteSpace: "pre-wrap",
            }}
          >
            {shownOut}
          </div>
        )}
      </div>
    </div>
  );
};
