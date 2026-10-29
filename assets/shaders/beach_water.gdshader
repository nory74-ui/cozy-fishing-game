shader_type canvas_item;

// 福岡県・糸島（玄界灘・野北）クリスタルクリア海洋シェーダー
// 透明感あふれる浅瀬、水底の砂紋、リアルタイムコースティクス、波打ち際の白波

uniform vec4 shallow_color : source_color = vec4(0.35, 0.88, 0.80, 1.0);  // 浅瀬のクリアエメラルド
uniform vec4 deep_color : source_color = vec4(0.08, 0.46, 0.66, 1.0);     // 沖合のターコイズコバルト
uniform vec4 foam_color : source_color = vec4(0.98, 1.0, 1.0, 0.96);     // 白波の泡
uniform vec4 wet_sand_color : source_color = vec4(0.84, 0.77, 0.64, 1.0); // 濡れた砂
uniform vec4 dry_sand_color : source_color = vec4(0.96, 0.92, 0.81, 1.0); // 乾いた白砂
uniform vec4 ripple_color : source_color = vec4(0.72, 0.66, 0.52, 1.0);   // 水底の砂紋の影

uniform float time_speed : hint_range(0.1, 3.0) = 0.95;
uniform float caustics_strength : hint_range(0.0, 1.0) = 0.38;
uniform float caustics_scale : hint_range(1.0, 30.0) = 14.0;

// ハッシュ・乱数
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
            vec2 diff = lattice + sin(offset * 6.2831 + TIME * time_speed * 1.6) * 0.38 + offset * 0.2 - f;
            d = min(d, length(diff));
        }
    }
    return d;
}

// コースティクスの光の網目
float get_caustics(vec2 uv) {
    vec2 uv1 = uv * caustics_scale;
    vec2 uv2 = uv * caustics_scale * 1.35 + vec2(0.4, 0.6);
    float v1 = voronoi(uv1);
    float v2 = voronoi(uv2 + vec2(sin(TIME * 0.8), cos(TIME * 0.7)) * 0.25);
    float c = min(v1, v2);
    return pow(1.0 - c, 2.4) * caustics_strength;
}

// 糸島・野北サーフの海岸線（UV空間）
// 右側（uv.x > curve）が砂浜、左側（uv.x <= curve）が海
float get_shore_x(float uv_y) {
    return 0.63 + sin(uv_y * 3.14159 * 0.95 + 0.2) * 0.08 + (uv_y - 0.5) * 0.06;
}

// 水底の砂紋（Ripple Marks）
float get_sand_ripples(vec2 uv) {
    float wave = sin(uv.x * 90.0 + sin(uv.y * 30.0) * 2.0);
    return smoothstep(0.4, 0.9, wave) * 0.15;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_speed;
    
    float shore_curve = get_shore_x(uv.y);
    float shore_dist = uv.x - shore_curve; // < 0 は海、> 0 は砂浜
    
    // 水深（砂浜から離れるほど深くなる: 0.0 = 浅瀬, 1.0 = 沖合）
    float depth = clamp(-shore_dist * 2.2, 0.0, 1.0);
    
    // 大波止の領域（UV: x 0.0〜0.47, y 0.31〜0.54）の周囲は水深が急に深くなる
    bool is_near_pier = uv.x < 0.50 && uv.y > 0.26 && uv.y < 0.59;
    if (is_near_pier) {
        depth = max(depth, 0.45);
    }
    
    // 1. 水底（Seabed）の描写
    // 浅瀬の底に見える白い砂地
    float ripple = get_sand_ripples(uv);
    vec4 seabed = mix(dry_sand_color, ripple_color, ripple);
    
    // 2. コースティクスの光
    float caust = get_caustics(uv);
    
    // 3. 海水の色（透明度の高いエメラルドグリーン 〜 ターコイズブルー）
    vec4 sea_color = mix(shallow_color, deep_color, smoothstep(0.0, 0.8, depth));
    
    // 4. 水面の透明感合成（浅瀬は水底の砂紋がくっきり透き通る！）
    float water_opacity = clamp(0.35 + depth * 0.60, 0.0, 0.95);
    vec4 water = mix(seabed, sea_color, water_opacity);
    
    // コースティクスを水底と海水に照射（浅瀬ほど強く光る）
    float caust_intensity = caust * (1.0 - depth * 0.45);
    water.rgb += vec3(caust_intensity);
    
    // 水面の穏やかなきらめき
    float shimmer = sin(uv.x * 35.0 + uv.y * 22.0 + t * 1.4) * cos(uv.x * 20.0 - uv.y * 30.0 - t * 1.1);
    water.rgb += vec3(max(0.0, shimmer) * 0.06);
    
    // 5. 砂浜に打ち寄せる波（寄せては引く波頭 Foam）
    float wave_cycle = t * 1.3;
    float wave_phase = sin(wave_cycle);
    
    // 主波（寄せてくる大きな白波）
    float wave1_pos = -0.038 + wave_phase * 0.034;
    float wave1_dist = abs(shore_dist - wave1_pos);
    float wave1_edge = smoothstep(0.016, 0.0, wave1_dist);
    
    // 副波（引いていくときの細い泡の帯）
    float wave2_pos = -0.014 + sin(wave_cycle - 1.5) * 0.016;
    float wave2_dist = abs(shore_dist - wave2_pos);
    float wave2_edge = smoothstep(0.011, 0.0, wave2_dist) * 0.6;
    
    // 泡の微細レース模様
    float foam_noise = (hash2(floor(uv * 140.0)).x - 0.5) * 0.25;
    float total_foam = clamp((wave1_edge + wave2_edge) * (1.0 + foam_noise), 0.0, 1.0);
    
    // 6. 砂浜の描画（濡れた砂と乾いた白砂）
    float wet_extent = 0.04;
    vec4 sand = mix(wet_sand_color, dry_sand_color, smoothstep(0.0, wet_extent + 0.06, shore_dist));
    float sand_grain = (hash2(floor(uv * 110.0)).x - 0.5) * 0.02;
    sand.rgb += vec3(sand_grain);
    
    // 7. 海と砂浜の結合
    vec4 final_color;
    if (shore_dist < 0.0) {
        final_color = water;
    } else {
        final_color = sand;
    }
    
    // 白波の泡を重ねる
    final_color = mix(final_color, foam_color, total_foam * 0.95);
    
    COLOR = final_color;
}
