shader_type canvas_item;

// 南国のエメラルドグリーン海洋シェーダー（動画「I Just Wanted to Fish」完全再現）

uniform vec4 shallow_color : source_color = vec4(0.42, 0.88, 0.78, 1.0);  // 浅瀬の鮮やかなエメラルドグリーン
uniform vec4 deep_color : source_color = vec4(0.12, 0.62, 0.72, 1.0);     // 沖合の美しいターコイズブルー
uniform vec4 foam_color : source_color = vec4(0.98, 1.0, 1.0, 0.95);     // 寄せては引く白い波の泡
uniform vec4 wet_sand_color : source_color = vec4(0.84, 0.76, 0.60, 1.0); // 濡れた砂浜
uniform vec4 dry_sand_color : source_color = vec4(0.95, 0.90, 0.76, 1.0); // 乾いた砂浜

uniform float time_speed : hint_range(0.1, 3.0) = 0.9;
uniform float caustics_strength : hint_range(0.0, 1.0) = 0.32;
uniform float caustics_scale : hint_range(1.0, 30.0) = 13.0;

// 疑似乱数・ハッシュ
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// ボロノイ（コースティクス用）
float voronoi(vec2 p) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    float d = 1.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 lattice = vec2(float(x), float(y));
            vec2 offset = hash2(g + lattice);
            vec2 diff = lattice + sin(offset * 6.2831 + TIME * time_speed * 1.5) * 0.38 + offset * 0.2 - f;
            d = min(d, length(diff));
        }
    }
    return d;
}

// コースティクスの網目模様
float get_caustics(vec2 uv) {
    vec2 uv1 = uv * caustics_scale;
    vec2 uv2 = uv * caustics_scale * 1.3 + vec2(0.3, 0.5);
    float v1 = voronoi(uv1);
    float v2 = voronoi(uv2 + vec2(sin(TIME * 0.7), cos(TIME * 0.6)) * 0.2);
    float c = min(v1, v2);
    return pow(1.0 - c, 2.2) * caustics_strength;
}

// 砂浜の海岸線曲線を定義
// uv.xが右に行くほど、uv.yが上に行くほど陸地（砂浜）
float get_shore_dist(vec2 uv) {
    // 弧を描く海岸線
    float curve = 0.58 + sin(uv.y * 3.14159 * 0.85 + 0.35) * 0.18 + uv.y * 0.14;
    return uv.x - curve;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_speed;
    
    // 海岸線からの正規化距離（< 0 は海、> 0 は砂浜）
    float shore_dist = get_shore_dist(uv);
    
    // 水深（沖に行くほど深く: -0.6 〜 0.0）
    float depth = clamp(-shore_dist * 2.0, 0.0, 1.0);
    
    // 基本の海水色（エメラルド〜ターコイズのグラデーション）
    vec4 water = mix(shallow_color, deep_color, depth);
    
    // コースティクスの光
    float caust = get_caustics(uv);
    float caust_mask = clamp(-shore_dist * 4.0, 0.0, 1.0) * (1.0 - depth * 0.35);
    water.rgb += vec3(caust * caust_mask);
    
    // 水面の穏やかな波紋ハイライト
    float ripple = sin(uv.x * 25.0 + uv.y * 18.0 + t * 1.2) * cos(uv.x * 12.0 - uv.y * 22.0 - t * 0.9);
    water.rgb += vec3(max(0.0, ripple) * 0.08 * caust_mask);
    
    // 波打ち際の波（寄せては引く波アニメーション）
    float wave_cycle = t * 1.2;
    float wave_phase = sin(wave_cycle); // -1.0 〜 1.0
    // 主波の位置
    float wave1_pos = -0.035 + wave_phase * 0.032;
    float wave1_dist = abs(shore_dist - wave1_pos);
    float wave1_edge = smoothstep(0.018, 0.0, wave1_dist);
    
    // 引いた後に残る細い波（副波）
    float wave2_pos = -0.012 + sin(wave_cycle - 1.4) * 0.018;
    float wave2_dist = abs(shore_dist - wave2_pos);
    float wave2_edge = smoothstep(0.012, 0.0, wave2_dist) * 0.65;
    
    // 泡のレースパターン
    float foam_noise = (hash2(floor(uv * 120.0)).x - 0.5) * 0.2;
    float total_foam = clamp((wave1_edge + wave2_edge) + foam_noise * (wave1_edge + wave2_edge), 0.0, 1.0);
    
    // 砂浜の描画（濡れた砂と乾いた砂）
    float wet_extent = 0.035; // 潮が引いた後の濡れた砂の範囲
    vec4 sand = mix(wet_sand_color, dry_sand_color, smoothstep(0.0, wet_extent + 0.05, shore_dist));
    
    // 砂浜の微細なノイズ質感
    float sand_grain = (hash2(floor(uv * 90.0)).x - 0.5) * 0.025;
    sand.rgb += vec3(sand_grain);
    
    // 海と砂浜の合成
    vec4 final_color;
    if (shore_dist < 0.0) {
        // 海
        final_color = water;
        // 浅瀬の砂が透ける透明感
        float see_through = clamp(1.0 - depth * 1.5, 0.0, 0.65);
        final_color = mix(final_color, wet_sand_color, see_through * 0.35);
    } else {
        // 砂浜
        final_color = sand;
    }
    
    // 白い波の泡をオーバーレイ
    final_color = mix(final_color, foam_color, total_foam * 0.95);
    
    COLOR = final_color;
}
