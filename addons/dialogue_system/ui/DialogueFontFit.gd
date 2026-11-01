extends RefCounted
## Measure full BBCode before typing, keeping a stable size throughout the line.

const FONT_SIZES := ["normal_font_size", "bold_font_size", "italics_font_size",
	"bold_italics_font_size", "mono_font_size"]


static func fit(label: RichTextLabel, content: String, maximum: int, minimum := 12) -> void:
	if label.size.x <= 1.0 or label.size.y <= 1.0:
		return
	var previous_text := label.text
	var previous_visible := label.visible_characters
	label.visible_characters = -1
	label.text = content
	label.fit_content = false
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var low := minimum
	var high := maxi(maximum, minimum)
	var best := minimum
	var padding := label.get_theme_constant("outline_size") * 2 + 4
	while low <= high:
		var candidate := (low + high) / 2
		for font_size in FONT_SIZES:
			label.add_theme_font_size_override(font_size, candidate)
		if label.get_content_height() <= label.size.y - padding and label.get_content_width() <= label.size.x:
			best = candidate
			low = candidate + 1
		else:
			high = candidate - 1
	for font_size in FONT_SIZES:
		label.add_theme_font_size_override(font_size, best)
	label.text = previous_text
	label.visible_characters = previous_visible
