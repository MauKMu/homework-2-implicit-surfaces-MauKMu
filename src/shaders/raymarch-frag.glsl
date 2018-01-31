#version 300 es

precision highp float;

uniform vec2 u_Dims;
uniform vec3 u_EyePos;
uniform mat4 u_InvViewProj;
uniform float u_Time;

out vec4 out_Col;

// hard-code this
const float FAR_PLANE = 1000.0;
const float EPSILON = 0.001;
const float PI = 3.14159265;

struct Ray {
    vec3 origin;
    vec3 dir;
};

float jankySqr(in Ray ray) {
    if (abs(ray.dir.z) < EPSILON) {
        return -1.0;
    }
    vec3 nor = vec3(0.0, 0.0, 1.0);
    //float t = dot(nor, -ray.origin) / dot(nor, ray.dir);
    float t = -ray.origin.z / ray.dir.z;
    vec3 p = ray.origin + t * ray.dir;
    if (abs(p.x) <= 0.1 && abs(p.y) <= 0.1) {
        return t;
    }
    return -1.0;
}

struct Intersection {
    float t;
    vec3 normal;
};

float sdfCube(vec3 p) {
    vec3 d = abs(p) - vec3(0.5);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
    // dimensions = 1
    vec3 diff = abs(p) - vec3(0.5);
    float maxDiff = max(max(diff.x, diff.y), diff.z);
    vec3 onlyPosDiff = max(diff, 0.0);
    return (maxDiff <= 0.0) ? maxDiff : min(min(onlyPosDiff.x, onlyPosDiff.y), onlyPosDiff.z);
}

// t.x = outer radius
// t.y = inner radius
float sdfTorus(vec3 p, vec2 t)
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float length8(vec2 v) {
    float sum = dot(vec2(1.0), pow(v, vec2(8.0)));
    return pow(sum, 0.125);
}

float length8(vec3 v) {
    float sum = dot(vec3(1.0), pow(v, vec3(8.0)));
    return pow(sum, 0.125);
}

float sdfTorus82( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length8(q)-t.y;
}

// c.xy = coordinates of center
// c.z  = radius of cylinder's cross-section
// modified from IQ's to make cylinder extend along Z axis instead of Y
float sdfCylinder(vec3 p, vec3 c)
{
  return length(p.xy-c.xy)-c.z;
}

float sdfTriPrism( vec3 p, vec2 h )
{
    vec3 q = abs(p);
    return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

float opCheapBend( vec3 P )
{
    mat3 rot = mat3(0.0);
    rot[0] = vec3(0, 0, -1);
    rot[1] = vec3(0, 1, 0);
    rot[2] = vec3(1, 0, 0);
    vec3 p = rot * P;
    float c = cos(20.0*p.y);
    float s = sin(20.0*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xz,p.y);
    return sdfTriPrism(q, vec2(2.0, 4.0));
}

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

float sdfPegBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(PEG_RADIUS, PEG_RADIUS, PEG_LENGTH);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfPeg(vec3 p) {
    return max(sdfHoleCylinder(p), sdfPegBoundary(p));
}

// FlatCube - HoleCylinder
float sdfHolePiece(vec3 p) {
    return max(sdfFlatCube(p), -sdfHoleCylinder(p));
}

const float NUM_CYCLES = 5.0;

const float LAUNCH_INTERVAL = 0.07;
const float LAUNCH_END = NUM_CYCLES - 0.22;
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
const float FALL_ROT_END = FALL_ROT_START + 1.0;

const float FALL_DISP_START = FALL_ROT_START + 0.2;
const float FALL_DISP_END = FALL_DISP_START + 1.0;

float animHolePiece(vec3 p, float time) {
    float tFract = fract(time);
    float tWhole = time - tFract;
    // compute second half of animation (falling off bridge)
    // moving back before falling
    float tBack = clamp(time, BACK_START, BACK_END) - BACK_START;
    tBack = tBack * 2.0;
    vec3 back = BACK_MOVEMENT * tBack;
    // fall off while rotating
    // when first half ends, total translation is toPosition * NUM_CYCLES
    // add this to back * 1 to get total translation prior to falling off
    /* OBSOLETE
    const vec3 transBeforeFall = LEFT_TO_POSITION * NUM_CYCLES + BACK_MOVEMENT;
    const vec3 toPivotFall = vec3(0.0, -1.0, 0.0) * HOLE_PIECE_SIDE;
    const vec3 blah = -toPivotFall + transBeforeFall;
    */
    // can use this to move back to origin, then to new pivot
    // falling off -- rotation
    float tFallRot = clamp(time, FALL_ROT_START, FALL_ROT_END) - (FALL_ROT_START);
    float fallAngle = smoothstep(0.05, 0.8, -cos(tFallRot * PI) * 0.5 + 0.5) * PI;
    // rotation about X
    float fallC = cos(fallAngle);
    float fallS = sin(fallAngle);
    mat3 fallRot = mat3(vec3(1.0, 0.0, 0.0),
                        vec3(0.0, fallC, fallS),
                        vec3(0.0, -fallS, fallC));
    // falling off -- translation
    float tFallDisp = clamp(time, FALL_DISP_START, FALL_DISP_END) - (FALL_DISP_START);
    vec3 fallDisp = vec3(0.0, -2.0, -4.0) * HOLE_PIECE_SIDE * tFallDisp;
    // move on treadmill
    float tTreadmill = max(time, FALL_DISP_END) - FALL_DISP_END;
    vec3 treadmill = vec3(0.0, 0.0, 3.0) * HOLE_PIECE_SIDE * tTreadmill;
    // "clamp" so first half of animation stops
    if (tWhole >= NUM_CYCLES) {
        tWhole = NUM_CYCLES;
        tFract = 0.0;
    }
    const vec3 toPivot = vec3(HOLE_PIECE_SIDE, -HOLE_PIECE_SIDE, 0.0);
    //vec3 toPosition = vec3(2.0 * HOLE_PIECE_SIDE, 0.0, 0.0) * tWhole;
    vec3 toPosition = LEFT_TO_POSITION * tWhole;
    float angle = smoothstep(0.1, 0.88, cos(tFract * PI) * 0.5 + 0.5) * PI * 0.5;
    float c = cos(angle);
    float s = sin(angle);
    // rotation about Z (first half)
    mat3 rot = mat3(vec3(c, s, 0.0),
                    vec3(-s, c, 0.0),
                    vec3(0.0, 0.0, 1.0));
    //rot = fallRot * rot;
    vec3 transP = toPivot + rot * (p - toPivot + toPosition);
    transP -= back;
    const vec3 toPivotFall = vec3(0.0, 1.0, 1.9) * HOLE_PIECE_SIDE - vec3(0.0, 0.0, 0.5) * HOLE_PIECE_THICKNESS;
    if (time > FALL_ROT_START) {
        transP = -toPivotFall + fallRot * (p + toPivotFall - fallDisp) - LEFT_BEFORE_FALL - treadmill;
        //transP = p - LEFT_BEFORE_FALL;
    }
    return sdfHolePiece(transP);
}

float animHolePieceRight(vec3 p, float time) {
    float tFract = fract(time);
    float tWhole = time - tFract;
    // moving back before falling
    float tBack = clamp(time, BACK_START, BACK_END) - BACK_START;
    tBack = tBack * 2.0;
    vec3 back = BACK_MOVEMENT * tBack;
    // falling off -- rotation
    float tFallRot = clamp(time, FALL_ROT_START, FALL_ROT_END) - (FALL_ROT_START);
    float fallAngle = smoothstep(0.05, 0.8, -cos(tFallRot * PI) * 0.5 + 0.5) * PI;
    // rotation about X
    float fallC = cos(fallAngle);
    float fallS = sin(fallAngle);
    mat3 fallRot = mat3(vec3(1.0, 0.0, 0.0),
                        vec3(0.0, fallC, fallS),
                        vec3(0.0, -fallS, fallC));
    // falling off -- translation
    float tFallDisp = clamp(time, FALL_DISP_START, FALL_DISP_END) - (FALL_DISP_START);
    vec3 fallDisp = vec3(0.0, -2.0, -4.0) * HOLE_PIECE_SIDE * tFallDisp;
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
    float angle = -smoothstep(0.1, 0.88, cos(tFract * PI) * 0.5 + 0.5) * PI * 0.5;
    float c = cos(angle);
    float s = sin(angle);
    mat3 rot = mat3(vec3(c, s, 0.0),
                    vec3(-s, c, 0.0),
                    vec3(0.0, 0.0, 1.0));
    vec3 transP = toPivot + rot * (p - toPivot + toPosition);
    transP -= back;
    const vec3 toPivotFall = vec3(0.0, 1.0, 1.9) * HOLE_PIECE_SIDE - vec3(0.0, 0.0, -0.5 * HOLE_PIECE_THICKNESS);
    if (time > FALL_ROT_START) {
        transP = -toPivotFall + fallRot * (p + toPivotFall - fallDisp) - RIGHT_BEFORE_FALL - treadmill;
        //transP = p - RIGHT_BEFORE_FALL;
    }
    return sdfHolePiece(transP);
}

const vec3 PEG_BEFORE_FALL = LAUNCH_MOVEMENT + BACK_MOVEMENT;

float animPeg(vec3 p, float time) {
    // initial launch
    float tLaunch = (clamp(time, LAUNCH_START, LAUNCH_END) - LAUNCH_START) / LAUNCH_INTERVAL;
    vec3 launch = LAUNCH_MOVEMENT * tLaunch;
    // moving back along with square piece
    float tBack = clamp(time, BACK_START, BACK_END) - BACK_START;
    tBack = tBack * 2.0;
    vec3 back = BACK_MOVEMENT * tBack;
    // falling off -- rotation
    float tFallRot = clamp(time, FALL_ROT_START, FALL_ROT_END) - (FALL_ROT_START);
    float fallAngle = smoothstep(0.05, 0.8, -cos(tFallRot * PI) * 0.5 + 0.5) * PI;
    // rotation matrix
    float fallC = cos(fallAngle);
    float fallS = sin(fallAngle);
    mat3 fallRot = mat3(vec3(1.0, 0.0, 0.0),
                        vec3(0.0, fallC, fallS),
                        vec3(0.0, -fallS, fallC));
    // falling off -- translation
    float tFallDisp = clamp(time, FALL_DISP_START, FALL_DISP_END) - (FALL_DISP_START);
    vec3 fallDisp = vec3(0.0, -2.0, -4.0) * HOLE_PIECE_SIDE * tFallDisp;
    // move on treadmill
    float tTreadmill = max(time, FALL_DISP_END) - FALL_DISP_END;
    vec3 treadmill = vec3(0.0, 0.0, 3.0) * HOLE_PIECE_SIDE * tTreadmill;
    // combine movement
    vec3 transP = p - launch - back;
    const vec3 toPivotFall = vec3(0.0, 3.0 * PEG_RADIUS, (10.25 + 1.9) * HOLE_PIECE_SIDE);// * PEG_RADIUS;
    if (time > FALL_ROT_START) {
        transP = -toPivotFall + fallRot * (p + toPivotFall - fallDisp) - PEG_BEFORE_FALL - treadmill;
        //transP -= tFallDisp;
    }
    return sdfPeg(transP);
}

float sdfBgCube(vec3 p) {
    vec3 d = abs(p) - vec3(HOLE_PIECE_SIDE * 0.95);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

const vec3 REP_Y_OFFSET = vec3(0.0, HOLE_PIECE_SIDE, 0.0);

float repBgCube(vec3 p) {
    vec3 c = vec3(2.0 * HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_SIDE);
    vec3 q = mod(p - REP_Y_OFFSET, c) - 0.5 * c;
    return sdfBgCube(q);
}

float sdfBridgeBoundary(vec3 p) {
    vec3 d = abs(p) - vec3(10.0 * HOLE_PIECE_SIDE, HOLE_PIECE_SIDE, 2.0 * HOLE_PIECE_SIDE);
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfBridge(vec3 p) {
    return max(repBgCube(p), sdfBridgeBoundary(p));
}

const vec3 PEG_SUPPORT_DIMS = vec3(HOLE_PIECE_SIDE, HOLE_PIECE_SIDE - PEG_RADIUS, HOLE_PIECE_SIDE);

float sdfPegSupportHole(vec3 p) {
    vec3 d = abs(p - vec3(1.0, 1.0, 0.0) * HOLE_PIECE_SIDE) - PEG_SUPPORT_DIMS;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdfPegBridge(vec3 p) {
    return max(sdfBridge(p), -sdfPegSupportHole(p));
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

float sdfCarvedBg(vec3 p) {
    float uncarved = sdfBoundedBgCubes(p);
    float first = sdfFirstLevelBoundary(p - vec3(1.0, 1.0, 0.0) * HOLE_PIECE_SIDE);
    float second = sdfSecondLevelBoundary(p - vec3(1.0, 2.0, 0.0) * HOLE_PIECE_SIDE);
    float third = sdfThirdLevelBoundary(p - vec3(1.0, 3.0, 0.0) * HOLE_PIECE_SIDE);
    float fourth = sdfFourthLevelBoundary(p - vec3(1.0, 4.0, 0.0) * HOLE_PIECE_SIDE);
    return max(max(max(max(uncarved, -first), -second), -third), -fourth);
}

const vec3 LEFT_TRANSLATION = vec3((NUM_CYCLES - 1.0) * 6.0, 0.0, 0.0);
const vec3 RIGHT_TRANSLATION = -LEFT_TRANSLATION + vec3(0.0, 0.0, 2.0 * HOLE_PIECE_THICKNESS);
const vec3 BRIDGE_TRANSLATION = vec3(-1.0, -2.0, 0.25) * HOLE_PIECE_SIDE;
const vec3 PEG_BRIDGE_TRANSLATION = vec3(-1.0, -2.0, 10.25) * HOLE_PIECE_SIDE;
const vec3 PEG_TRANSLATION = vec3(0.0, 0.0, 10.25) * HOLE_PIECE_SIDE;

// b = box dimensions
// r = radius of round parts
float udfRoundBox(vec3 p, vec3 b, float r)
{
  // test carved background
  float carved = sdfCarvedBg(p - BRIDGE_TRANSLATION);
  // test "bridge"
  float bridge = sdfBridge(p - BRIDGE_TRANSLATION);
  // test peg "bridge"
  float pegBridge = sdfPegBridge(p - PEG_BRIDGE_TRANSLATION);
  // test peg support
    float pegSupport = sdfPegSupportHole(p - PEG_BRIDGE_TRANSLATION);
  // test left piece
  float left = animHolePiece(p - LEFT_TRANSLATION, u_Time * 0.001);
  // test right piece
  float right = animHolePieceRight(p - RIGHT_TRANSLATION, u_Time * 0.001);
  // test peg
  float peg = animPeg(p - PEG_TRANSLATION, u_Time * 0.001);
  return min(peg, min(pegSupport, min(pegBridge, min(carved, min(bridge, min(left, right))))));
  return sdfHolePiece(p);
  return sdfCylinder(p, b);
  return sdfFlatCube(p);
  //return sdfTriPrism(p, vec2(2.0, 4.0));
  //return opCheapBend(p);
  //return sdfCylinder(p, b);
  /*
  vec3 c = vec3(6.0, 12.0, 6.0);
  vec3 q = mod(p, c) - 0.5 * c;
  return sdfTorus82(q, b.xy);
  */
  // note: can render cube from inside if return abs of "udf"
  return length(max(abs(p)-b,0.0))-r;
  //return sdfCube(p);
  // below gives interesting result w/ r = 1, b = vec3(2, 1, 1)
  return length(min(abs(p)-b,0.0))-r;
  return length(p) - r;
}

const float MAX_DIST = 1000.0;

// cake???
// PCB??
// rhythm heaven?
Intersection sphereMarch(in Ray r) {
    float t = 0.0;
    Intersection isx;
    isx.t = -1.0;
    isx.normal = vec3(1.0, -1.0, -1.0);
    for (int i = 0; i < 300; i++) {
        vec3 p = r.origin + t * r.dir;
        vec3 dims = vec3(1.0, 1.0, 1.0 + (cos(u_Time * 0.001) * 0.5 + 0.5));
        dims.xy = dims.zz;
        dims.z = 1.0;
        dims.xy = vec2(0.0);
        float radius = 0.3;
        float dist = udfRoundBox(p, dims, radius);
        if (dist < EPSILON * 10.0) {
            isx.t = t;
            float distXL = udfRoundBox(p - vec3(EPSILON, 0.0, 0.0), dims, radius);
            float distXH = udfRoundBox(p + vec3(EPSILON, 0.0, 0.0), dims, radius);
            float distYL = udfRoundBox(p - vec3(0.0, EPSILON, 0.0), dims, radius);
            float distYH = udfRoundBox(p + vec3(0.0, EPSILON, 0.0), dims, radius);
            float distZL = udfRoundBox(p - vec3(0.0, 0.0, EPSILON), dims, radius);
            float distZH = udfRoundBox(p + vec3(0.0, 0.0, EPSILON), dims, radius);
            // local normal!! need invTr
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
void main() {
	// TODO: make a Raymarcher!
    // aspect ratio?
    vec2 ndc = (gl_FragCoord.xy / u_Dims) * 2.0 - vec2(1.0);
    // flip Y?
    vec4 worldTarget = u_InvViewProj * vec4(ndc, 1.0, 1.0) * FAR_PLANE;
    Ray ray;
    ray.origin = u_EyePos;
    ray.dir = normalize(worldTarget.xyz - u_EyePos);
	out_Col = vec4(1.0, 0.5, 0.0, 1.0);
    out_Col.xyz = ray.dir * 0.5 + vec3(0.5);
    out_Col.xyz = vec3(0.1);
    Intersection isx = sphereMarch(ray);
    //float t = jankySqr(ray);
    out_Col.xyz = isx.normal * 0.5 + vec3(0.5);
}
