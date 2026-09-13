// check-auth-spacing.mjs —— 对照原型 CSS，校验 auth 屏（login / register）的间距声明是否补齐。
//
// 背景（RED 用例的来源）
// ----------------------
// register 屏视觉偏差 11.61%（目标 ≤8%），与 login 同源（同一 fittracker-auth.html）。
// login 已通过补齐原型声明 `.auth-cta{margin-top:20px}` 与 `.auth-aux{margin-top:2px}` 达标（2ea9813）。
// register 属同一 auth 骨架，但多一个「确认密码」字段与「同意条款」勾选，
// 原型结构上是 `.auth-form{gap:14px}` 内多挂两项：`.agree`（margin-top:4px）与 `.auth-cta`（margin-top:20px）。
// 实现侧若把这两项移出 `Column({ space: 14 })`，gap 便不生效，间距整段丢失。
//
// 判据来源
// --------
// design/06_prototype_redraw/src/fittracker-auth.html 的 <style> 声明值，
// 并与 tools/probe-css-metrics.py 的 Chrome 实测交叉核对（frame 1 = register）：
//   .auth-brand  底 → .auth-head  顶 = 22
//   .auth-head   底 → .auth-form  顶 = 26
//   field[4]     底 → .agree      顶 = 18  (gap 14 + margin-top 4)
//   .agree       底 → .auth-cta   顶 = 34  (gap 14 + margin-top 20)
//   .auth-cta    底 → .auth-switch 顶 = 26
//
// 运行：node --test tools/check-auth-spacing.test.mjs

export const AUTH_PROTOTYPE_HTML = 'design/06_prototype_redraw/src/fittracker-auth.html'
export const REGISTER_PAGE_ETS = 'entry/src/main/ets/features/pencil/pages/PencilRegisterPage.ets'
export const LOGIN_PAGE_ETS = 'entry/src/main/ets/features/pencil/pages/PencilLoginPage.ets'

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function ruleBody(cssText, selector) {
  const pattern = new RegExp(escapeRegExp(selector) + '\\s*\\{([^{}]*)\\}')
  const found = cssText.match(pattern)
  return found ? found[1] : null
}

function declPx(body, property) {
  if (body === null) {
    return null
  }
  const pattern = new RegExp('(?:^|[;{\\s])' + escapeRegExp(property) + '\\s*:\\s*(-?[\\d.]+)px')
  const found = body.match(pattern)
  return found ? Number(found[1]) : null
}

/** 解析 `margin` 简写为四边值；多数元素只声明单边属性，故仅 .auth-brand 需要。 */
function declMarginBox(body, property) {
  if (body === null) {
    return null
  }
  const pattern = new RegExp('(?:^|[;{\\s])' + escapeRegExp(property) + '\\s*:\\s*([^;}]+)')
  const found = body.match(pattern)
  if (found === null) {
    return null
  }
  const parts = found[1].trim().split(/\s+/).map(function (value) {
    return Number.parseFloat(value)
  })
  if (parts.length === 0 || parts.some(function (value) { return Number.isNaN(value) })) {
    return null
  }
  const top = parts[0]
  const right = parts.length > 1 ? parts[1] : parts[0]
  const bottom = parts.length > 2 ? parts[2] : top
  const left = parts.length > 3 ? parts[3] : right
  return { top: top, right: right, bottom: bottom, left: left }
}

/** 解析原型 <style> 中 auth 屏共用的间距声明（画布内 px）。 */
export function parsePrototypeAuthSpacing(htmlText) {
  const styleMatch = htmlText.match(/<style[\s\S]*?<\/style>/)
  const cssText = styleMatch ? styleMatch[0] : htmlText
  const brand = ruleBody(cssText, '.auth-brand')
  const head = ruleBody(cssText, '.auth-head')
  const form = ruleBody(cssText, '.auth-form')
  const fieldLabel = ruleBody(cssText, '.field-label')
  const agree = ruleBody(cssText, '.agree')
  const cta = ruleBody(cssText, '.auth-cta')
  const brandBox = declMarginBox(brand, 'margin')
  return {
    brandMarginBottom: brandBox ? brandBox.bottom : null,
    headMarginBottom: declPx(head, 'margin-bottom'),
    formGap: declPx(form, 'gap'),
    fieldLabelMarginBottom: declPx(fieldLabel, 'margin-bottom'),
    agreeMarginTop: declPx(agree, 'margin-top'),
    ctaMarginTop: declPx(cta, 'margin-top')
  }
}

function skipStringLiteral(source, start) {
  const quote = source[start]
  for (let index = start + 1; index < source.length; index += 1) {
    if (source[index] === '\\') {
      index += 1
      continue
    }
    if (source[index] === quote) {
      return index
    }
  }
  throw new Error('未闭合的字符串字面量（起点 ' + start + '）')
}

/** 从 source[openIndex]（指向 '{'）起取出花括号配对的整块文本，跳过字符串字面量。 */
export function sliceBalancedBlock(source, openIndex) {
  let depth = 0
  for (let index = openIndex; index < source.length; index += 1) {
    const ch = source[index]
    if (ch === "'" || ch === '"' || ch === '`') {
      index = skipStringLiteral(source, index)
      continue
    }
    if (ch === '{') {
      depth += 1
      continue
    }
    if (ch === '}') {
      depth -= 1
      if (depth === 0) {
        return source.slice(openIndex, index + 1)
      }
    }
  }
  throw new Error('花括号不平衡（起点 ' + openIndex + '）')
}

/** 匹配锚点后，取锚点内最后一个 '{' 起的配对块。返回 { start, text } 或 null。 */
export function blockAfterAnchor(source, anchorPattern) {
  const found = source.match(anchorPattern)
  if (found === null) {
    return null
  }
  const openRelative = found[0].lastIndexOf('{')
  if (openRelative < 0) {
    return null
  }
  const blockStart = found.index + openRelative
  const text = sliceBalancedBlock(source, blockStart)
  return {
    start: blockStart,
    end: blockStart + text.length,
    text: text
  }
}

function readMarginValue(body, key) {
  const pattern = new RegExp('(?:^|[,\\s])' + key + '\\s*:\\s*(-?[\\d.]+)')
  const found = body.match(pattern)
  return found ? Number(found[1]) : null
}

/** 从 fromIndex 起第一个 `.margin({ ... })` 声明，解析出 top / bottom。 */
export function firstMarginAfter(source, fromIndex) {
  const rest = source.slice(fromIndex)
  const found = rest.match(/\.margin\(\{([^}]*)\}\)/)
  if (found === null) {
    return null
  }
  return {
    raw: found[0],
    top: readMarginValue(found[1], 'top'),
    bottom: readMarginValue(found[1], 'bottom')
  }
}

const FORM_ANCHOR = /Column\(\{\s*space:\s*14\s*\}\)\s*\{/
const HEAD_ANCHOR = /Column\(\{\s*space:\s*0\s*\}\)\s*\{/
const AGREE_ANCHOR = /Row\(\{\s*space:\s*10\s*\}\)\s*\{/
const CTA_ANCHOR = /Button\(this\.loading \? '[^']*' : '[^']*'\)/

/**
 * 采集一个 auth 屏实现的结构化间距事实。
 * 每个 margin 取「锚点元素链上第一个 .margin(...)」——这些元素的链上各自只有一个 margin 声明。
 */
export function collectAuthScreenFacts(source) {
  const form = blockAfterAnchor(source, FORM_ANCHOR)
  const head = blockAfterAnchor(source, HEAD_ANCHOR)
  const agree = blockAfterAnchor(source, AGREE_ANCHOR)
  const cta = source.match(CTA_ANCHOR)

  const formText = form ? form.text : ''
  const fieldMatches = formText.match(/this\.buildField\(/g)

  // 注意：margin 必须从「元素的属性链」上取，即块结束后开始搜。
  // 从锚点位置搜会先命中子元素（如 checkbox 的 .margin({ top: 1 })），得到错误值。
  return {
    form: form
      ? { margin: firstMarginAfter(source, form.end), text: formText }
      : null,
    head: head ? { margin: firstMarginAfter(source, head.end) } : null,
    agree: agree ? { margin: firstMarginAfter(source, agree.end) } : null,
    cta: cta ? { margin: firstMarginAfter(source, cta.index + cta[0].length) } : null,
    fieldCountInForm: fieldMatches ? fieldMatches.length : 0,
    agreeInsideForm: formText.includes('我已阅读并同意'),
    ctaInsideForm: /Button\(this\.loading/.test(formText)
  }
}

/** 把原型声明与实现事实摊平成逐项判据，供测试与报告共用。 */
export function evaluateRegisterSpacing(registerSource, loginSource, prototypeSpacing) {
  const register = collectAuthScreenFacts(registerSource)
  const login = collectAuthScreenFacts(loginSource)
  const marginOf = function (entry) {
    return entry && entry.margin ? entry.margin : null
  }
  const registerFormMargin = marginOf(register.form)
  const loginFormMargin = marginOf(login.form)
  const registerHeadMargin = marginOf(register.head)
  const registerAgreeMargin = marginOf(register.agree)
  const registerCtaMargin = marginOf(register.cta)
  const loginCtaMargin = marginOf(login.cta)

  return {
    headMarginBottom: {
      expected: prototypeSpacing.headMarginBottom,
      actual: registerHeadMargin ? registerHeadMargin.bottom : null
    },
    ctaMarginTop: {
      expected: prototypeSpacing.ctaMarginTop,
      actual: registerCtaMargin ? registerCtaMargin.top : null
    },
    agreeMarginTop: {
      expected: prototypeSpacing.agreeMarginTop,
      actual: registerAgreeMargin ? registerAgreeMargin.top : null
    },
    formGapConsistency: {
      registerTop: registerFormMargin ? registerFormMargin.top : null,
      registerBottom: registerFormMargin ? registerFormMargin.bottom : null,
      loginTop: loginFormMargin ? loginFormMargin.top : null,
      loginBottom: loginFormMargin ? loginFormMargin.bottom : null
    },
    fieldCountInForm: register.fieldCountInForm,
    agreeInsideForm: register.agreeInsideForm,
    ctaInsideForm: register.ctaInsideForm,
    loginCtaMarginTop: loginCtaMargin ? loginCtaMargin.top : null
  }
}
