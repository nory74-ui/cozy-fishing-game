shader_type canvas_item;

// オクトパストラベラー風 HD-2D ティルトシフト（被写界深度 DoF）シェーダー
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.4;
uniform float focus_center : hint_range(0.0, 1.0) = 0.52; // ピントが合う垂直位置（プレイヤー付近）
uniform float focus_width : hint_range(0.0, 1.0) = 0.22;  // ピントが合っている領域の幅
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// ピント中心からの垂直距離
	float dist = abs(uv.y - focus_center);
	float blur_factor = smoothstep(focus_width * 0.5, focus_width * 1.5, dist);
	
	vec4 color = vec4(0.0);
	float total = 0.0;
	float radius = blur_factor * blur_amount;

	// ガウシアンブラーサンプリング
	for (float x = -2.0; x <= 2.0; x += 1.0) {
		for (float y = -2.0; y <= 2.0; y += 1.0) {
			vec2 offset = vec2(x, y) * radius * SCREEN_PIXEL_SIZE;
			float weight = exp(-(x * x + y * y) / 4.0);
			color += texture(screen_texture, uv + offset) * weight;
			total += weight;
		}
	}
	color /= total;

	// 周辺減光（ビネット）で劇場のジオラマ感を強調
	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vig = vig_uv.x * vig_uv.y * 15.0;
	vig = clamp(pow(vig, vignette_strength), 0.0, 1.0);
	
	COLOR = color * vig;
}
