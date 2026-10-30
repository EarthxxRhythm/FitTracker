import React from "react";

export type Verdict = "active" | "pass" | "fail" | "pending";

const RINGS: { id: string; zh: string }[] = [
  { id: "req", zh: "需求" },
  { id: "design", zh: "设计" },
  { id: "dev", zh: "开发" },
  { id: "test", zh: "测试" },
  { id: "release", zh: "上线" },
  { id: "ops", zh: "运维" },
];

const COLORS: Record<Verdict, { border: string; text: string; bg: string }> = {
  active: { border: "#34d399", text: "#34d399", bg: "rgba(52,211,153,0.14)" },
  pass: { border: "#22c55e", text: "#22c55e", bg: "rgba(34,197,94,0.08)" },
  fail: { border: "#f87171", text: "#f87171", bg: "rgba(248,113,113,0.12)" },
  pending: { border: "#334155", text: "#64748b", bg: "transparent" },
};

const MARK: Record<Verdict, string> = {
  active: "●",
  pass: "✓",
  fail: "✗",
  pending: "·",
};

export const RingBar: React.FC<{ verdicts: Record<string, Verdict> }> = ({
  verdicts,
}) => {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 8,
      }}
    >
      {RINGS.map((ring, i) => {
        const v = verdicts[ring.id] ?? "pending";
        const c = COLORS[v];
        return (
          <React.Fragment key={ring.id}>
            {i > 0 && (
              <div
                style={{
                  width: 28,
                  height: 2,
                  background:
                    v === "active" || v === "pass" ? "#34d399" : "#334155",
                }}
              />
            )}
            <div
              style={{
                width: 104,
                height: 64,
                borderRadius: 10,
                border: `2px solid ${c.border}`,
                background: c.bg,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                gap: 2,
              }}
            >
              <div style={{ fontSize: 22, fontWeight: 700, color: c.text }}>
                {ring.id}
              </div>
              <div style={{ fontSize: 15, color: c.text, opacity: 0.85 }}>
                {MARK[v]} {ring.zh}
              </div>
            </div>
          </React.Fragment>
        );
      })}
    </div>
  );
};
