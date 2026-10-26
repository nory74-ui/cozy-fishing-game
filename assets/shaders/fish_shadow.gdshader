shader_type canvas_item;

// 水彩の世界に溶け込むリアルな水中の魚影（シルエット）シェーダー
uniform vec4 shadow_color : source_color = vec4(0.12, 0.22, 0.36, 0.72); // 水深のダークネイビー
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.35, 0.0);    // 黄金の主用の淡い光彩 (alpha 0.0 で無効)
uniform float depth_fade : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// 尾ヒレに向かって（UV.x が 0 付近、右向き魚の頭は 1.0 付近）わずかに水深の透け感を出す
	float tail_fade = mix(1.0 - depth_fade, 1.0, smoothstep(0.1, 0.8, UV.x));
	
	// 影の基本色
	vec3 base_rgb = shadow_color.rgb;
	
	// 黄金の主の淡い金色のきらめきブレンド
	if (glow_color.a > 0.0) {
		base_rgb = mix(base_rgb, glow_color.rgb, glow_color.a);
	}
	
	COLOR = vec4(base_rgb, tex.a * shadow_color.a * tail_fade);
}
