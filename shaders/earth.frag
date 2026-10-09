#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Uniform order is the float index order EarthPainter writes; every uniform
// must be used, or the compiler drops it and shifts the indices.
uniform vec2 uCenter;
uniform float uRadius;
// The longitude and latitude facing the viewer, in radians.
uniform float uYaw;
uniform float uPitch;
// The sun direction in view space (x right, y up, z towards the viewer).
uniform vec3 uLight;
// The sea tint (rgb) and how much of it replaces the texture's sea (a).
uniform vec4 uOcean;
// The atmosphere colour (rgb) and strength (a).
uniform vec4 uAtmosphere;
// The halo's width beyond the edge, as a fraction of the radius.
uniform float uHalo;
// Equirectangular map: longitude -180..180 left to right, north at the top.
uniform sampler2D uEarth;

out vec4 fragColor;

const float PI = 3.14159265359;

void main() {
  vec2 p = (FlutterFragCoord().xy - uCenter) / uRadius;
  p.y = -p.y;
  float d = length(p);
  float aa = 1.2 / uRadius;
  vec3 atmosphere = uAtmosphere.rgb;
  float haloBase = uAtmosphere.a * 0.5;

  if (d > 1.0 + aa) {
    float t = clamp((d - 1.0) / uHalo, 0.0, 1.0);
    float glow = pow(1.0 - t, 3.0) * haloBase;
    fragColor = vec4(atmosphere * glow, glow);
    return;
  }

  float z = sqrt(max(1.0 - d * d, 0.0));
  vec3 n = vec3(p, z);

  // Undo the camera: pitch about x, then yaw about y.
  float cp = cos(uPitch);
  float sp = sin(uPitch);
  float y1 = n.y * cp + n.z * sp;
  float z1 = -n.y * sp + n.z * cp;
  float lat = asin(clamp(y1, -1.0, 1.0));
  float lon = atan(n.x, z1) + uYaw;
  vec2 uv = vec2(fract((lon + PI) / (2.0 * PI)), (0.5 * PI - lat) / PI);

  vec3 c = texture(uEarth, uv).rgb;
  // Blue Marble's sea is a flat dark navy: tint it, keep its shading.
  float ocean = clamp((c.b - max(c.r, c.g)) * 6.0, 0.0, 1.0);
  c = mix(c, uOcean.rgb * (0.55 + 1.6 * c.b), ocean * uOcean.a);

  float diffuse = max(dot(n, uLight), 0.0);
  vec3 col = c * (0.3 + 0.8 * diffuse);
  vec3 r = reflect(-uLight, n);
  col += vec3(pow(max(r.z, 0.0), 28.0) * ocean * 0.4);

  float rim = pow(1.0 - z, 2.5);
  col = mix(col, atmosphere, rim * uAtmosphere.a * 0.85);

  float inside = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, d);
  fragColor = mix(vec4(atmosphere * haloBase, haloBase), vec4(col, 1.0), inside);
}
