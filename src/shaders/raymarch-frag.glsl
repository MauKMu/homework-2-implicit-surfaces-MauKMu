#version 300 es

precision highp float;

uniform vec2 u_Dims;
uniform vec3 u_EyePos;
uniform mat4 u_InvViewProj;

out vec4 out_Col;

// hard-code this
const float FAR_PLANE = 1000.0;
const float EPSILON = 0.001;

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

float udfRoundBox(vec3 p, vec3 b, float r)
{
  return length(max(abs(p)-b,0.0))-r;
  //return sdfCube(p);
  // below gives interesting result w/ r = 1, b = vec3(2, 1, 1)
  return length(min(abs(p)-b,0.0))-r;
  return length(p) - r;
}

const float MAX_DIST = 1000.0;

Intersection sphereMarch(in Ray r) {
    float t = 0.0;
    Intersection isx;
    isx.t = -1.0;
    isx.normal = vec3(1.0, -1.0, -1.0);
    for (int i = 0; i < 100; i++) {
        vec3 p = r.origin + t * r.dir;
        vec3 dims = vec3(0.5);
        float radius = 0.3;
        float dist = udfRoundBox(p, dims, radius);
        if (dist < EPSILON * 0.1) {
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
