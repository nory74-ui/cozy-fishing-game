shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

// --- Xの動画完全準拠：深みのあるエメラルド・ターコイズ水面 & 繊細なレース白波・ボロノイコースティクス ---

uniform vec4 shallow_color : source_color = vec4(0.18, 0.78, 0.66, 0.34); // 波打ち際のクリアミント
uniform vec4 mid_color : source_color = vec4(0.06, 0.66, 0.62, 0.70);     // 浅瀬のエメラルドターコイズ
uniform vec4 deep_color : source_color = vec4(0.02, 0.46, 0.52, 0.88);    // 沖合のディープターコイズ
uniform float depth_distance : hint_range(0.1, 25.0) = 2.8;

uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 0.99, 0.94);     // 純白のレース波
uniform float wave_speed : hint_range(0.0, 5.0) = 0.85;
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.018;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float voronoi_caustics(vec2 x, float time) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			o = 0.5 + 0.42 * sin(time * 0.65 + 6.2831 * o);
			vec2 r = g - f + o;
			float d = dot(r, r);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	float edge = sqrt(f2) - sqrt(f1);
	return smoothstep(0.11, 0.0, edge);
}

float foam_bubble_cells(vec2 x, float time) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float min_d = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			o = 0.5 + 0.35 * sin(time * 0.9 + 6.2831 * o);
			vec2 r = g - f + o;
			float d = dot(r, r);
			min_d = min(min_d, d);
		}
	}
	return sqrt(min_d);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float w1 = sin(world_pos.x * 0.55 + t * 1.1) * cos(world_pos.z * 0.45 + t * 0.8) * wave_amplitude;
	float w2 = sin((world_pos.x - world_pos.z) * 0.9 + t * 1.4) * (wave_amplitude * 0.4);
	VERTEX.y += w1 + w2;
}

void fragment() {
	float depth_raw = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;

	float scene_z = -view_pos.z;
	float surface_z = -VERTEX.z;
	float water_depth = scene_z - surface_z;

	if (water_depth < 0.002) {
		discard;
	}

	float depth_norm = clamp(water_depth / depth_distance, 0.0, 1.0);
	vec4 water_col = vec4(0.0);
	if (depth_norm < 0.28) {
		water_col = mix(shallow_color, mid_color, smoothstep(0.0, 0.28, depth_norm));
	} else {
		water_col = mix(mid_color, deep_color, smoothstep(0.28, 1.0, depth_norm));
	}

	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;

	// ボロノイ網目コースティクス（frame_009.jpg 準拠）
	float c_net = voronoi_caustics(world_pos.xz * 0.42 + vec2(t * 0.08, -t * 0.05), t);
	float caustics_mask = c_net * smoothstep(0.08, 0.22, water_depth) * (1.0 - smoothstep(0.9, 3.2, water_depth)) * 0.14;

	// 波打ち際 & 浅瀬岩周りの繊細なレース白波（水深 0.11m 以浅のみに限定し海中サンゴには干渉しない）
	float tide = sin(t * 1.4 + world_pos.z * 0.25) * 0.02;
	float shore_band = smoothstep(0.11 + tide, 0.0, water_depth);

	float cell_small = foam_bubble_cells(world_pos.xz * 4.5 + vec2(t * 0.25, 0.0), t);
	float cell_tiny = foam_bubble_cells(world_pos.xz * 10.0 - vec2(t * 0.35, 0.0), t);
	float lace_pattern = smoothstep(0.34, 0.58, cell_small * 0.65 + cell_tiny * 0.35 + shore_band * 0.50);
	float main_shore_foam = shore_band * lace_pattern;

	float crisp_rim = smoothstep(0.03, 0.004, water_depth) * 0.92;

	// 2本目の細い白波ライン（frame_001.jpg 準拠）
	float wave_phase = fract(t * 0.30 + sin(world_pos.z * 0.2) * 0.06);
	float wave_target_depth = mix(0.20, 0.05, wave_phase);
	float thin_wave_line = smoothstep(0.016, 0.0, abs(water_depth - wave_target_depth)) * sin(wave_phase * 3.14159) * 0.68;

	float foam_factor = clamp(max(max(main_shore_foam, crisp_rim), thin_wave_line), 0.0, 1.0);

	vec3 final_color = mix(water_col.rgb + vec3(caustics_mask), foam_color.rgb, foam_factor);
	float final_alpha = mix(water_col.a, 0.94, foam_factor);

	ALBEDO = final_color;
	ALPHA = final_alpha;
	ROUGHNESS = mix(0.48, 0.75, foam_factor);
	SPECULAR = 0.04;
}
