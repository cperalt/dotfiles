void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iChannel0, uv);

    // Increase saturation — adjust VIBRANCE to taste (1.0 = no change, 1.3 = 30% boost)
    const float VIBRANCE = 1.3;

    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray = vec3(luminance);
    color.rgb = mix(gray, color.rgb, VIBRANCE);

    fragColor = color;
}
