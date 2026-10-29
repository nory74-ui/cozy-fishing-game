shader_type canvas_item;

// うみかぜ日和 〜 日本全国お魚釣り旅：福岡・糸島編 〜
// 添付動画（ForkedPush）完全再現：クォータービュー（斜め見下ろし視点）クリスタルクリア海洋シェーダー
// 1. 左奥から右手前へダイナミックに伸びる斜め視点の海岸線
// 2. 実測カラーに基づく超高透明度ミントアクア・エメラルドグラデーション
// 3. Voronoi F2-F1エッジによる本物の極細水底コースティクス網（パースペクティブ補正）
// 4. 斜めの海岸線に沿って滑らかに寄せては引く繊細な白波泡ライン（Crisp Shore Foam Rims）
// 5. 波が引いた後のしっとり濡れた砂（Wet Sand with Soft Specular）
// 6. 太陽光の微細なきらめき（Sun Sparkles / Glint）

uniform vec4 shallow_color : source_color = vec4(0.38, 0.76, 0.70, 0.24);  // 浅瀬の超高透明度ミントアクア
uniform vec4 mid_color : source_color = vec4(0.32, 0.71, 0.66, 0.55);      // 中深度のエメラルドグリーン
uniform vec4 deep_color : source_color = vec4(0.21, 0.68, 0.64, 0.78);     // 沖合深場のクリアターコイズ
uniform vec4 foam_color : source_color = vec4(0.98, 1.0, 1.0, 0.98);       // 白波の純白泡
uniform vec4 wet_sand_color : source_color = vec4(0.66, 0.61, 0.45, 1.0);  // 濡れた砂（しっとりとした色）
uniform vec4 dry_sand_color : source_color = vec4(0.77, 0.73, 0.55, 1.0);  // 温かみある白砂
uniform vec4 ripple_color : source_color = vec4(0.68, 0.64, 0.48, 1.0);    // 水底砂紋の陰影

uniform float time_speed : hint_range(0.1, 3.0) = 0.92;
uniform float caustics_strength : hint_range(0.0, 1.0) = 0.40;
uniform float caustics_scale : hint_range(1.0, 45.0) = 22.0;

// ハッシュ乱数
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// クォータービュー（斜め視点）の海岸線カーブ（UV空間: 0.0〜1.0）
// 左上（約0.45）から右下（約0.82）へ緩やかなカーブを描いて横切る
float get_shore_curve(float uv_y) {
    return 0.44 + uv_y * 0.36 + sin(uv_y * 3.14159 * 0.85) * 0.07;
}

// Voronoi F2 - F1 エッジ（境界距離）による細線コースティクス
vec2 voronoi_edge(vec2 p, float t) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    float f1 = 8.0;
    float f2 = 8.0;
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 lattice = vec2(float(x), float(y));
            vec2 offset = hash2(g + lattice);
            vec2 pos = lattice + sin(offset * 6.2831 + t) * 0.38 + offset * 0.2 - f;
            float d = length(pos);
            if (d < f1) {
                f2 = f1;
                f1 = d;
            } else if (d < f2) {
                f2 = d;
            }
        }
    }
    return vec2(f1, f2);
}

// 極細でしなやかに歪む水底コースティクス網（クォータービュー パース補正）
float get_caustics(vec2 uv, float t) {
    // 奥行き（奥ほど細かく圧縮）のパースペクティブスケーリング
    float pers_scale = 1.0 + (1.0 - uv.y) * 0.35;
    vec2 p_uv = uv * vec2(1.0, 1.35) * pers_scale;
    
    vec2 uv1 = p_uv * caustics_scale;
    vec2 uv2 = p_uv * caustics_scale * 1.30 + vec2(1.2, 2.8);
    
    vec2 v1 = voronoi_edge(uv1, t * 1.15);
    vec2 v2 = voronoi_edge(uv2, -t * 0.95);
    
    float edge1 = v1.y - v1.x;
    float edge2 = v2.y - v2.x;
    
    float line1 = 1.0 - smoothstep(0.01, 0.14, edge1);
    float line2 = 1.0 - smoothstep(0.01, 0.12, edge2);
    
    float caust = pow(clamp(line1 * 0.75 + line2 * 0.75, 0.0, 1.0), 2.2);
    return caust * caustics_strength;
}

// 水底の砂紋（Ripple Marks）
float get_sand_ripples(vec2 uv) {
    float wave = sin((uv.x * 0.8 + uv.y * 0.6) * 95.0 + sin(uv.y * 28.0) * 2.0);
    return smoothstep(0.48, 0.92, wave) * 0.10;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_speed;
    
    float shore_base = get_shore_curve(uv.y);
    
    // 潮の満ち引き（波が斜めの砂浜に寄せては引く動き）
    float wave_cycle = t * 1.25;
    float wave_surge = sin(wave_cycle) * 0.022 + cos(wave_cycle * 0.5) * 0.008;
    float water_line = shore_base + wave_surge; // 実際の水面の先端位置
    
    // 水面からの法線距離（< 0 は海、> 0 は陸地）
    float water_dist = uv.x - water_line;
    
    // 水深（砂浜から沖合・左下に向かって緩やかに深くなる）
    float depth = clamp(-water_dist * 1.9, 0.0, 1.0);
    
    // 波止・桟橋の周辺の水深
    bool is_near_pier = uv.x < 0.42 && uv.y > 0.20 && uv.y < 0.65;
    if (is_near_pier) {
        depth = max(depth, 0.38);
    }
    
    // ----------------------------------------------------
    // 1. 水底（Seabed）の描写
    // ----------------------------------------------------
    float ripple = get_sand_ripples(uv);
    vec4 seabed = mix(dry_sand_color, ripple_color, ripple);
    
    // ----------------------------------------------------
    // 2. 海水の色（透明度の極めて高いアクアエメラルド）
    // ----------------------------------------------------
    vec4 sea_color;
    if (depth < 0.35) {
        sea_color = mix(shallow_color, mid_color, depth / 0.35);
    } else {
        sea_color = mix(mid_color, deep_color, (depth - 0.35) / 0.65);
    }
    
    // ----------------------------------------------------
    // 3. 水面の透明感合成（浅瀬は水底の砂地が80%透き通る！）
    // ----------------------------------------------------
    float water_opacity = clamp(sea_color.a + depth * 0.28, 0.20, 0.86);
    vec4 water = mix(seabed, sea_color, water_opacity);
    
    // ----------------------------------------------------
    // 4. 有機的コースティクス網の照射（動画通りの繊細な光）
    // ----------------------------------------------------
    float caust = get_caustics(uv, t);
    float caust_depth_falloff = 1.0 - smoothstep(0.0, 0.90, depth) * 0.35;
    water.rgb += vec3(caust * caust_depth_falloff);
    
    // ----------------------------------------------------
    // 5. 太陽光の微細なきらめき（Sun Sparkles / Glint）
    // ----------------------------------------------------
    vec2 sparkle_uv = uv * 95.0 + vec2(t * 0.7, -t * 0.5);
    float sparkle_hash = hash2(floor(sparkle_uv)).x;
    float sparkle_blink = sin(t * 3.8 + sparkle_hash * 6.28);
    if (sparkle_hash > 0.96 && sparkle_blink > 0.8) {
        water.rgb += vec3(0.25 * (sparkle_blink - 0.8) * 5.0);
    }
    
    // ----------------------------------------------------
    // 6. 斜めの砂浜に打ち寄せる白波（動画通りの極細で繊細な白波泡ライン）
    // ----------------------------------------------------
    // 主波（水面の最先端を走る極細の白波ライン）
    float foam1_edge = 0.0;
    if (water_dist < 0.0 && water_dist > -0.0035) {
        foam1_edge = smoothstep(-0.0035, -0.0005, water_dist);
    }
    
    // 副波（少し遅れて引いていく第2波の極細レースライン）
    float wave2_phase = sin(wave_cycle - 1.4);
    float wave2_pos = water_line - 0.022 + wave2_phase * 0.008;
    float foam2_dist = abs(uv.x - wave2_pos);
    float foam2_edge = smoothstep(0.0020, 0.0, foam2_dist) * 0.45;
    
    float foam_noise = (hash2(floor(uv * 220.0)).x - 0.5) * 0.3;
    float total_foam = clamp((foam1_edge + foam2_edge) * (1.0 + foam_noise), 0.0, 1.0);
    
    // ----------------------------------------------------
    // 7. 砂浜（乾いた白砂 と 濡れた砂 Wet Sand）
    // ----------------------------------------------------
    float max_wave_reach = shore_base + 0.030;
    float wet_factor = smoothstep(max_wave_reach + 0.02, shore_base - 0.01, uv.x);
    vec4 sand = mix(dry_sand_color, wet_sand_color, wet_factor * 0.80);
    
    if (wet_factor > 0.3 && uv.x > water_line) {
        float wet_shine = pow(clamp(sin(uv.x * 25.0 + t * 0.5), 0.0, 1.0), 4.0) * 0.06;
        sand.rgb += vec3(wet_shine);
    }
    
    float sand_grain = (hash2(floor(uv * 120.0)).x - 0.5) * 0.018;
    sand.rgb += vec3(sand_grain);
    
    // ----------------------------------------------------
    // 8. 海と砂浜の最終ブレンド
    // ----------------------------------------------------
    vec4 final_color;
    if (uv.x < water_line) {
        final_color = water;
    } else {
        final_color = sand;
    }
    
    final_color = mix(final_color, foam_color, total_foam * 0.95);
    
    COLOR = final_color;
}
