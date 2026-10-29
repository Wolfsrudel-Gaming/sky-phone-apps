// Draws the live GTA picture into a WebGL canvas.
//
// FiveM's browser replaces a texture with the game's back buffer when the
// texture's wrap mode is set in one specific sequence (the same mechanism the
// official screenshot-basic resource uses). The picture contains the game world
// only; NUI pages such as the phone are not part of it.

const VERTEX_SHADER = `
  attribute vec2 a_position;
  attribute vec2 a_texcoord;
  varying vec2 v_texcoord;
  void main() {
    gl_Position = vec4(a_position, 0.0, 1.0);
    v_texcoord = a_texcoord;
  }
`

const FRAGMENT_SHADER = `
  precision mediump float;
  varying vec2 v_texcoord;
  uniform sampler2D u_texture;
  void main() {
    gl_FragColor = texture2D(u_texture, v_texcoord);
  }
`

/** Seed colour of the texture. Still visible after a render = no game picture. */
const SEED_PIXEL = [255, 0, 255, 255]

export interface GameView {
  readonly canvas: HTMLCanvasElement
  /**
   * Sets the output size. The game picture (sourceWidth x sourceHeight, by default
   * the screen) is centre-cropped to that aspect ratio.
   */
  resize(width: number, height: number, sourceWidth?: number, sourceHeight?: number): void
  render(): void
  /** Renders once and checks whether FiveM delivered the game picture. */
  isLive(): boolean
  dispose(): void
}

function compile(gl: WebGLRenderingContext, type: number, source: string): WebGLShader {
  const shader = gl.createShader(type)
  if (!shader) throw new Error('game_view_unavailable')
  gl.shaderSource(shader, source)
  gl.compileShader(shader)
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(shader) ?? 'game_view_unavailable')
  }
  return shader
}

/** Texture coordinates that crop the source picture to the target aspect ratio. */
export function cropCoordinates(
  sourceWidth: number,
  sourceHeight: number,
  targetWidth: number,
  targetHeight: number,
): Float32Array {
  const sourceAspect = sourceWidth / sourceHeight
  const targetAspect = targetWidth / targetHeight
  let left = 0
  let right = 1
  let bottom = 0
  let top = 1
  if (sourceAspect > targetAspect) {
    const visible = targetAspect / sourceAspect
    left = (1 - visible) / 2
    right = 1 - left
  } else if (sourceAspect < targetAspect) {
    const visible = sourceAspect / targetAspect
    bottom = (1 - visible) / 2
    top = 1 - bottom
  }
  // The game texture arrives bottom-up, so texture row 0 belongs at the bottom.
  return new Float32Array([left, bottom, right, bottom, left, top, right, top])
}

export function createGameView(canvas: HTMLCanvasElement = document.createElement('canvas')): GameView {
  const gl = canvas.getContext('webgl', {
    alpha: false,
    antialias: false,
    depth: false,
    stencil: false,
    desynchronized: true,
    // Needed so captureStream, thumbnails and the liveness check can read the last frame.
    preserveDrawingBuffer: true,
  })
  if (!gl) throw new Error('game_view_unavailable')

  const program = gl.createProgram()
  if (!program) throw new Error('game_view_unavailable')
  gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, VERTEX_SHADER))
  gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, FRAGMENT_SHADER))
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw new Error(gl.getProgramInfoLog(program) ?? 'game_view_unavailable')
  }
  gl.useProgram(program)

  const positionBuffer = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer)
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW)
  const positionLocation = gl.getAttribLocation(program, 'a_position')
  gl.enableVertexAttribArray(positionLocation)
  gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0)

  const texcoordBuffer = gl.createBuffer()
  const texcoordLocation = gl.getAttribLocation(program, 'a_texcoord')

  const texture = gl.createTexture()
  gl.bindTexture(gl.TEXTURE_2D, texture)
  gl.texImage2D(
    gl.TEXTURE_2D,
    0,
    gl.RGBA,
    1,
    1,
    0,
    gl.RGBA,
    gl.UNSIGNED_BYTE,
    new Uint8Array(SEED_PIXEL),
  )
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  // The sequence FiveM watches for. Each call matters; none of them is redundant.
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.uniform1i(gl.getUniformLocation(program, 'u_texture'), 0)

  let disposed = false

  const view: GameView = {
    canvas,
    resize(width, height, sourceWidth = window.screen.width, sourceHeight = window.screen.height) {
      canvas.width = Math.max(1, Math.round(width))
      canvas.height = Math.max(1, Math.round(height))
      gl.viewport(0, 0, canvas.width, canvas.height)
      gl.bindBuffer(gl.ARRAY_BUFFER, texcoordBuffer)
      gl.bufferData(
        gl.ARRAY_BUFFER,
        cropCoordinates(sourceWidth || 16, sourceHeight || 9, canvas.width, canvas.height),
        gl.STATIC_DRAW,
      )
      gl.enableVertexAttribArray(texcoordLocation)
      gl.vertexAttribPointer(texcoordLocation, 2, gl.FLOAT, false, 0, 0)
    },
    render() {
      if (disposed || gl.isContextLost()) return
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    },
    isLive() {
      view.render()
      const pixel = new Uint8Array(4)
      gl.readPixels(
        Math.floor(canvas.width / 2),
        Math.floor(canvas.height / 2),
        1,
        1,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        pixel,
      )
      return !SEED_PIXEL.every((value, index) => Math.abs(pixel[index] - value) < 3)
    },
    dispose() {
      if (disposed) return
      disposed = true
      gl.deleteTexture(texture)
      gl.deleteBuffer(positionBuffer)
      gl.deleteBuffer(texcoordBuffer)
      gl.deleteProgram(program)
      gl.getExtension('WEBGL_lose_context')?.loseContext()
    },
  }
  view.resize(canvas.width || 1, canvas.height || 1)
  return view
}
