import {vec2, vec3} from 'gl-matrix';
import * as Stats from 'stats-js';
import * as DAT from 'dat-gui';
import Square from './geometry/Square';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';
import * as Howler from 'howler';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  // TODO: add any controls you want
};

let screenQuad: Square;

function main() {
  // Time-keeping variables
  let lastTime = 0;
  let accTime = 0;

  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // TODO: add any controls you need to the gui
  const gui = new DAT.GUI();
  // E.G. gui.add(controls, 'tesselations', 0, 8).step(1);

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');

  function setSize(width: number, height: number) {
    canvas.width = width;
    canvas.height = height;
  }

  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  screenQuad = new Square(vec3.fromValues(0, 0, 0));
  screenQuad.create();

  // Camera(position, target)
  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  gl.clearColor(0.0, 0.0, 0.0, 1);
  gl.disable(gl.DEPTH_TEST);

  const raymarchShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/screenspace-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/raymarch-frag.glsl')),
  ]);


  function getAnimTime(time: number) {
    return time < 5.545 ? 0.0 :
           time < 10.458 ? (time - 5.545) * 2.0 : 
           time < 15.361 ? (time - 10.458) / 0.6 :
           time < 20.259 ? (time - 15.361) * 2.0 : 
           time < 22.546 ? (time - 20.259) / 0.45 : 
           time < 25.158 ? (time - 22.546) / 0.366 : 
           time < 30.056 ? (time - 25.158) / 0.506 : 
           time < 34.954 ? (time - 30.056) / 0.506 : 
           time < 39.852 ? (time - 34.954) / 0.486 : 
           time < 42.163 ? (time - 39.852) / 0.471 : 
           time < 49.182 ? (time - 42.163) / 0.331 : 
           time < 51.057 ? (time - 49.182) / 0.486 : 
           time < 52.872 ? (time - 51.057) / 0.431 : 
           time < 54.481 ? (time - 52.872) / 0.376 : 
           time < 56.527 ? (time - 54.481) / 0.361 : 
           time < 58.362 ? (time - 56.527) / 0.371 : 
           time < 60.167 ? (time - 58.362) / 0.386 : 
           time < 61.756 ? (time - 60.167) / 0.386 : 
           time < 63.566 ? (time - 61.756) / 0.256 : 
           time < 67.206 ? (time - 63.566) / 0.371 : 
           time < 70.840 ? (time - 67.206) / 0.481 : 
           time < 74.480 ? (time - 70.840) / 0.366 : 
           time < 76.195 ? (time - 74.480) / 0.371 : 
           time < 79.945 ? (time - 76.195) / 0.256 : 
           time < 81.765 ? (time - 79.945) / 0.356 : 
           time < 83.580 ? (time - 81.765) / 0.356 : 
           time < 85.856 ? (time - 83.580) / 0.471 : 
           time < 87.219 ? (time - 85.856) / 0.256 : 
           time < 89.029 ? (time - 87.219) / 0.361 : 
           time < 90.849 ? (time - 89.029) / 0.361 : 
           time < 92.448 ? (time - 90.849) / 0.361 : 
           time < 99.999 ? (time - 92.448) / 0.917 :
                           ((time - 99.999) % 4.0) / 0.5;
  } 

  const sound = new Howler.Howl({
      src: ['built2scale.wav']
  });
  sound.play();

  lastTime = Date.now();

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();

    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // TODO: get / calculate relevant uniforms to send to shader here
    // TODO: send uniforms to shader
    raymarchShader.setDims(vec2.fromValues(canvas.width, canvas.height));
    raymarchShader.setEyePos(camera.controls.eye);
    raymarchShader.setInvViewProj(camera.invViewProjMatrix);
    let now = Date.now();
    accTime += now - lastTime;
    //accTime = (accTime > 11 * 1000) ? 0.0 : accTime;
    lastTime = now;
    raymarchShader.setTime(getAnimTime(accTime * 0.001));

    // March!
    raymarchShader.draw(screenQuad);

    // TODO: more shaders to layer / process the first one? (either via framebuffers or blending)

    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
