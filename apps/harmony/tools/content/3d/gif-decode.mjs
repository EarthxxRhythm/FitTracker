#!/usr/bin/env node
/**
 * GIF89a 解码器（自写，纯函数、纯 Node、零依赖）。
 *
 * 用途：3D 演示 GIF 的回归断言需要「解码回索引像素」——帧数、delay、循环次数、
 * 逐帧像素差都必须从字节里读出来，不能靠编码器自己报数。
 * 只覆盖本项目编码器实际产出的子集，并**显式声明覆盖范围**（避免同义反复的假绿）：
 *
 *   ✅ 支持：GIF89a/GIF87a 头、全局调色板、局部调色板、NETSCAPE2.0 循环次数、
 *            Graphic Control Extension（delay / disposal / transparentIndex）、
 *            Image Descriptor（含 offset）、连续 LZW 子块、标准 LZW 增宽与 clear。
 *   ❌ 不支持：隔行扫描（interlace）、纯文本扩展、注释扩展（按长度跳过，不解读）、
 *            disposal=3（restore to previous）的合成——本解码器返回**每帧原始索引**，
 *            **不做 disposal/合成**。因此调用方若改了编码选项（如启用透明差分、
 *            dispose 非 2），逐帧像素比较就不再有意义：那属于"编码器不确定"路径。
 *            本项目编码点固定 `{ repeat: 0, dispose: 2, transparent: false }`，
 *            与"每帧独立完整帧 + 不做合成"的假设一致（见 render/build 脚本注释）。
 *
 * 用法：
 *   import { decodeGif } from './gif-decode.mjs'
 *   const gif = decodeGif(fs.readFileSync('x.gif'))
 *   gif.frames[i].indices  // Uint8Array，长度 = width*height
 */

/**
 * @param {Uint8Array|Buffer} bytes
 * @returns {{
 *   signature: string, version: string, width: number, height: number,
 *   globalPalette: number[][]|null, loopCount: number|null,
 *   frames: Array<{ left: number, top: number, width: number, height: number,
 *                   indices: Uint8Array, palette: number[][], delayCs: number,
 *                   disposal: number, transparentIndex: number|null }>
 * }}
 */
export function decodeGif(bytes) {
  if (!bytes || bytes.length < 13) throw new Error('GIF 过短，不是有效文件')
  const buf = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes)
  const signature = String.fromCharCode(buf[0], buf[1], buf[2])
  if (signature !== 'GIF') throw new Error('不是 GIF 文件（缺 GIF 签名）')
  const version = String.fromCharCode(buf[3], buf[4], buf[5])

  let p = 6
  const width = buf[p] | (buf[p + 1] << 8)
  const height = buf[p + 2] | (buf[p + 3] << 8)
  const packed = buf[p + 4]
  const bgIndex = buf[p + 5]
  p += 7
  const hasGct = (packed & 0x80) !== 0
  const gctSize = 1 << ((packed & 0x07) + 1)

  let globalPalette = null
  if (hasGct) {
    const read = readPalette(buf, p, gctSize)
    globalPalette = read.palette
    p = read.next
  }

  /** @type {any[]} */
  const frames = []
  let loopCount = null
  let pending = { delayCs: 0, disposal: 0, transparentIndex: null }

  while (p < buf.length) {
    const block = buf[p]
    if (block === 0x3b) { p++; break } // trailer
    if (block === 0x21) { // extension
      const label = buf[p + 1]
      p += 2
      if (label === 0xf9) { // Graphic Control Extension
        const size = buf[p]
        if (size !== 4) throw new Error('GCE 长度异常：' + size)
        const flags = buf[p + 1]
        pending = {
          delayCs: buf[p + 2] | (buf[p + 3] << 8),
          disposal: (flags >> 2) & 0x07,
          transparentIndex: (flags & 0x01) ? buf[p + 4] : null
        }
        p += 5
        p = skipSubBlocks(buf, p)
      } else if (label === 0xff) { // Application Extension
        const size = buf[p]
        const appId = String.fromCharCode(...buf.subarray(p + 1, p + 1 + size))
        p += 1 + size
        if (appId === 'NETSCAPE2.0') {
          const { data, next } = readSubBlocks(buf, p)
          p = next
          if (data.length >= 3 && data[0] === 0x01) loopCount = data[1] | (data[2] << 8)
        } else {
          p = skipSubBlocks(buf, p)
        }
      } else {
        p = skipSubBlocks(buf, p)
      }
      continue
    }
    if (block === 0x2c) { // Image Descriptor
      const left = buf[p + 1] | (buf[p + 2] << 8)
      const top = buf[p + 3] | (buf[p + 4] << 8)
      const fw = buf[p + 5] | (buf[p + 6] << 8)
      const fh = buf[p + 7] | (buf[p + 8] << 8)
      const fpacked = buf[p + 9]
      p += 10
      let palette = globalPalette
      if (fpacked & 0x80) {
        const read = readPalette(buf, p, 1 << ((fpacked & 0x07) + 1))
        palette = read.palette
        p = read.next
      }
      if (!palette) throw new Error('第 ' + frames.length + ' 帧既无全局也无局部调色板')
      if (fpacked & 0x40) throw new Error('不支持隔行扫描帧（本项目编码器不产出 interlace）')
      const minCodeSize = buf[p]
      p += 1
      const { data, next } = readSubBlocks(buf, p)
      p = next
      const indices = lzwDecode(minCodeSize, data, fw * fh)
      frames.push({
        left, top, width: fw, height: fh, indices, palette,
        delayCs: pending.delayCs, disposal: pending.disposal,
        transparentIndex: pending.transparentIndex
      })
      pending = { delayCs: 0, disposal: 0, transparentIndex: null }
      continue
    }
    // 未知块：无法安全跳过，报错比静默错位好
    throw new Error('偏移 ' + p + ' 处的块标签未知：0x' + block.toString(16))
  }

  return { signature, version, width, height, globalPalette, loopCount, frames, backgroundIndex: bgIndex }
}

function readPalette(buf, p, size) {
  const palette = []
  for (let i = 0; i < size; i++) {
    palette.push([buf[p], buf[p + 1], buf[p + 2]])
    p += 3
  }
  return { palette, next: p }
}

function skipSubBlocks(buf, p) {
  while (p < buf.length) {
    const len = buf[p]
    p += 1 + len
    if (len === 0) break
  }
  return p
}

function readSubBlocks(buf, p) {
  const parts = []
  let total = 0
  while (p < buf.length) {
    const len = buf[p]
    if (len === 0) { p++; break }
    parts.push(buf.subarray(p + 1, p + 1 + len))
    total += len
    p += 1 + len
  }
  const data = new Uint8Array(total)
  let o = 0
  for (const part of parts) { data.set(part, o); o += part.length }
  return { data, next: p }
}

/**
 * GIF 变体 LZW：clear/eoi 语义与 TIFF LZW 不同（这里是"码宽先小后大，字典满则送 clear"）。
 * @param {number} minCodeSize
 * @param {Uint8Array} data 拼接后的子块数据
 * @param {number} expected 期望输出像素数（用于截断/校验）
 */
export function lzwDecode(minCodeSize, data, expected) {
  const clearCode = 1 << minCodeSize
  const eoiCode = clearCode + 1
  const out = new Uint8Array(expected)
  let outLen = 0

  // 字典用「前缀 + 末字节 + 链头字节」三个数组扁平表示，避免每项建数组
  const maxDict = 4096
  const prefix = new Int16Array(maxDict)
  const suffix = new Uint8Array(maxDict)
  const head = new Uint8Array(maxDict) // 该项串的第一个字节（新增项时继承 prev 的 head）
  let dictLen = 0
  const resetDict = () => {
    dictLen = eoiCode + 1
    for (let i = 0; i < clearCode; i++) { prefix[i] = -1; suffix[i] = i; head[i] = i }
    prefix[clearCode] = -1; suffix[clearCode] = 0; head[clearCode] = 0
    prefix[eoiCode] = -1; suffix[eoiCode] = 0; head[eoiCode] = 0
  }
  resetDict()

  let codeSize = minCodeSize + 1
  let bitBuf = 0
  let bitCnt = 0
  let pos = 0
  let prev = -1
  const stack = new Uint8Array(maxDict + 1)

  while (outLen < expected) {
    while (bitCnt < codeSize) {
      if (pos >= data.length) return out // 数据提前结束：返回已解部分（调用方自行判长度）
      bitBuf |= data[pos++] << bitCnt
      bitCnt += 8
    }
    const code = bitBuf & ((1 << codeSize) - 1)
    bitBuf >>>= codeSize
    bitCnt -= codeSize

    if (code === clearCode) {
      resetDict()
      codeSize = minCodeSize + 1
      prev = -1
      continue
    }
    if (code === eoiCode) break
    if (code > dictLen) throw new Error('LZW 码超出字典：code=' + code + ' dictLen=' + dictLen)

    // KwKwK：code === dictLen 时，串 = prev 串 + prev 串首字节（编码器尚未入表的那一项）
    const kwkwk = code === dictLen
    const entryCode = kwkwk ? prev : code
    if (entryCode < 0) throw new Error('LZW 首码无效（无 prev 可引用）')

    let sp = 0
    for (let c = entryCode; c >= 0; c = prefix[c]) {
      stack[sp++] = suffix[c]
      if (sp > maxDict) throw new Error('LZW 链条过长，字典损坏')
    }
    const firstByte = stack[sp - 1] // 链头 = 该串第一个字节（栈是反序，栈顶才是链头）
    while (sp > 0) {
      const b = stack[--sp]
      if (outLen < expected) out[outLen++] = b
    }
    if (kwkwk && outLen < expected) out[outLen++] = firstByte

    if (prev >= 0 && dictLen < maxDict) {
      // 新项 = prev 串 + 当前串首字节
      prefix[dictLen] = prev
      suffix[dictLen] = firstByte
      head[dictLen] = head[prev]
      dictLen++
      // 与 encode-gif.mjs 的配对（4 组合探针裁定唯一 PASS）：
      // decoder 在 dictLen == 2^codeSize - 1 时扩宽，encoder 在 nextCode == 2^codeSize 时扩宽。
      if (dictLen === (1 << codeSize) - 1 && codeSize < 12) codeSize++
    }
    prev = code
  }
  return out
}

export default decodeGif
