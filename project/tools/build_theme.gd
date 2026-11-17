extends SceneTree

## Regenerates res://assets/ui/scroll_ink_theme.tres from the design tokens.
##   Godot --headless --path project --script res://tools/build_theme.gd

const UITheme = preload("res://scripts/ui/kit/ui_theme.gd")
const OUT := "res://assets/ui/scroll_ink_theme.tres"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	var th: Theme = UITheme.build()
	var err := ResourceSaver.save(th, OUT)
	print("[build_theme] %s -> %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)
