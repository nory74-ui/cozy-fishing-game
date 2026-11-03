shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform vec4 shallow_color : source_color = vec4(0.06, 0.48, 0.58, 0.88); // 澄んだエメラルドグリーン
uniform vec4 deep_color : source_color = vec4(0.02, 0.14, 0.32, 0.96);   // 玄界灘の深い藍色
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 0.9);

uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;

void vertex() {
	// 微細なさざ波
	float t = TIME * wave_speed;
	float w = sin(VERTEX.x * 2.5 + t) * cos(VERTEX.z * 2.0 + t * 0.7) * 0.025;
	VERTEX.y += w;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = UV * 60.0; // 緻密なスケール
	
	// 流れるコースティクスと微細な水面のゆらめき
	vec2 uv1 = p + vec2(t * 0.08, t * 0.04);
	vec2 uv2 = p * 1.4 - vec2(t * 0.06, -t * 0.09);
	
	float s1 = sin(uv1.x + cos(uv1.y * 1.8));
	float s2 = cos(uv2.x + sin(uv2.y * 1.5));
	float wave_pattern = clamp((s1 + s2) * 0.5 + 0.5, 0.0, 1.0);
	float sparkle = pow(wave_pattern, 5.0) * 0.35;

	// 法線マップ（さざ波による光の反射）
	vec3 norm_offset = vec3(s1 * 0.06, 1.0, s2 * 0.06);
	NORMAL = normalize(NORMAL + norm_offset);

	// 水深によるグラデーション（Z軸奥に向かって深海色）
	float depth_fac = clamp((6.0 - VERTEX.z) * 0.05, 0.0, 1.0);
	vec4 base_water = mix(shallow_color, deep_color, depth_fac);
	
	vec3 final_color = base_water.rgb + sparkle * foam_color.rgb;

	ALBEDO = final_color;
	ALPHA = base_water.a;
	METALLIC = 0.2;
	ROUGHNESS = 0.12;
	SPECULAR = 0.75;
}
