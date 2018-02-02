#version 300 es

precision highp float;

uniform vec2 u_Dims;
uniform vec3 u_EyePos;
uniform mat4 u_InvViewProj;
uniform float u_Time;
uniform float u_TimeAux1;
uniform float u_TimeAux2;
uniform float u_TimeAux3;
uniform float u_TimeAux4;
uniform float u_TimeAux5;
uniform int u_RenderMode;
uniform int u_BaseShape;

out vec4 out_Col;

// hard-code this
const float FAR_PLANE = 1000.0;
const float EPSILON = 0.001;
const float PI = 3.14159265;

// http://demofox.org/biasgain.html 
float bias(float t, float bias) {
  return (t / ((((1.0 / bias) - 2.0) * (1.0 - t)) + 1.0));
}

float gain(float t, float gain) {
  return (t < 0.5) ? (bias(t * 2.0, gain) * 0.5)
                   : (bias(t * 2.0 - 1.0, 1.0 - gain) * 0.5 + 0.5);
}

struct Ray {
    vec3 origin;
    vec3 dir;
};

struct Intersection {
    float t;
    vec3 normal;
    vec3 color;
};

// HOLE PIECE ======================================

const float HOLE_PIECE_SIDE = 3.0;
const float HOLE_PIECE_THICKNESS = 0.5;

float sdfFlatCube(vec3 p) {
    vec3 d = abs(p) - vec3(HOLE_PIECE_SIDE, HOLE_PIECE_SIDE, HOLE_PIECE_THICKNESS);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

//const vec3 HOLE_CYLINDER_PARAMS = vec3(0.0, 0.0, 1.0);
const float PEG_RADIUS = 1.0;

// modified from IQ's to make cylinder extend along Z axis instead of Y
float sdfHoleCylinder(vec3 p)
{
  //return length(p.xy-HOLE_CYLINDER_PARAMS.xy)-HOLE_CYLINDER_PARAMS.z;
  return length(p.xy) - PEG_RADIUS;
}

const float PEG_LENGTH = 4.0;

float sdfPegBoundary(vec3 p, float time) {
    vec3 d = abs(p) - vec3(PEG_RADIUS, PEG_RADIUS, (0.2 + 0.8 * time) * PEG_LENGTH);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfPeg(vec3 p, float time) {
    return max(sdfHoleCylinder(p), sdfPegBoundary(p, time));
}

// FlatCube - HoleCylinder
float sdfHolePiece(vec3 p) {
    return max(sdfFlatCube(p), -sdfHoleCylinder(p));
}

// SHAFT =================================
const float SHAFT_RADIUS = 1.0;

float sdfShaftCylinder(vec3 p)
{
  return length(p.xy) - SHAFT_RADIUS;
}

const float SHAFT_LENGTH = 8.0;

float sdfShaftBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(SHAFT_RADIUS, SHAFT_RADIUS, SHAFT_LENGTH);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfShaft(vec3 p) {
    return max(sdfShaftCylinder(p), sdfShaftBoundary(p));
}

 // ANIMATIONS ===============

const float NUM_CYCLES = 5.0;

const float LAUNCH_INTERVAL = 0.15;
const float LAUNCH_END = NUM_CYCLES - 0.082;
const float LAUNCH_START = LAUNCH_END - LAUNCH_INTERVAL;

const vec3 LAUNCH_MOVEMENT = vec3(0.0, 0.0, -10.25) * HOLE_PIECE_SIDE;

const vec3 BACK_MOVEMENT = vec3(0.0, 0.0, -1.9) * HOLE_PIECE_SIDE; 
const vec3 LEFT_TO_POSITION = vec3(2.0, 0.0, 0.0) * HOLE_PIECE_SIDE; 
const vec3 RIGHT_TO_POSITION = vec3(-2.0, 0.0, 0.0) * HOLE_PIECE_SIDE; 
const vec3 LEFT_BEFORE_FALL = BACK_MOVEMENT - LEFT_TO_POSITION * (NUM_CYCLES - 1.0); 
const vec3 RIGHT_BEFORE_FALL = BACK_MOVEMENT - RIGHT_TO_POSITION * (NUM_CYCLES - 1.0); 

const float BACK_START = LAUNCH_END;
const float BACK_END = BACK_START + 0.5;

const float FALL_ROT_START = LAUNCH_END + 0.5;
const float FALL_ROT_END = FALL_ROT_START + 0.8;

const float FALL_DISP_START = FALL_ROT_START + 0.05;
const float FALL_DISP_END = FALL_DISP_START + 0.8;

float animHolePiece(vec3 p, float time) {
    float rawFract = fract(time);
    float tFract = gain(rawFract, 0.91);
    float tWhole = time - rawFract;
    // compute second half of animation (falling off bridge)
    // moving back before falling
    float tBack = clamp(time, BACK_START, BACK_END) - BACK_START;
    tBack = tBack * 2.0;
    vec3 back = BACK_MOVEMENT * tBack;
    // falling off -- rotation
    float tFallRot = (clamp(time, FALL_ROT_START, FALL_ROT_END) - (FALL_ROT_START)) * 1.25;
    float fallAngle = smoothstep(0.05, 0.8, -cos(tFallRot * PI) * 0.5 + 0.5) * PI;
    // rotation about X
    float fallC = cos(fallAngle);
    float fallS = sin(fallAngle);
    mat3 fallRot = mat3(vec3(1.0, 0.0, 0.0),
                        vec3(0.0, fallC, fallS),
                        vec3(0.0, -fallS, fallC));
    // falling off -- translation
    float tFallDisp = (clamp(time, FALL_DISP_START, FALL_DISP_END) - (FALL_DISP_START)) * 1.25;
    vec3 fallDisp = vec3(0.0, -2.0, -1.5) * HOLE_PIECE_SIDE * vec3(0.0, pow(tFallDisp, 5.0), tFallDisp);
    // move on treadmill
    float tTreadmill = max(time, FALL_DISP_END) - FALL_DISP_END;
    vec3 treadmill = vec3(0.0, 0.0, 3.0) * HOLE_PIECE_SIDE * tTreadmill;
    // "clamp" so first half of animation stops
    if (time >= NUM_CYCLES) {
        tWhole = NUM_CYCLES;
        tFract = 0.0;
    }
    const vec3 toPivot = vec3(HOLE_PIECE_SIDE, -HOLE_PIECE_SIDE, 0.0);
    //vec3 toPosition = vec3(2.0 * HOLE_PIECE_SIDE, 0.0, 0.0) * tWhole;
    vec3 toPosition = LEFT_TO_POSITION * tWhole;
    //float angle = smoothstep(0.1, 0.88, cos(tFract * PI) * 0.5 + 0.5) * PI * 0.5;
    float angle = (1.0 - tFract) * PI * 0.5;
    float c = cos(angle);
    float s = sin(angle);
    // rotation about Z (first half)
    mat3 rot = mat3(vec3(c, s, 0.0),
                    vec3(-s, c, 0.0),
                    vec3(0.0, 0.0, 1.0));
    //rot = fallRot * rot;
    vec3 transP = toPivot + rot * (p - toPivot + toPosition);
    transP -= back;
    const vec3 toPivotFall = vec3(0.0, 1.0, 1.9) * HOLE_PIECE_SIDE - vec3(0.0, 0.0, 1.0) * HOLE_PIECE_THICKNESS;
    if (time > FALL_ROT_START) {
        transP = -toPivotFall + fallRot * (p + toPivotFall - fallDisp) - LEFT_BEFORE_FALL - treadmill;
        //transP = p - LEFT_BEFORE_FALL;
    }
    return sdfHolePiece(transP);
}

float animHolePieceRight(vec3 p, float time) {
    float rawFract = fract(time);
    float tFract = gain(rawFract, 0.91);
    float tWhole = time - rawFract;
    // moving back before falling
    float tBack = clamp(time, BACK_START, BACK_END) - BACK_START;
    tBack = tBack * 2.0;
    vec3 back = BACK_MOVEMENT * tBack;
    // falling off -- rotation
    //float tFallRot = clamp(time, FALL_ROT_START, FALL_ROT_END) - (FALL_ROT_START);
    float tFallRot = (clamp(time, FALL_ROT_START, FALL_ROT_END) - (FALL_ROT_START)) * 1.25;
    float fallAngle = smoothstep(0.05, 0.8, -cos(tFallRot * PI) * 0.5 + 0.5) * PI;
    // rotation about X
    float fallC = cos(fallAngle);
    float fallS = sin(fallAngle);
    mat3 fallRot = mat3(vec3(1.0, 0.0, 0.0),
                        vec3(0.0, fallC, fallS),
                        vec3(0.0, -fallS, fallC));
    // falling off -- translation
    float tFallDisp = (clamp(time, FALL_DISP_START, FALL_DISP_END) - (FALL_DISP_START)) * 1.25;
    //vec3 fallDisp = vec3(0.0, -2.0, -4.0) * HOLE_PIECE_SIDE * tFallDisp;
    vec3 fallDisp = vec3(0.0, -2.0, -1.5) * HOLE_PIECE_SIDE * vec3(0.0, pow(tFallDisp, 5.0), tFallDisp);
    // move on treadmill
    float tTreadmill = max(time, FALL_DISP_END) - FALL_DISP_END;
    vec3 treadmill = vec3(0.0, 0.0, 3.0) * HOLE_PIECE_SIDE * tTreadmill;
    // "clamp" so first half of animation stops
    if (tWhole >= NUM_CYCLES) {
        tWhole = NUM_CYCLES;
        tFract = 0.0;
    }
    const vec3 toPivot = vec3(-3.0, -3.0, 0.0);
    vec3 toPosition = vec3(-6.0, 0.0, 0.0) * tWhole;
    //float angle = -smoothstep(0.1, 0.88, cos(tFract * PI) * 0.5 + 0.5) * PI * 0.5;
    float angle = -(1.0 - tFract) * PI * 0.5;
    float c = cos(angle);
    float s = sin(angle);
    mat3 rot = mat3(vec3(c, s, 0.0),
                    vec3(-s, c, 0.0),
                    vec3(0.0, 0.0, 1.0));
    vec3 transP = toPivot + rot * (p - toPivot + toPosition);
    transP -= back;
    const vec3 toPivotFall = vec3(0.0, 1.0, 1.9) * HOLE_PIECE_SIDE - vec3(0.0, 0.0, -1.0 * HOLE_PIECE_THICKNESS);
    if (time > FALL_ROT_START) {
        transP = -toPivotFall + fallRot * (p + toPivotFall - fallDisp) - RIGHT_BEFORE_FALL - treadmill;
        //transP = p - RIGHT_BEFORE_FALL;
    }
    return sdfHolePiece(transP);
}

const vec3 PEG_BEFORE_FALL = LAUNCH_MOVEMENT + BACK_MOVEMENT;

const float PEG_RAISE_START = 0.0;
const float PEG_RAISE_END = 1.0;

const float PEG_GROW_START = PEG_RAISE_END;
const float PEG_GROW_END = PEG_GROW_START + 0.2;

float animPeg(vec3 p, float time) {
    // raising at start -- translation
    float tRaiseDisp = clamp(time, PEG_RAISE_START, PEG_RAISE_END) - PEG_RAISE_START;
    vec3 raiseDisp = vec3(0.0, -1.0 + tRaiseDisp, 0.0) * HOLE_PIECE_SIDE;
    // raising at start -- scale (pass to sdfPeg to scale bounding volume)
    float tRaiseScale = (clamp(time, PEG_GROW_START, PEG_GROW_END) - PEG_GROW_START) * 5.0;
    // initial launch
    float tLaunch = (clamp(time, LAUNCH_START, LAUNCH_END) - LAUNCH_START) / LAUNCH_INTERVAL;
    vec3 launch = LAUNCH_MOVEMENT * tLaunch;
    // moving back along with square piece
    float tBack = clamp(time, BACK_START, BACK_END) - BACK_START;
    tBack = tBack * 2.0;
    vec3 back = BACK_MOVEMENT * tBack;
    // falling off -- rotation
    //float tFallRot = clamp(time, FALL_ROT_START, FALL_ROT_END) - (FALL_ROT_START);
    float tFallRot = (clamp(time, FALL_ROT_START, FALL_ROT_END) - (FALL_ROT_START)) * 1.25;
    float fallAngle = smoothstep(0.05, 0.8, -cos(tFallRot * PI) * 0.5 + 0.5) * PI;
    // rotation matrix
    float fallC = cos(fallAngle);
    float fallS = sin(fallAngle);
    mat3 fallRot = mat3(vec3(1.0, 0.0, 0.0),
                        vec3(0.0, fallC, fallS),
                        vec3(0.0, -fallS, fallC));
    // falling off -- translation
    float tFallDisp = (clamp(time, FALL_DISP_START, FALL_DISP_END) - (FALL_DISP_START)) * 1.25;
    //vec3 fallDisp = vec3(0.0, -2.0, -4.0) * HOLE_PIECE_SIDE * tFallDisp;
    vec3 fallDisp = vec3(0.0, -2.0, -1.5) * HOLE_PIECE_SIDE * vec3(0.0, pow(tFallDisp, 5.0), tFallDisp);
    // move on treadmill
    float tTreadmill = max(time, FALL_DISP_END) - FALL_DISP_END;
    vec3 treadmill = vec3(0.0, 0.0, 3.0) * HOLE_PIECE_SIDE * tTreadmill;
    // combine movement
    vec3 transP = p - launch - back - raiseDisp;
    const vec3 toPivotFall = vec3(0.0, 3.0 * PEG_RADIUS, (10.25 + 1.9) * HOLE_PIECE_SIDE);// * PEG_RADIUS;
    if (time > FALL_ROT_START) {
        transP = -toPivotFall + fallRot * (p + toPivotFall - fallDisp) - PEG_BEFORE_FALL - treadmill;
        //transP -= tFallDisp;
    }
    return sdfPeg(transP, tRaiseScale);
}

const vec3 TO_PIVOT_FIRST_SHAFT = vec3(0.0, 0.0, -SHAFT_LENGTH);

const float SHAFT_ROT_START = 1.0;
const float SHAFT_ROT_END = SHAFT_ROT_START + 1.0;

float sdfJoint(vec3 p) {
    return length(p) - 2.0 * SHAFT_RADIUS;
}

const vec3 PANEL_DIMS = vec3(3.0 * HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_THICKNESS);

float sdfPanel(vec3 p) {
    vec3 d = abs(p) - PANEL_DIMS;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float animFirstShaft(vec3 p, float time) {
    float tRot = (clamp(time, LAUNCH_START, LAUNCH_END) - LAUNCH_START) / LAUNCH_INTERVAL;
    tRot = (time > LAUNCH_END) ? (1.0 - 2.0 * clamp(time - LAUNCH_END, 0.0, 0.5)) : tRot;
    //float tRot = clamp(time, SHAFT_ROT_START, SHAFT_ROT_END) - SHAFT_ROT_START;
    float rotAngle = 0.5 + cos(tRot * PI) * 0.5;
    rotAngle *= -PI * 0.33333;
    // rotation matrix (about X)
    float c = cos(rotAngle);
    float s = sin(rotAngle);
    mat3 rot = mat3(vec3(1.0, 0.0, 0.0),
                    vec3(0.0, c, s),
                    vec3(0.0, -s, c));
    vec3 transP = -TO_PIVOT_FIRST_SHAFT + rot * (p + TO_PIVOT_FIRST_SHAFT);
    return sdfShaft(transP);
}

const vec3 PANEL_START = vec3(0.0, 0.0, -1.0 * SHAFT_LENGTH);

float animSecondShaft(vec3 p, float time) {
    float tRot = (clamp(time, LAUNCH_START, LAUNCH_END) - LAUNCH_START) / LAUNCH_INTERVAL;
    tRot = (time > LAUNCH_END) ? (1.0 - 2.0 * clamp(time - LAUNCH_END, 0.0, 0.5)) : tRot;
    //float tRot = clamp(time, SHAFT_ROT_START, SHAFT_ROT_END) - SHAFT_ROT_START;
    float rotAngle = 0.5 - cos(tRot * PI) * 0.5;
    rotAngle += 5.0;
    rotAngle *= -PI * 0.33333;
    // rotation matrix (about X)
    float c = cos(rotAngle);
    float s = sin(rotAngle);
    mat3 rot = mat3(vec3(1.0, 0.0, 0.0),
                    vec3(0.0, c, s),
                    vec3(0.0, -s, c));
    // move joint
    float jointAngle = 0.5 + cos(tRot * PI) * 0.5;
    jointAngle *= PI * 0.33333;
    float jointC = cos(jointAngle);
    float jointS = sin(jointAngle);
    // stands for first shaft end
    const vec3 fse = vec3(0.0, 0.0, -2.0 * SHAFT_LENGTH);
    vec3 secondShaftStart = vec3(fse.x, jointC * fse.y + -jointS * fse.z, jointS * fse.y + jointC * fse.z);
    vec3 transP = -TO_PIVOT_FIRST_SHAFT + rot * (p + TO_PIVOT_FIRST_SHAFT - secondShaftStart);
    // combine shaft and joint
    float shaft = sdfShaft(transP);
    vec3 transJoint = secondShaftStart + vec3(0.0, 0.0, SHAFT_LENGTH);
    float joint = sdfJoint(p - transJoint);
    // ...and panel
    //vec3 transPanel = -TO_PIVOT_FIRST_SHAFT + rot * (PANEL_START + TO_PIVOT_FIRST_SHAFT - secondShaftStart);
    vec3 transPanel = vec3(0.0, 0.0, (1.0 - 4.0 * cos(jointAngle)) * SHAFT_LENGTH);
    float panel = sdfPanel(p - transPanel);
    return min(min(shaft, joint), panel);
}

// BACKGROUND ================

float sdfBgCube(vec3 p) {
    vec3 d = abs(p) - vec3(HOLE_PIECE_SIDE * 0.95);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

const vec3 REP_Y_OFFSET = vec3(0.0, HOLE_PIECE_SIDE, 0.0);

float repBgCube(vec3 p) {
    vec3 c = vec3(2.0 * HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_SIDE);
    vec3 q = mod(p - REP_Y_OFFSET, c) - 0.5 * c;
    if (u_BaseShape == 0) {
        return sdfBgCube(q);
    }
    else {
        return length(q) - (HOLE_PIECE_SIDE * 0.99);
    }
}

float sdfBridgeBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(10.0 * HOLE_PIECE_SIDE, HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_SIDE);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfBridge(vec3 p) {
    return max(repBgCube(p), sdfBridgeBoundary(p));
}

float sdfBridgeRemover(vec3 p) {
    vec3 d = abs(p) - vec3(11.0 * HOLE_PIECE_SIDE, 1.5 * HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_SIDE);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

const vec3 PEG_SUPPORT_DIMS = vec3(HOLE_PIECE_SIDE, HOLE_PIECE_SIDE - PEG_RADIUS, HOLE_PIECE_SIDE);

float sdfPegSupportHole(vec3 p) {
    vec3 d = abs(p - vec3(1.0, 1.0, 0.0) * HOLE_PIECE_SIDE) - PEG_SUPPORT_DIMS;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfPegBridge(vec3 p) {
    return max(sdfBridge(p), -sdfPegSupportHole(p));
}

float sdfPegSupportRemover(vec3 p) {
    vec3 d = abs(p - vec3(1.0, -1.0, 0.0) * HOLE_PIECE_SIDE) - 2.0 * PEG_SUPPORT_DIMS;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float animPegSupport(vec3 p, float time) {
    float t = (time < LAUNCH_END) ? clamp(time, 0.0, 1.0) :
                                    1.0 - 3.333 * clamp(time - LAUNCH_END, 0.0, 0.3);
    return max(sdfPegSupportHole(p - vec3(0.0, -1.0 + t, 0.0) * HOLE_PIECE_SIDE), -sdfPegSupportRemover(p));
}

const float BG_LENGTH = 20.0;

float sdfBgBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(12.0, 5.0, BG_LENGTH) * HOLE_PIECE_SIDE;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfBoundedBgCubes(vec3 p) {
    return max(repBgCube(p), sdfBgBoundary(p));
}

float sdfFirstLevelBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(3.0, 4.0, BG_LENGTH) * HOLE_PIECE_SIDE;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfSecondLevelBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(5.0, 3.0, BG_LENGTH) * HOLE_PIECE_SIDE;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfThirdLevelBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(7.0, 2.0, BG_LENGTH) * HOLE_PIECE_SIDE;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfFourthLevelBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(9.0, 1.0, BG_LENGTH) * HOLE_PIECE_SIDE;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

const vec3 BRIDGE_TRANSLATION = vec3(-1.0, -2.0, 0.25) * HOLE_PIECE_SIDE;
const vec3 BRIDGE_TOP_REMOVER_TRANSLATION = BRIDGE_TRANSLATION + vec3(1.0, 4.0, 0.0) * HOLE_PIECE_SIDE;//vec3(-1.0, 0.0, 0.25) * HOLE_PIECE_SIDE;

float sdfCarvedBg(vec3 p) {
    float uncarved = sdfBoundedBgCubes(p);
    float first = sdfFirstLevelBoundary(p - vec3(1.0, 1.0, 0.0) * HOLE_PIECE_SIDE);
    float second = sdfSecondLevelBoundary(p - vec3(1.0, 2.0, 0.0) * HOLE_PIECE_SIDE);
    float third = sdfThirdLevelBoundary(p - vec3(1.0, 3.0, 0.0) * HOLE_PIECE_SIDE);
    float fourth = sdfFourthLevelBoundary(p - vec3(1.0, 4.0, 0.0) * HOLE_PIECE_SIDE);
    float bridgeRemover = sdfBridgeRemover(p - BRIDGE_TOP_REMOVER_TRANSLATION);
    return max(max(max(max(max(uncarved, -first), -second), -third), -fourth), -bridgeRemover);
}

const vec3 LEFT_TRANSLATION = vec3((NUM_CYCLES - 1.0) * 6.0, 0.0, 0.0);
const vec3 RIGHT_TRANSLATION = -LEFT_TRANSLATION + vec3(0.0, 0.0, 2.0 * HOLE_PIECE_THICKNESS);
const vec3 PEG_BRIDGE_TRANSLATION = vec3(-1.0, -2.0, 10.25) * HOLE_PIECE_SIDE;
const vec3 PEG_TRANSLATION = vec3(0.0, 0.0, 10.25) * HOLE_PIECE_SIDE;
const vec3 FIRST_SHAFT_TRANSLATION = vec3(0.0, 2.0, 18.0) * HOLE_PIECE_SIDE;

// b = box dimensions
// r = radius of round parts
float udfRoundBox(vec3 p, vec3 b, float r, inout vec3 color)
{
  float firstShaft = animFirstShaft(p - FIRST_SHAFT_TRANSLATION, u_TimeAux4);
  float secondShaft = animSecondShaft(p - FIRST_SHAFT_TRANSLATION, u_TimeAux4);
  // test carved background
  float carved = sdfCarvedBg(p - BRIDGE_TRANSLATION);
  // test "bridge"
  float bridge = sdfBridge(p - BRIDGE_TRANSLATION);
  // test peg "bridge"
  float pegBridge = sdfPegBridge(p - PEG_BRIDGE_TRANSLATION);
  // test peg support
  //float pegSupport = sdfPegSupportHole(p - PEG_BRIDGE_TRANSLATION);
  float pegSupport = animPegSupport(p - PEG_BRIDGE_TRANSLATION, u_Time);
  // test left piece
  float left = animHolePiece(p - LEFT_TRANSLATION, u_TimeAux3);
  // test right piece
  float right = animHolePieceRight(p - RIGHT_TRANSLATION, u_TimeAux3);
  // test peg
  float peg = animPeg(p - PEG_TRANSLATION, u_TimeAux3);
  float piece0 = min(left, min(right, peg));
  // second piece
  float left1 = animHolePiece(p - LEFT_TRANSLATION, u_TimeAux1);
  float right1 = animHolePieceRight(p - RIGHT_TRANSLATION, u_TimeAux1);
  float peg1 = animPeg(p - PEG_TRANSLATION, u_TimeAux1);
  float piece1 = min(left1, min(right1, peg1));
  // third piece
  float left2 = animHolePiece(p - LEFT_TRANSLATION, u_TimeAux2);
  float right2 = animHolePieceRight(p - RIGHT_TRANSLATION, u_TimeAux2);
  float peg2 = animPeg(p - PEG_TRANSLATION, u_TimeAux2);
  float piece2 = min(left2, min(right2, peg2));
  // combine all
  float whiteParts = min(piece2, min(piece1, min(piece0, min(firstShaft, secondShaft))));
  //float partial = min(peg, min(pegSupport, min(pegBridge, min(carved, min(bridge, min(left, right))))));
  float scene = min(whiteParts, min(pegSupport, min(pegBridge, min(carved, bridge))));
  //float scene = min(secondShaft, min(partial, firstShaft));
  color = (scene == whiteParts) ? vec3(0.9) : vec3(0.1, 0.7, 0.1);
  return scene;
}

float sdfScene(vec3 p) {
    vec3 dummy;
    return udfRoundBox(p, vec3(0.0), 0.0, dummy);
}

const float AO_DELTA = 0.5;//0.66 * HOLE_PIECE_SIDE;
const float AO_K = 0.1;

float getAO(vec3 p, vec3 n) {
    float decay = 0.5;
    float aoSum = 0.0;
    vec3 samplePt;
    for (float i = 1.0; i < 5.1; i += 1.0) {
        samplePt = p + n * i * AO_DELTA;
        aoSum += decay * (i * AO_DELTA - sdfScene(samplePt)) / AO_DELTA;
        decay *= 0.5; 
    }
    return clamp(1.0 - AO_K * aoSum, 0.0, 1.0);
}

const float THICKNESS_DELTA = 4.9;
const float THICKNESS_K = 0.7;

float getThickness(vec3 p, vec3 n) {
    float decay = 0.5;
    float aoSum = 0.0;
    vec3 samplePt;
    for (float i = 1.0; i < 5.1; i += 1.0) {
        samplePt = p - n * i * THICKNESS_DELTA;
        // if still inside, add
        //aoSum += decay * ((sdfScene(samplePt) < 0.0) ? 2.0 : 0.0);
        aoSum += decay * (i * THICKNESS_DELTA - sdfScene(samplePt)) / THICKNESS_DELTA;
        decay *= 0.5; 
    }
    return clamp(THICKNESS_K * aoSum, 0.0, THICKNESS_K);
}


float getLambert(vec3 p, vec3 n) {
vec3 LIGHT_POS = vec3(0.0, 0.0 + 5.0 * (cos(u_TimeAux5) * 0.5 + 0.5), -15.0) * HOLE_PIECE_SIDE;
    vec3 lightDir = normalize(p - LIGHT_POS);
    return 0.3 + 0.7 * clamp(dot(lightDir, n), 0.0, 1.0);
}

float getSSS(vec3 p, vec3 vNormal) {
vec3 LIGHT_POS = vec3(0.0, 0.0 + 5.0 * (cos(u_TimeAux5) * 0.5 + 0.5), -15.0) * HOLE_PIECE_SIDE;
    vec3 vLight = normalize(LIGHT_POS - p);
    vec3 vEye = normalize(u_EyePos - p);
    const float fLTAmbient = 0.1;
    const float iLTPower = 2.0;
    const float fLTDistortion = 0.01;
    const float fLTScale = 1.3;
    float dist = distance(LIGHT_POS, p) * 0.03;
    float fLightAttenuation = min(1.0, pow(dist, -2.0));
    float fLTThickness = getThickness(p, vNormal);
    
    vec3 vLTLight = vLight + vNormal * fLTDistortion;
    float fLTDot = pow(clamp(dot(vEye, -vLTLight), 0.0, 1.0), iLTPower) * fLTScale;
    return fLightAttenuation * (fLTDot + fLTAmbient) * fLTThickness;
}

const float MAX_DIST = 1000.0;

Intersection sphereMarch(in Ray r) {
    float t = 0.0;
    Intersection isx;
    isx.t = -1.0;
    isx.normal = vec3(1.0, -1.0, -1.0);
    vec3 color;
    for (int i = 0; i < 200; i++) {
        vec3 p = r.origin + t * r.dir;
        vec3 dims = vec3(1.0, 1.0, 1.0 + (cos(u_Time * 0.001) * 0.5 + 0.5));
        dims.xy = dims.zz;
        dims.z = 1.0;
        dims.xy = vec2(0.0);
        float radius = 0.3;
        float dist = udfRoundBox(p, dims, radius, color);
        if (dist < EPSILON * 10.0) {
            isx.t = t;
            isx.color = color;
            float distXL = udfRoundBox(p - vec3(EPSILON, 0.0, 0.0), dims, radius, color);
            float distXH = udfRoundBox(p + vec3(EPSILON, 0.0, 0.0), dims, radius, color);
            float distYL = udfRoundBox(p - vec3(0.0, EPSILON, 0.0), dims, radius, color);
            float distYH = udfRoundBox(p + vec3(0.0, EPSILON, 0.0), dims, radius, color);
            float distZL = udfRoundBox(p - vec3(0.0, 0.0, EPSILON), dims, radius, color);
            float distZH = udfRoundBox(p + vec3(0.0, 0.0, EPSILON), dims, radius, color);
            isx.normal = normalize(vec3(distXL - distXH, distYL - distYH, distZL - distZH));
            break;
        }
        t += dist;
        if (t >= MAX_DIST) {
            isx.t = MAX_DIST;
            isx.normal = vec3(0.0);
            break;
        }
    }
    return isx;
}

vec3 getBG(in Ray ray) {
    float t = (max(u_TimeAux4, LAUNCH_START) - LAUNCH_START) / LAUNCH_INTERVAL;
    //t = (t > 0.7) ? 0.0 : smoothstep(0.3, 0.71, t);
    t = 1.0 - smoothstep(0.0, 0.6, abs(0.8 - t));
    vec3 baseColor = ray.dir * 0.5 + vec3(0.5);
    const vec3 altColor = vec3(0.0, 0.7, 0.0);//vec3(1.0) - baseColor;
    return mix(baseColor, altColor, t);
}


void main() {
	// TODO: make a Raymarcher!
    vec2 ndc = (gl_FragCoord.xy / u_Dims) * 2.0 - vec2(1.0);
    vec4 worldTarget = u_InvViewProj * vec4(ndc, 1.0, 1.0) * FAR_PLANE;
    Ray ray;
    ray.origin = u_EyePos;
    ray.dir = normalize(worldTarget.xyz - u_EyePos);
	out_Col = vec4(1.0, 0.5, 0.0, 1.0);
    out_Col.xyz = ray.dir * 0.5 + vec3(0.5);
    out_Col.xyz = vec3(0.1);
    Intersection isx = sphereMarch(ray);
    vec3 isxPoint = ray.origin + isx.t * ray.dir;
    float ao = getAO(isxPoint, isx.normal);
    float lambert = getLambert(isxPoint, isx.normal);
    float sss = getSSS(isxPoint, isx.normal);
    //out_Col.xyz = isx.normal * 0.5 + vec3(0.5);
    //out_Col.xyz = vec3(0.05, 0.7, 0.1);
    out_Col.xyz = isx.color;
    if (u_RenderMode == 0) {
        out_Col.xyz *= (lambert + sss * 2.0);
        out_Col.xyz *= ao;
    }
    else if (u_RenderMode == 1) {
        out_Col.xyz *= ao;
    }
    else if (u_RenderMode == 2) {
        out_Col.xyz *= (sss * 2.0);
    }
    else {
        out_Col.xyz *= (lambert);
    }
    out_Col.xyz = (isx.t == -1.0 || isx.t == MAX_DIST) ? getBG(ray) : out_Col.xyz;
    //out_Col.xyz *= (lambert);
    //out_Col.xyz = vec3(sss);
    //out_Col.xyz = vec3(getSSS(isxPoint, isx.normal));
    //out_Col.xyz = vec3(getThickness(isxPoint, isx.normal));
    //out_Col.xyz *= ao;
}
