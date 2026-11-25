extends SceneTree
## Renders icon.svg (the Dragon Hand emblem over its static frame) to the boot
## splash image. Rerun after changing icon.svg or assets/ui/dragon_emblem.svg,
## then `--import`:
##   godot --headless --script res://tools/render_boot_splash.gd

const ICON := "res://icon.svg"
const OUT := "res://assets/boot_splash.png"
## Splash side in pixels (icon.svg is 128 px wide).
const SIDE := 256
const ICON_SIDE := 128.0


func _init() -> void:
	var svg := FileAccess.get_file_as_string(ICON)
	var img := Image.new()
	var err := img.load_svg_from_string(svg, SIDE / ICON_SIDE)
	if err != OK:
		printerr("cannot render %s: %s" % [ICON, error_string(err)])
		quit(1)
		return
	err = img.save_png(ProjectSettings.globalize_path(OUT))
	if err != OK:
		printerr("cannot write %s: %s" % [OUT, error_string(err)])
		quit(1)
		return
	print("wrote %s (%dx%d)" % [OUT, img.get_width(), img.get_height()])
	quit(0)
