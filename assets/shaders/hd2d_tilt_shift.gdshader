shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.4;
uniform float focus_y : hint_range(0.0, 1.0) = 0.52;
uniform float focus_height : hint_range(0.05, 0.6) = 0.32;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.18;
uniform float saturation : hint_range(0.5, 1.5) = 1.08;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // 中央の焦点エリアからの距離（ティルトシフト被写界深度）
    float dist_from_focus = abs(uv.y - focus_y);
    float blur_factor = smoothstep(focus_height * 0.5, focus_height * 1.5, dist_from_focus) * blur_amount;
    
    vec4 col = vec4(0.0);
    
    if (blur_factor > 0.05) {
        // 9タップガウシアンブラー
        vec2 texel = vec2(1.0) / vec2(textureSize(screen_texture, 0)) * blur_factor;
        col += texture(screen_texture, uv + vec2(-texel.x, -texel.y) * 1.5) * 0.06;
        col += texture(screen_texture, uv + vec2(0.0, -texel.y) * 1.5) * 0.12;
        col += texture(screen_texture, uv + vec2(texel.x, -texel.y) * 1.5) * 0.06;
        
        col += texture(screen_texture, uv + vec2(-texel.x, 0.0) * 1.5) * 0.12;
        col += texture(screen_texture, uv) * 0.28;
        col += texture(screen_texture, uv + vec2(texel.x, 0.0) * 1.5) * 0.12;
        
        col += texture(screen_texture, uv + vec2(-texel.x, texel.y) * 1.5) * 0.06;
        col += texture(screen_texture, uv + vec2(0.0, texel.y) * 1.5) * 0.12;
        col += texture(screen_texture, uv + vec2(texel.x, texel.y) * 1.5) * 0.06;
    } else {
        col = texture(screen_texture, uv);
    }
    
    // 彩度調整
    float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    col.rgb = mix(vec3(gray), col.rgb, saturation);
    
    // ミニチュア風周辺ヴィネット
    vec2 center_uv = uv - 0.5;
    float vig = length(center_uv);
    col.rgb -= vig * vig * vignette_amount;
    
    COLOR = col;
}
