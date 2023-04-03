#version 150




#define EXPOSURE -1.7

#define TONEMAP_LOWER_CURVE 1.0
#define TONEMAP_UPPER_CURVE 1.0
#define TONEMAP_WHITE_CURVE 2.0
#define SATURATION 1.25
#define VIBRANCE 1.25
vec3 toLinear(vec3 sRGB)
{
    return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}


vec3 BSLTonemap(vec3 color)
{
    color = color * exp2(2.0 + EXPOSURE);
    color = color / pow(pow(color, vec3(TONEMAP_WHITE_CURVE)) + 1.0, vec3(1.0 / TONEMAP_WHITE_CURVE));
    color = pow(color, mix(vec3(TONEMAP_LOWER_CURVE), vec3(TONEMAP_UPPER_CURVE), sqrt(color)));
    return color;
}

vec3 colorSaturation(vec3 color)
{
    float grayVibrance = (color.r + color.g + color.b) / 3.0;
    float graySaturation = grayVibrance;
    if (SATURATION < 1.00)
        graySaturation = dot(color, vec3(0.299, 0.587, 0.114));

    float mn = min(color.r, min(color.g, color.b));
    float mx = max(color.r, max(color.g, color.b));
    float sat = (1.0 - (mx - mn)) * (1.0 - mx) * grayVibrance * 5.0;
    vec3 lightness = vec3((mn + mx) * 0.5);

    color = mix(color, mix(color, lightness, 1.0 - VIBRANCE), sat);
    color = mix(color, lightness, (1.0 - lightness) * (2.0 - VIBRANCE) / 2.0 * abs(VIBRANCE - 1.0));
    color = color * SATURATION - graySaturation * (SATURATION - 1.0);

    return color;
}


void getNightDesaturation(inout vec3 color)
{
    float weight = 30.0;

    color = pow(color, vec3(2.2));

    float brightness = dot(color, vec3(0.2627, 0.6780, 0.0593)) * 2.0;
    float amount = 0.01 / (pow(brightness * weight, 2.0) + 0.02);
    vec3 desatColor = mix(color, vec3(brightness), vec3(0.9)) * vec3(0.2, 1.0, 2.0);

    color = mix(color, desatColor, amount);

    color = pow(color, vec3(1.0 / 2.2));
}


float luma4(vec3 color)
{
    return dot(color, vec3(0.21, 0.72, 0.07));
}

vec4 linear_fog(vec4 inColor, float vertexDistance, float fogStart, float fogEnd, vec4 fogColor)
{
    if (fogStart > 1.0)
    { // just to look nicer
        fogStart /= 2.0;
    }
    vec4 precol = inColor;
    getNightDesaturation(precol.rgb);
    precol.rgb = BSLTonemap(precol.rgb);
    precol.rgb = colorSaturation(precol.rgb);
    if (vertexDistance <= fogStart)
    {
        return precol;
    }
    float density = 0.5;
    vec4 fcolor = fogColor;
    float lum = luma4(fcolor.rgb);
    vec3 diff = fcolor.rgb - lum;
    fcolor.rgb = fcolor.rgb + diff * (-lum * 2.3 + 0.0);

    float fogValue = vertexDistance < fogEnd ? smoothstep(fogStart, fogEnd, vertexDistance) : 1.0;

    //vec4 fog = vec4(mix(precol.rgb, fcolor.rgb, 1.0 - clamp(exp2(pow(density * fogValue, 2.0) * -1.442695), 0, 1)), precol.a);
    vec4 fog = vec4(mix(precol.rgb, fcolor.rgb, fogValue * fogColor.a), inColor.a);

    return fog;
}

float linear_fog_fade(float vertexDistance, float fogStart, float fogEnd) {
    if (vertexDistance <= fogStart) {
        return 1.0;
    } else if (vertexDistance >= fogEnd) {
        return 0.0;
    }

    return smoothstep(fogEnd, fogStart, vertexDistance);
}

float fog_distance(mat4 modelViewMat, vec3 pos, int shape) {
    if (shape == 0) {
        return length((modelViewMat * vec4(pos, 1.0)).xyz);
    } else {
        float distXZ = length((modelViewMat * vec4(pos.x, 0.0, pos.z, 1.0)).xyz);
        float distY = length((modelViewMat * vec4(0.0, pos.y, 0.0, 1.0)).xyz);
        return max(distXZ, distY);
    }
}


