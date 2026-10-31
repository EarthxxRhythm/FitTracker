/* ============================================================================
   aurora-webgl.js —— 真 shader 极光（裸 WebGL，不引 three.js）
   ----------------------------------------------------------------------------
   为什么裸写：three.js 约 600KB，而这里只需要「一个全屏 quad + 一个 fragment
   shader」，约 3KB 就够。视觉效果等价，首屏代价小两个数量级。

   shader 内容：两层 FBM 域扭曲噪声叠加成流动的极光带，
   色相取站点主色 #4CECA4，向上渐隐。

   降级链（任一不满足就静默退出，CSS 极光继续工作）：
     无 WebGL            → 直接 return
     prefers-reduced-motion → 只渲染一帧静态帧
     页面不可见          → 暂停 rAF，可见时恢复
     30fps 上限          → 省电，肉眼无差

   渲染分辨率按容器尺寸 × 0.5 取，再靠 CSS 拉伸——大面积极光本来就没有锐利
   细节，降采样后肉眼无差，GPU 负载降到 1/4。
   ========================================================================== */
(function () {
  'use strict'

  var VERT = [
    'attribute vec2 aPos;',
    'void main() { gl_Position = vec4(aPos, 0.0, 1.0); }'
  ].join('\n')

  var FRAG = [
    'precision mediump float;',
    'uniform vec2 uRes;',
    'uniform float uTime;',
    '',
    'float hash(vec2 p) {',
    '  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);',
    '}',
    '',
    'float noise(vec2 p) {',
    '  vec2 i = floor(p);',
    '  vec2 f = fract(p);',
    '  vec2 u = f * f * (3.0 - 2.0 * f);',
    '  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),',
    '             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);',
    '}',
    '',
    'float fbm(vec2 p) {',
    '  float v = 0.0;',
    '  float a = 0.5;',
    '  for (int i = 0; i < 5; i++) {',
    '    v += a * noise(p);',
    '    p *= 2.03;',
    '    a *= 0.5;',
    '  }',
    '  return v;',
    '}',
    '',
    'void main() {',
    '  vec2 uv = gl_FragCoord.xy / uRes;',
    '  vec2 p = vec2(uv.x * (uRes.x / uRes.y), uv.y) * 1.7;',
    '  float t = uTime * 0.035;',
    '',
    '  // 两层 FBM，一层正向漂移、一层反向，形成剪切感',
    '  float n1 = fbm(p + vec2(t, t * 0.55));',
    '  float n2 = fbm(p * 2.1 - vec2(t * 0.8, t * 0.35));',
    '  float n = n1 * 0.72 + n2 * 0.42;',
    '',
    '  // 极光带：只让高值区发亮，低值区留黑',
    '  float band = smoothstep(0.30, 0.82, n);',
    '  band = pow(band, 1.35);',
    '',
    '  vec3 deep = vec3(0.055, 0.088, 0.078);',
    '  vec3 core = vec3(0.298, 0.925, 0.643);   // ≈ #4CECA4',
    '  vec3 col = mix(deep, core, band);',
    '',
    '  // 上亮下暗，模拟光源在上方',
    '  col *= mix(1.0, 0.42, smoothstep(0.0, 1.0, uv.y));',
    '',
    '  // 两侧收边，避免极光糊满整屏',
    '  float edge = smoothstep(0.0, 0.22, uv.x) * smoothstep(1.0, 0.78, uv.x);',
    '  col *= mix(0.55, 1.0, edge);',
    '',
    '  gl_FragColor = vec4(col, band * 0.80);',
    '}'
  ].join('\n')

  function compile(gl, type, src) {
    var sh = gl.createShader(type)
    gl.shaderSource(sh, src)
    gl.compileShader(sh)
    if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
      gl.deleteShader(sh)
      return null
    }
    return sh
  }

  function init() {
    var canvas = document.getElementById('auroraGl')
    if (!canvas) return

    var gl = canvas.getContext('webgl', {
      alpha: true,
      premultipliedAlpha: false,
      antialias: false,
      depth: false,
      stencil: false,
      powerPreference: 'low-power'
    })
    if (!gl) return   // 无 WebGL：CSS 极光兜底

    var vs = compile(gl, gl.VERTEX_SHADER, VERT)
    var fs = compile(gl, gl.FRAGMENT_SHADER, FRAG)
    if (!vs || !fs) return

    var prog = gl.createProgram()
    gl.attachShader(prog, vs)
    gl.attachShader(prog, fs)
    gl.linkProgram(prog)
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return
    gl.useProgram(prog)

    // 全屏三角带
    var buf = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, buf)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
      -1, -1, 1, -1, -1, 1,
      -1, 1, 1, -1, 1, 1
    ]), gl.STATIC_DRAW)
    var aPos = gl.getAttribLocation(prog, 'aPos')
    gl.enableVertexAttribArray(aPos)
    gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0)

    var uRes = gl.getUniformLocation(prog, 'uRes')
    var uTime = gl.getUniformLocation(prog, 'uTime')

    gl.enable(gl.BLEND)
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE)   // 加色混合，叠在暗底上
    gl.clearColor(0, 0, 0, 0)

    var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    var scale = 0.5
    var elapsed = 0
    var last = 0
    var raf = 0
    var running = false

    function resize() {
      var w = Math.max(1, Math.round(window.innerWidth * scale))
      var h = Math.max(1, Math.round(window.innerHeight * scale))
      if (canvas.width === w && canvas.height === h) return
      canvas.width = w
      canvas.height = h
      gl.viewport(0, 0, w, h)
      gl.uniform2f(uRes, w, h)
    }

    function draw() {
      gl.uniform1f(uTime, elapsed)
      gl.clear(gl.COLOR_BUFFER_BIT)
      gl.drawArrays(gl.TRIANGLES, 0, 6)
    }

    function frame(now) {
      if (!running) return
      raf = requestAnimationFrame(frame)
      // 30fps 上限：极光是低速运动，30 帧肉眼无差，负载减半
      if (now - last < 33) return
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

    resize()
    window.addEventListener('resize', function () {
      resize()
      if (reduceMotion) draw()
    }, { passive: true })

    document.addEventListener('visibilitychange', function () {
      if (document.hidden) stop()
      else start()
    })

    if (reduceMotion) {
      elapsed = 12.0        // 取一帧好看的静态相位
      draw()
    } else {
      start()
    }

    // 标记已启用，便于 CSS 调层级/调试
    canvas.setAttribute('data-active', '1')
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }
})();
