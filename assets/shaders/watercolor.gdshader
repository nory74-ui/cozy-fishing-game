shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float paper_roughness : hint_range(0.0, 0.2) = 0.045;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.14;
uniform vec4 paper_tint : source_color = vec4(0.995, 0.985, 0.96, 1.0);

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
    for (int i = 0; i < 3; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec4 screen_col = texture(screen_texture, SCREEN_UV);
    
    // 水彩紙の微細な凹凸と繊維
    vec2 paper_uv = SCREEN_UV * vec2(500.0, 280.0);
    float n = fbm(paper_uv) - 0.5;
    
    // 紙の色味とテクスチャの合成
    vec3 col = screen_col.rgb * paper_tint.rgb;
    col += n * paper_roughness;
    
    // 四隅の淡い水彩のにじみ（ヴィネット）
    vec2 uv = SCREEN_UV - 0.5;
    float d = length(uv);
    col -= d * d * vignette_strength;
    
    COLOR = vec4(col, screen_col.a);
}
