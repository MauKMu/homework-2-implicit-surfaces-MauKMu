#version 300 es

precision highp float;

uniform vec2 u_Dims;
uniform vec3 u_EyePos;
uniform mat4 u_InvViewProj;

out vec4 out_Col;

// hard-code this
const float FAR_PLANE = 1000.0;

void main() {
	// TODO: make a Raymarcher!
    // aspect ratio?
    vec2 ndc = (gl_FragCoord.xy / u_Dims) * 2.0 - vec2(1.0);
    // flip Y?
    vec4 worldTarget = u_InvViewProj * vec4(ndc, 1.0, 1.0) * FAR_PLANE;
    vec3 rayOrigin = u_EyePos;
    vec3 rayDir = normalize(worldTarget.xyz - rayOrigin);
	out_Col = vec4(1.0, 0.5, 0.0, 1.0);
    out_Col.xyz = rayDir * 0.5 + vec3(0.5);
}
