shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float tilt_shift_strength : hint_range(0.0, 4.0) = 1.2;
uniform float focus_y : hint_range(0.0, 1.0) = 0.50;
uniform float focus_band : hint_range(0.1, 0.8) = 0.45;
uniform float paper_roughness : hint_range(0.0, 0.1) = 0.025;
uniform float vignette : hint_range(0.0, 0.5) = 0.10;
uniform float saturation : hint_range(0.8, 1.4) = 1.05;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // 1. HD-2D なめらかな被写界深度ティルトシフト
    float dist = abs(uv.y - focus_y);
    float blur_factor = smoothstep(focus_band * 0.4, focus_band * 1.5, dist);
    float blur = blur_factor * tilt_shift_strength;
    
    vec4 col_sharp = texture(screen_texture, uv);
    vec4 col = col_sharp;
    
    if (blur > 0.01) {
        vec2 texel = vec2(1.0) / vec2(textureSize(screen_texture, 0)) * blur;
        vec4 col_blur = vec4(0.0);
        col_blur += texture(screen_texture, uv + vec2(-texel.x, -texel.y) * 1.2) * 0.08;
        col_blur += texture(screen_texture, uv + vec2(0.0, -texel.y) * 1.2) * 0.14;
        col_blur += texture(screen_texture, uv + vec2(texel.x, -texel.y) * 1.2) * 0.08;
        col_blur += texture(screen_texture, uv + vec2(-texel.x, 0.0) * 1.2) * 0.14;
        col_blur += texture(screen_texture, uv) * 0.28;
        col_blur += texture(screen_texture, uv + vec2(texel.x, 0.0) * 1.2) * 0.14;
        col_blur += texture(screen_texture, uv + vec2(-texel.x, texel.y) * 1.2) * 0.08;
        col_blur += texture(screen_texture, uv + vec2(0.0, texel.y) * 1.2) * 0.14;
        col_blur += texture(screen_texture, uv + vec2(texel.x, texel.y) * 1.2) * 0.08;
        col = mix(col_sharp, col_blur, clamp(blur_factor * 1.2, 0.0, 1.0));
    }
    
    // 2. 水彩紙の微細テクスチャ
    float grain = (noise(uv * vec2(480.0, 270.0)) - 0.5) * paper_roughness;
    col.rgb += grain;
    
    // 3. HD-2D 彩度と温かみ
    float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    col.rgb = mix(vec3(gray), col.rgb, saturation);
    
    // 4. 周辺光量落ち（ヴィネット）
    vec2 cuv = uv - 0.5;
    col.rgb -= dot(cuv, cuv) * vignette;
    
    COLOR = col;
}
