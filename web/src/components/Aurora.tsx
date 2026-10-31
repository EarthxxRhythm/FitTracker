import { useEffect, useRef } from 'react'

/* ============================================================================
   Aurora —— 真 shader 极光背景
   ----------------------------------------------------------------------------
   从 site/assets/aurora-webgl.js 移植成 React 组件：逻辑不变，只是把
   getElementById 换成 ref。CSS 极光（.aurora 三层渐变）保留作兜底，
   无 WebGL 时 canvas 透明，用户看到的就是 CSS 版。

   降级：无 WebGL / reduced-motion 只渲一帧 / 页面隐藏暂停 / 30fps 上限。
   ========================================================================== */

const VERT = 'attribute vec2 aPos; void main() { gl_Position = vec4(aPos, 0.0, 1.0); }'

const FRAG = [
  'precision mediump float;',
  'uniform vec2 uRes;',
  'uniform float uTime;',
  'float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }',
  'float noise(vec2 p) {',
  '  vec2 i = floor(p); vec2 f = fract(p);',
  '  vec2 u = f * f * (3.0 - 2.0 * f);',
  '  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),',
  '             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);',
  '}',
  'float fbm(vec2 p) {',
  '  float v = 0.0; float a = 0.5;',
  '  for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }',
  '  return v;',
  '}',
  'void main() {',
  '  vec2 uv = gl_FragCoord.xy / uRes;',
  '  vec2 p = vec2(uv.x * (uRes.x / uRes.y), uv.y) * 1.7;',
  '  float t = uTime * 0.035;',
  '  float n1 = fbm(p + vec2(t, t * 0.55));',
  '  float n2 = fbm(p * 2.1 - vec2(t * 0.8, t * 0.35));',
  '  float n = n1 * 0.72 + n2 * 0.42;',
  '  float band = smoothstep(0.30, 0.82, n);',
  '  band = pow(band, 1.35);',
  '  vec3 deep = vec3(0.055, 0.088, 0.078);',
  '  vec3 core = vec3(0.298, 0.925, 0.643);',
  '  vec3 col = mix(deep, core, band);',
  '  col *= mix(1.0, 0.42, smoothstep(0.0, 1.0, uv.y));',
  '  float edge = smoothstep(0.0, 0.22, uv.x) * smoothstep(1.0, 0.78, uv.x);',
  '  col *= mix(0.55, 1.0, edge);',
  '  gl_FragColor = vec4(col, band * 0.80);',
  '}'
].join('\n')

function compile(gl: WebGLRenderingContext, type: number, src: string) {
  const sh = gl.createShader(type)
  if (!sh) return null
  gl.shaderSource(sh, src)
  gl.compileShader(sh)
  if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
    gl.deleteShader(sh)
    return null
  }
  return sh
}

export default function Aurora() {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const gl = canvas.getContext('webgl', {
      alpha: true,
      premultipliedAlpha: false,
      antialias: false,
      depth: false,
      stencil: false,
      powerPreference: 'low-power'
    })
    if (!gl) return

    const vs = compile(gl, gl.VERTEX_SHADER, VERT)
    const fs = compile(gl, gl.FRAGMENT_SHADER, FRAG)
    if (!vs || !fs) return

    const prog = gl.createProgram()
    if (!prog) return
    gl.attachShader(prog, vs)
    gl.attachShader(prog, fs)
    gl.linkProgram(prog)
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return
    gl.useProgram(prog)

    const buf = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, buf)
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
      gl.STATIC_DRAW
    )
    const aPos = gl.getAttribLocation(prog, 'aPos')
    gl.enableVertexAttribArray(aPos)
    gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0)

    const uRes = gl.getUniformLocation(prog, 'uRes')
    const uTime = gl.getUniformLocation(prog, 'uTime')

    gl.enable(gl.BLEND)
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE)
    gl.clearColor(0, 0, 0, 0)

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const scale = 0.5
    let elapsed = 0
    let last = 0
    let raf = 0
    let running = false

    function resize() {
      const w = Math.max(1, Math.round(window.innerWidth * scale))
      const h = Math.max(1, Math.round(window.innerHeight * scale))
      if (canvas!.width === w && canvas!.height === h) return
      canvas!.width = w
      canvas!.height = h
      gl!.viewport(0, 0, w, h)
      gl!.uniform2f(uRes, w, h)
    }

    function draw() {
      gl!.uniform1f(uTime, elapsed)
      gl!.clear(gl!.COLOR_BUFFER_BIT)
      gl!.drawArrays(gl!.TRIANGLES, 0, 6)
    }

    function frame(now: number) {
      if (!running) return
      raf = requestAnimationFrame(frame)
      if (now - last < 33) return   // 30fps 上限
      elapsed += (now - last) / 1000
      last = now
      draw()
    }

    function start() {
      if (running || reduceMotion) return
      running = true
      last = 0
      raf = requestAnimationFrame(frame)
    }

    function stop() {
      running = false
      if (raf) cancelAnimationFrame(raf)
      raf = 0
    }

    function onResize() {
      resize()
      if (reduceMotion) draw()
    }

    function onVisibility() {
      if (document.hidden) stop()
      else start()
    }

    resize()
    window.addEventListener('resize', onResize, { passive: true })
    document.addEventListener('visibilitychange', onVisibility)

    if (reduceMotion) {
      elapsed = 12.0
      draw()
    } else {
      start()
    }

    return () => {
      stop()
      window.removeEventListener('resize', onResize)
      document.removeEventListener('visibilitychange', onVisibility)
    }
  }, [])

  return (
    <>
      <div className="aurora" aria-hidden="true">
        <i />
        <i />
        <i />
      </div>
      <canvas className="aurora-gl" ref={canvasRef} aria-hidden="true" />
    </>
  )
}
