//
// 自写 GIF 编码器（GIF89a + LZW 压缩，纯函数零依赖）。
//
// 与 gif-decode.mjs 配对（round-trip 测试守护）：本编码器产出的字节形态
// 完全受控——256 色全局调色板、每帧 GCE（delay 单位 1/100s）、
// 每帧完整索引帧（无局部调色板、无透明、dispose=2）、NETSCAPE 无限循环。
//
// 为什么不用 gifenc：实测其 writeFrame 字节行为（调色板区 3072 字节且内容未写）
// 与文档不符且 minified 不可追踪；自写后 vendor 依赖归零、字节可断言。

const MIN_CODE_SIZE = 8 // 256 色索引

/** GIF LZW 压缩（GIF 变体：clear/end 码 + early-change 码宽递增）。 */
export function lzwEncode(indices) {
  const clear = 1 << MIN_CODE_SIZE
  const end = clear + 1
  let codeSize = MIN_CODE_SIZE + 1
  const dict = new Map() // 单字符码 = 字符值本身（emit 直接用），无需字典条目
  let nextCode = end + 1

  const codes = []
  let bitBuf = 0
  let bitCnt = 0
  const emit = (code) => {
    bitBuf |= code << bitCnt
    bitCnt += codeSize
    while (bitCnt >= 8) {
      codes.push(bitBuf & 0xff)
      bitBuf >>>= 8
      bitCnt -= 8
    }
  }

  emit(clear)
  let prefix = indices[0]
  for (let i = 1; i < indices.length; i++) {
    const k = indices[i]
    const key = (prefix << 8) | k
    if (dict.has(key)) {
      prefix = dict.get(key)
      continue
    }
    emit(prefix)
    // 与 gif-decode.mjs 的配对（探针裁定唯一 PASS 组合）：
    // encoder 在 nextCode == 2^codeSize 时扩宽，decoder 在 dictLen == 2^codeSize - 1 时扩宽。
    // 字典满 4096 后停止增长（与解码器 dictLen < maxDict 对齐）。
    if (nextCode < 4096) {
      dict.set(key, nextCode++)
      if (nextCode === (1 << codeSize) && codeSize < 12) codeSize++
    }
    prefix = k
  }
  emit(prefix)
  emit(end)
  if (bitCnt > 0) codes.push(bitBuf & 0xff)
  return Uint8Array.from(codes)
}

function subBlocks(data) {
  const out = []
  for (let i = 0; i < data.length; i += 255) {
    const len = Math.min(255, data.length - i)
    out.push(len)
    for (let j = 0; j < len; j++) out.push(data[i + j])
  }
  out.push(0)
  return out
}

/**
 * 索引帧序列 → GIF 字节。
 * @param frames Uint8Array[]（每帧 width*height 索引）
 * @param opts { width, height, delays:number[]（1/100s）, palette:Uint8Array(768), loop:boolean }
 */
export function encodeGif(frames, opts) {
  const width = opts.width
  const height = opts.height
  const delays = opts.delays || frames.map(() => 4)
  const palette = opts.palette
  const bytes = []
  const push = (...xs) => bytes.push(...xs)

  push(0x47, 0x49, 0x46, 0x38, 0x39, 0x61) // GIF89a
  // LSD：packed = 0xF7（GCT=1，color resolution=7，size 低3位=111 → 256 色）
  push(width & 0xff, width >> 8, height & 0xff, height >> 8, 0xf7, 0, 0)
  // GCT
  for (let i = 0; i < 256 * 3; i++) push(palette[i])
  // NETSCAPE2.0 无限循环
  push(0x21, 0xff, 0x0b)
  for (const c of 'NETSCAPE2.0') push(c.charCodeAt(0))
  push(0x03, 0x01, 0x00, 0x00, 0x00)

  for (let f = 0; f < frames.length; f++) {
    // GCE：packed=0x04（dispose=1 不处置？用 dispose=0）——本编码器每帧完整，
    // disposal 语义无关紧要，写 dispose=0（未指定）、无透明。
    const delay = delays[f] & 0xffff
    push(0x21, 0xf9, 0x04, 0x00, delay & 0xff, delay >> 8, 0x00, 0x00)
    // Image Descriptor（整幅、无局部调色板、无交错）
    push(0x2c, 0, 0, 0, 0, width & 0xff, width >> 8, height & 0xff, height >> 8, 0x00)
    push(MIN_CODE_SIZE)
    const data = lzwEncode(frames[f])
    push(...subBlocks(data))
  }
  push(0x3b)
  return Buffer.from(Uint8Array.from(bytes))
}
