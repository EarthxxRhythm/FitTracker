// convert-legal-docs.mjs —— docs/legal/*.md → entry/src/main/resources/rawfile/legal/*.txt 转换工具
//
// 用途：法律文档的应用内展示副本生成。每次修改 docs/legal/privacy-policy.md 或
// user-agreement.md 正文、或替换占位符（【上线前须替换为…】）后，必须运行本脚本
// 重生成 rawfile 副本，两者不得漂移（约定见 docs/legal/README.md「应用内展示」）。
//
// 轻量清理规则（正文逐字保留，仅去除 markdown 标记）：
//   1) 行首 #~###### 标题前缀 → 去前缀留文字
//   2) ** 粗体标记 → 去除
//   3) ` 反引号（行内代码标记）→ 去除
//   4) 表格分隔行（| --- | --- |）→ 整行删除
//
// 用法：node tools/convert-legal-docs.mjs（任意 cwd 均可）
// 输出：每个目标的路径 + 行数 + 字节数（stdout），供转换对账。
//
// 2026-10-27 monorepo 重组修正：源文档在仓库根 `docs/`、目标在工程内 `entry/`，两者不再同前缀，
// 故改为按脚本位置解析（原先按 cwd 取相对路径，在 apps/harmony 下会找不到 docs/legal）。
import { readFileSync, writeFileSync, mkdirSync, statSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// tools/ → apps/harmony → apps → 仓库根
const harmonyRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const repoRoot = resolve(harmonyRoot, '..', '..')
const legalOutDir = join(harmonyRoot, 'entry/src/main/resources/rawfile/legal')

const jobs = [
  [join(repoRoot, 'docs/legal/privacy-policy.md'), join(legalOutDir, 'privacy-policy.txt')],
  [join(repoRoot, 'docs/legal/user-agreement.md'), join(legalOutDir, 'user-agreement.txt')]
]

mkdirSync(legalOutDir, { recursive: true })

for (const [src, dst] of jobs) {
  const text = readFileSync(src, 'utf8')
  const lines = text.split(/\r?\n/)
  const out = []
  for (const line of lines) {
    if (/^\|\s*[-:| ]+\s*\|$/.test(line)) {
      continue
    }
    let l = line.replace(/^#{1,6}\s+/, '')
    l = l.replace(/\*\*/g, '')
    l = l.replace(/`/g, '')
    out.push(l)
  }
  writeFileSync(dst, out.join('\n'))
  process.stdout.write(dst + ' lines=' + out.length + ' bytes=' + statSync(dst).size + '\n')
}
process.stdout.write('convert done\n')
