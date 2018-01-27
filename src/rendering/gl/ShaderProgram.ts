import {vec2, vec3, vec4, mat4} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;

  unifView: WebGLUniformLocation;
  unifDims: WebGLUniformLocation;
  unifInvViewProj: WebGLUniformLocation;
  unifEyePos: WebGLUniformLocation;

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    // Raymarcher only draws a quad in screen space! No other attributes
    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");

    // TODO: add other attributes here
    this.unifView   = gl.getUniformLocation(this.prog, "u_View");
    this.unifDims   = gl.getUniformLocation(this.prog, "u_Dims");
    this.unifInvViewProj   = gl.getUniformLocation(this.prog, "u_InvViewProj");
    this.unifEyePos   = gl.getUniformLocation(this.prog, "u_EyePos");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  setDims(dims: vec2) {
    this.use();
    if (this.unifDims != -1) {
      gl.uniform2fv(this.unifDims, dims);
    }
  }

  setInvViewProj(invViewProj: mat4) {
    this.use();
    if (this.unifInvViewProj != -1) {
      gl.uniformMatrix4fv(this.unifInvViewProj, false, invViewProj);
    }
  }

  setEyePos(eyePos: vec3) {
    this.use();
    if (this.unifEyePos != -1) {
      gl.uniform3fv(this.unifEyePos, eyePos);
    }
  }

  // TODO: add functions to modify uniforms

  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);

  }
};

export default ShaderProgram;
