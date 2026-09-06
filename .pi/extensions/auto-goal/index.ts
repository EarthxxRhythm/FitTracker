/**
 * auto-goal —— 还原队列自动续跑扩展（方案 B）
 *
 * 让主模型在每一轮结束后，若还原队列（cluster/inbox）仍有未完成任务，
 * 自动注入一条“继续执行队列”的用户消息，无需人工反复输入“继续”。
 *
 * 命令：
 *   /goal status                查看开关与队列状态
 *   /goal on [maxTurns]         开启自动续跑（默认 60 轮上限）
 *   /goal once                  只执行下一项后暂停（干跑测试）
 *   /goal off                   关闭自动续跑
 *
 * 停止条件（不会空转）：
 *   1) cluster/inbox 没有未完成任务（对应 outbox 缺失）→ 发汇总并自动 off；
 *   2) 达到 maxTurns 或时间窗（默认 8h）→ 暂停；
 *   3) 主模型回复中出现标记 AUTO-GOAL-STOP → 暂停等人工；
 *   4) 同一任务连续注入 2 次仍无 outbox → 暂停（防卡死重试）。
 */
import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface GoalState {
	enabled: boolean;
	maxTurns: number;
	turnsUsed: number;
	startTime: number;
	windowMs: number;
	lastTask: string;
	lastTaskRepeat: number;
}

const STATE_FILE = path.join("cluster", ".auto-goal.json");
const INBOX_DIR = path.join("cluster", "inbox");
const OUTBOX_DIR = path.join("cluster", "outbox");

const DEFAULT_MAX_TURNS = 60;
const DEFAULT_WINDOW_MS = 8 * 60 * 60 * 1000;
const STOP_MARKER = "AUTO-GOAL-STOP";

function defaultState(): GoalState {
	return {
		enabled: false,
		maxTurns: DEFAULT_MAX_TURNS,
		turnsUsed: 0,
		startTime: 0,
		windowMs: DEFAULT_WINDOW_MS,
		lastTask: "",
		lastTaskRepeat: 0,
	};
}

function loadState(): GoalState {
	try {
		const raw = fs.readFileSync(STATE_FILE, "utf-8");
		const parsed = JSON.parse(raw) as GoalState;
		if (typeof parsed.enabled === "boolean") {
			return parsed;
		}
	} catch (_e) {
		// first run or missing file
	}
	return defaultState();
}

function saveState(state: GoalState): void {
	try {
		fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
		fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), "utf-8");
	} catch (_e) {
		// best effort
	}
}

function listJsonNames(dir: string): string[] {
	try {
		return fs
			.readdirSync(dir)
			.filter((name) => name.endsWith(".json"))
			.sort((a, b) => {
				const ta = fs.statSync(path.join(dir, a)).mtimeMs;
				const tb = fs.statSync(path.join(dir, b)).mtimeMs;
				return ta - tb;
			});
	} catch (_e) {
		return [];
	}
}

/** inbox 中还没有对应 outbox 的任务（最旧优先）。 */
function pendingTasks(): string[] {
	const outboxNames = new Set(listJsonNames(OUTBOX_DIR));
	return listJsonNames(INBOX_DIR).filter((name) => !outboxNames.has(name));
}

function hasInbox(): boolean {
	return listJsonNames(INBOX_DIR).length > 0;
}

function assistantText(event: { messages?: unknown[] }): string {
	const messages = event.messages ?? [];
	let text = "";
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i] as { role?: string; content?: unknown };
		if (msg && msg.role === "assistant") {
			const content = msg.content;
			if (typeof content === "string") {
				text = content;
			} else if (Array.isArray(content)) {
				for (const part of content) {
					const p = part as { type?: string; text?: string };
					if (p && p.type === "text" && typeof p.text === "string") {
						text += p.text;
					}
				}
			}
			break;
		}
	}
	return text;
}

function notify(ctx: { ui?: { notify?: (msg: string, level?: string) => void } }, msg: string): void {
	try {
		ctx.ui?.notify?.(msg, "info");
	} catch (_e) {
		// no ui
	}
}

export default function (pi: ExtensionAPI): void {
	let state: GoalState = loadState();

	pi.registerCommand("goal", {
		description: "还原队列自动续跑开关。on [maxTurns] / off / once / status",
		handler: async (args: string, ctx: unknown) => {
			const c = ctx as { ui?: { notify?: (msg: string, level?: string) => void } };
			const parts = args.trim().split(/\s+/);
			const cmd = (parts[0] || "status").toLowerCase();

			if (cmd === "on") {
				state = { ...defaultState(), enabled: true };
				if (parts[1] !== undefined) {
					const n = Number.parseInt(parts[1], 10);
					if (Number.isFinite(n) && n > 0) {
						state.maxTurns = n;
					}
				}
				state.turnsUsed = 0;
				state.startTime = Date.now();
				saveState(state);
				notify(c, "auto-goal: 已开启（maxTurns=" + state.maxTurns + "）。无需输入，队列跑完或遇 blocker 自动停。");
				return;
			}

			if (cmd === "off") {
				state.enabled = false;
				saveState(state);
				notify(c, "auto-goal: 已关闭。");
				return;
			}

			if (cmd === "once") {
				const tasks = pendingTasks();
				if (tasks.length === 0) {
					notify(c, "auto-goal: 队列已空，无可执行项。");
					return;
				}
				state = { ...defaultState(), enabled: false, turnsUsed: 0, lastTask: tasks[0], lastTaskRepeat: 1 };
				saveState(state);
				const next = tasks[0];
				const msg = buildContinueMessage(next, tasks.length);
				pi.sendUserMessage(msg, { deliverAs: "followUp", triggerTurn: true });
				return;
			}

			// status (default)
			const tasks = pendingTasks();
			notify(
				c,
				"auto-goal: " + (state.enabled ? "运行中" : "关闭") +
					" | 剩余 " + tasks.length + " 项 | 已用 " + state.turnsUsed + "/" + state.maxTurns +
					" 轮" + (tasks.length > 0 ? " | 下一项 " + tasks[0] : ""),
			);
		},
	});

	pi.on("agent_end", async (event: { messages?: unknown[] }, ctx: unknown) => {
		if (!state.enabled || !hasInbox()) {
			return;
		}
		const c = ctx as { isIdle?: () => boolean; ui?: { notify?: (msg: string, level?: string) => void } };
		if (typeof c.isIdle === "function" && !c.isIdle()) {
			return;
		}

		const text = assistantText(event);
		if (text.includes(STOP_MARKER)) {
			state.enabled = false;
			saveState(state);
			notify(c, "auto-goal: 检测到 " + STOP_MARKER + "，已暂停等人工。");
			return;
		}

		const tasks = pendingTasks();
		if (tasks.length === 0) {
			state.enabled = false;
			saveState(state);
			notify(c, "auto-goal: 队列已全部完成，已自动关闭。");
			return;
		}

		const now = Date.now();
		if (state.turnsUsed >= state.maxTurns || now - state.startTime > state.windowMs) {
			state.enabled = false;
			saveState(state);
			notify(c, "auto-goal: 达到轮次/时间上限，已暂停（/goal on 可续跑）。");
			return;
		}

		const next = tasks[0];
		if (next === state.lastTask) {
			state.lastTaskRepeat += 1;
			if (state.lastTaskRepeat > 2) {
				state.enabled = false;
				saveState(state);
				notify(c, "auto-goal: 任务 " + next + " 连续注入无 outbox，已暂停等人工。");
				return;
			}
		} else {
			state.lastTask = next;
			state.lastTaskRepeat = 1;
		}

		state.turnsUsed += 1;
		saveState(state);

		const msg = buildContinueMessage(next, tasks.length);
		pi.sendUserMessage(msg, { deliverAs: "followUp", triggerTurn: true });
	});
}

function buildContinueMessage(taskFile: string, remaining: number): string {
	return (
		"继续执行还原队列（auto-goal，剩余 " + remaining + " 项）。\n" +
		"下一步任务：" + taskFile + "（读 cluster/inbox/" + taskFile + " 的任务说明并执行）。\n" +
		"约束：只改任务 owner_files；完成后把结果写入 cluster/outbox/" + taskFile +
		"（task/status/summary/changed_files/evidence/gaps）。\n" +
		"执行完若队列仍有任务，本回合正常结束即可（auto-goal 会自动续下一项）。\n" +
		"若遇到需要人工决策的 blocker，在回复中写明 " + STOP_MARKER + " 并说明原因后停止。不要空转。"
	);
}
