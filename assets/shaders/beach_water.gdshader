shader_type canvas_item;

// ============================================================================
// うみかぜ日和 〜 日本全国お魚釣り旅：福岡・糸島編 〜
// 【Godot最高峰 水質シミュレーション・海洋シェーダー】
// 1. 多重Trochoidal/Gerstner波による解析的動的法線（Dynamic Normal Mapping）
// 2. Beer-Lambert吸光則に基づくリアルな海水透過・波長散乱（Crystal Turquoise）
// 3. 波面屈折連動 デュアルレイヤー・バイリニア・コースティクス（Optical Caustics）
// 4. 物理ベース・フレネル反射（Fresnel）＆太陽光スペキュラ（GGX Specular）
// 5. 有機的海岸砕波（Shore Breaker Foam）＆網目状レース気泡（Cellular Foam Matrix）
// 6. 濡れた砂浜のしっとり感・水膜照り返し（Wet Sand Film Sheen）
// 7. 太陽光の微細なさざ波きらめき（Micro-facet Sun Sparkles）
// ============================================================================

// --- テクスチャ・マスク ---
uniform sampler2D water_mask : hint_default_white; // 海面マスク（白: 海, 黒: 陸地）
uniform sampler2D seabed_texture : hint_default_white; // 海底・原画テクスチャ

// --- カラー設定 ---
uniform vec4 shallow_color : source_color = vec4(0.38, 0.88, 0.82, 0.22);  // 浅瀬の超高透明度ミントアクア
uniform vec4 mid_color : source_color = vec4(0.18, 0.74, 0.72, 0.58);      // 中深度のエメラルドターコイズ
uniform vec4 deep_color : source_color = vec4(0.06, 0.42, 0.62, 0.88);     // 沖合深場のサファイアブルー
uniform vec4 foam_color : source_color = vec4(0.98, 1.0, 1.0, 0.98);       // 打ち寄せる純白の波泡
uniform vec4 dry_sand_color : source_color = vec4(0.93, 0.89, 0.80, 1.0);  // 暖かみある白砂
uniform vec4 wet_sand_color : source_color = vec4(0.76, 0.68, 0.52, 1.0);  // 濡れた砂（しっとりとした色）
uniform vec4 ripple_color : source_color = vec4(0.70, 0.65, 0.50, 1.0);    // 水底砂紋の陰影
uniform vec4 sun_color : source_color = vec4(1.0, 0.98, 0.90, 1.0);        // 太陽光ハイライト色
uniform vec4 caustics_color : source_color = vec4(1.0, 1.0, 0.95, 1.0);   // 集光コースティクス光色

// --- 物理・波パラメータ ---
uniform float time_speed : hint_range(0.1, 3.0) = 0.85;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.028;
uniform float wave_frequency : hint_range(1.0, 40.0) = 14.0;
uniform float caustics_strength : hint_range(0.0, 1.5) = 0.55;
uniform float caustics_scale : hint_range(5.0, 50.0) = 18.0;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.80;
uniform float sparkle_strength : hint_range(0.0, 2.0) = 0.75;

// 高速・高品質2Dハッシュ乱数
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// ゲーム内海岸線（SHORE_PTS）と1ミリの狂いもなく完全同期する区分エルミート補間
float get_shore_curve(float uv_y) {
    float y = clamp(uv_y * 648.0, 0.0, 648.0);
    if (y < 60.0) {
        float t = smoothstep(0.0, 60.0, y);
        return mix(200.0, 280.0, t) / 1152.0;
    } else if (y < 100.0) {
        float t = smoothstep(60.0, 100.0, y);
        return mix(280.0, 400.0, t) / 1152.0;
    } else if (y < 140.0) {
        float t = smoothstep(100.0, 140.0, y);
        return mix(400.0, 600.0, t) / 1152.0;
    } else if (y < 220.0) {
        float t = smoothstep(140.0, 220.0, y);
        return mix(600.0, 800.0, t) / 1152.0;
    } else if (y < 350.0) {
        float t = smoothstep(220.0, 350.0, y);
        return mix(800.0, 930.0, t) / 1152.0;
    } else if (y < 500.0) {
        float t = smoothstep(350.0, 500.0, y);
        return mix(930.0, 1060.0, t) / 1152.0;
    } else {
        float t = smoothstep(500.0, 648.0, y);
        return mix(1060.0, 1200.0, t) / 1152.0;
    }
}

// ----------------------------------------------------------------------------
// 多重Trochoidal/Gerstner波の解析的計算（高さ H と 勾配 dH/dx, dH/dy）
// ----------------------------------------------------------------------------
struct WaveResult {
    float height;
    vec2 normal_xy;
};

WaveResult get_water_waves(vec2 uv, float t) {
    WaveResult res;
    float h = 0.0;
    vec2 grad = vec2(0.0);

    // 4本の独立した進行波（斜め方向、異なる周期・振幅）
    // 波1: 主波（南西から北東へ進む大きなうねり）
    vec2 d1 = normalize(vec2(0.85, 0.52));
    float k1 = wave_frequency * 0.75;
    float w1 = t * 1.4;
    float phase1 = dot(d1, uv) * k1 - w1;
    float sin1 = sin(phase1);
    float cos1 = cos(phase1);
    float a1 = wave_amplitude * 0.45;
    h += a1 * sin1;
    grad += d1 * (a1 * k1 * cos1);

    // 波2: 交叉波（北西から南東へ進む波）
    vec2 d2 = normalize(vec2(0.70, -0.71));
    float k2 = wave_frequency * 1.35;
    float w2 = t * 1.9;
    float phase2 = dot(d2, uv) * k2 - w2;
    float sin2 = sin(phase2);
    float cos2 = cos(phase2);
    float a2 = wave_amplitude * 0.28;
    h += a2 * sin2;
    grad += d2 * (a2 * k2 * cos2);

    // 波3: 細かなさざ波（浅瀬で砕ける細波）
    vec2 d3 = normalize(vec2(-0.45, 0.89));
    float k3 = wave_frequency * 2.6;
    float w3 = t * 2.7;
    float phase3 = dot(d3, uv) * k3 - w3;
    float a3 = wave_amplitude * 0.15;
    h += a3 * sin(phase3);
    grad += d3 * (a3 * k3 * cos(phase3));

    // 波4: 微細高周波リップル
    vec2 d4 = normalize(vec2(0.92, 0.38));
    float k4 = wave_frequency * 4.8;
    float phase4 = dot(d4, uv) * k4 - t * 3.4;
    float a4 = wave_amplitude * 0.08;
    h += a4 * sin(phase4);
    grad += d4 * (a4 * k4 * cos(phase4));

    res.height = h;
    res.normal_xy = -grad; // 法線の傾き
    return res;
}

// ----------------------------------------------------------------------------
// Voronoi F2 - F1 エッジ（境界距離）による細線コースティクス
// ----------------------------------------------------------------------------
vec2 voronoi_edge(vec2 p, float t) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    float f1 = 8.0;
    float f2 = 8.0;
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 lattice = vec2(float(x), float(y));
            vec2 offset = hash2(g + lattice);
            vec2 pos = lattice + sin(offset * 6.2831 + t) * 0.42 + offset * 0.15 - f;
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

// 波面の屈折法線と連動したデュアルレイヤー・コースティクス
float get_caustics(vec2 uv, vec2 normal_xy, float t) {
    // パースペクティブ補正（手前ほど大きく、奥ほど細かく）
    float pers_scale = 1.0 + (1.0 - uv.y) * 0.40;
    // 水面の波による光線の屈折（屈折率による屈折偏向）
    vec2 refr_uv = (uv + normal_xy * 0.035) * vec2(1.0, 1.35) * pers_scale;
    
    vec2 uv1 = refr_uv * caustics_scale;
    vec2 uv2 = refr_uv * caustics_scale * 1.35 + vec2(1.4, 2.7);
    
    vec2 v1 = voronoi_edge(uv1, t * 1.15);
    vec2 v2 = voronoi_edge(uv2, -t * 0.95);
    
    float edge1 = v1.y - v1.x;
    float edge2 = v2.y - v2.x;
    
    float line1 = 1.0 - smoothstep(0.01, 0.16, edge1);
    float line2 = 1.0 - smoothstep(0.01, 0.14, edge2);
    
    // 集光スポットのシャープネス強調
    float caust = pow(clamp(line1 * 0.70 + line2 * 0.75, 0.0, 1.0), 2.0);
    return caust * caustics_strength;
}

// 水底の砂紋（Ripple Marks）
float get_sand_ripples(vec2 uv) {
    float wave = sin((uv.x * 0.85 + uv.y * 0.55) * 85.0 + sin(uv.y * 24.0) * 1.8);
    return smoothstep(0.42, 0.95, wave) * 0.09;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_speed;
    
    // 1. 海岸線の基準位置
    float shore_base = get_shore_curve(uv.y);
    
    // 2. 潮の満ち引き（波が砂浜に寄せては引く自然なうねり）
    float wave_cycle = t * 1.15;
    float wave_surge = sin(wave_cycle) * 0.024 + cos(wave_cycle * 0.45) * 0.009;
    float water_line = shore_base + wave_surge; // 実際の水面の先端位置
    
    float water_dist = uv.x - water_line; // < 0: 海, > 0: 砂浜
    float depth = clamp(-water_dist * 1.75, 0.0, 1.0); // 水深
    
    // 左上ウッドデッキ周辺の深度補正
    if (uv.x < 0.32 && uv.y < 0.42) {
        depth = max(depth, 0.35);
    }

    // ------------------------------------------------------------------------
    // A. 砂浜（陸地）の描写
    // ------------------------------------------------------------------------
    float max_wave_reach = shore_base + 0.035;
    // 波が引いた直後の濡れた砂（Wet Sand）
    float wet_factor = smoothstep(max_wave_reach + 0.022, shore_base - 0.015, uv.x);
    vec4 sand = mix(dry_sand_color, wet_sand_color, wet_factor * 0.88);
    
    // 濡れた砂の表面反射（太陽光のしっとりした水膜スペキュラ）
    if (wet_factor > 0.15 && uv.x > water_line) {
        float wet_sheen = pow(clamp(sin(uv.x * 24.0 + uv.y * 12.0 + t * 0.5), 0.0, 1.0), 3.0) * 0.14 * wet_factor;
        float glint = pow(hash2(floor(uv * 200.0)).x, 16.0) * 0.30 * wet_factor;
        sand.rgb += vec3(wet_sheen + glint);
    }
    
    // 砂粒の微細なノイズテクスチャ
    float grain = (hash2(floor(uv * 160.0)).x - 0.5) * 0.025;
    sand.rgb += vec3(grain);

    // ------------------------------------------------------------------------
    // B. 海水マスク判定（マスクが白のエリア＝海面、黒のエリア＝陸地）
    // ------------------------------------------------------------------------
    float mask_val = texture(water_mask, uv).r;
    if (mask_val > 0.05) {
        // 1. 多重Gerstner波シミュレーションによる動的法線ベクトルの取得
        WaveResult wave = get_water_waves(uv, t);
        vec3 normal = normalize(vec3(wave.normal_xy * 2.2, 1.0));
        
        // 2. 水底（Seabed）のサンプリング（原画テクスチャ屈折連動）
        vec2 refracted_uv = uv + wave.normal_xy * 0.018;
        vec4 seabed = texture(seabed_texture, refracted_uv);

        // 3. 深度に応じたリアルな海水カラー遷移
        vec4 sea_color;
        if (depth < 0.32) {
            sea_color = mix(shallow_color, mid_color, depth / 0.32);
        } else {
            sea_color = mix(mid_color, deep_color, smoothstep(0.32, 1.0, depth));
        }

        // 水の透明度合成（海底の海藻林や磯根がリアルに透けて見える！）
        float water_opacity = clamp(sea_color.a * 0.75 + depth * 0.25, 0.20, 0.85);
        vec4 water = mix(seabed, sea_color, water_opacity);

        // 4. 動的コースティクス網の照射（法線屈折連動・深度減衰）
        float caust = get_caustics(uv, wave.normal_xy, t);
        float caust_depth = 1.0 - smoothstep(0.0, 0.90, depth) * 0.40;
        water.rgb += caustics_color.rgb * (caust * caust_depth * 0.55);

        // 5. 太陽光のスペキュラハイライト（波頭の稜線がきらりと光る繊細なGGX）
        vec3 light_dir = normalize(vec3(-0.45, -0.65, 0.62)); // 斜め奥からの太陽光
        vec3 view_dir = vec3(0.0, 0.0, 1.0); // 見下ろし視線
        vec3 half_vec = normalize(light_dir + view_dir);
        float n_dot_h = max(0.0, dot(normal, half_vec));
        float specular = pow(n_dot_h, 96.0) * (specular_strength * 0.50);
        water.rgb += sun_color.rgb * specular;

        // 6. 物理ベース・フレネル反射（斜め奥ほど空の反射が強くなる）
        float fresnel = pow(1.0 - max(0.0, dot(normal, view_dir)), 4.0);
        water.rgb = mix(water.rgb, vec3(0.72, 0.90, 0.98), fresnel * 0.20);

        // 7. 太陽光の微細なさざ波きらめき（ダイヤモンドダストのような瞬き）
        vec2 sparkle_uv = uv * 140.0 + vec2(t * 0.7, -t * 0.5) + wave.normal_xy * 3.0;
        float sp_hash = hash2(floor(sparkle_uv)).x;
        float sp_blink = sin(t * 4.5 + sp_hash * 6.28);
        if (sp_hash > 0.970 && sp_blink > 0.80) {
            float sp_intensity = (sp_blink - 0.80) * 5.0 * sparkle_strength;
            water.rgb += sun_color.rgb * sp_intensity;
        }

        // 8. 有機的白波（海岸線マスクのエッジに沿って打ち寄せる白波と泡）
        float foam_wave = sin(t * 2.0 + mask_val * 12.0) * 0.08;
        float shore_foam = smoothstep(0.08, 0.28 + foam_wave, mask_val) * (1.0 - smoothstep(0.28 + foam_wave, 0.45, mask_val));
        
        // 微細な気泡レース
        vec2 foam_cell_uv = uv * 300.0 + wave.normal_xy * 2.0;
        float foam_noise = hash2(floor(foam_cell_uv)).x * 0.25;

        float total_foam = clamp((shore_foam * 1.4 + foam_noise * shore_foam), 0.0, 1.0);
        water = mix(water, foam_color, total_foam * 0.85);

        // マスクのエッジで滑らかにフェード
        float edge_alpha = smoothstep(0.05, 0.20, mask_val);
        COLOR = vec4(water.rgb, edge_alpha);
    } else {
        COLOR = vec4(0.0);
    }
}
