extends Node

## Small local settings store (user://settings.cfg): remembered name and
## the last host IP you joined, so reconnecting is one click.

const PATH := "user://settings.cfg"

var player_name: String = ""
var last_ip: String = ""
var last_port: int = 7777
var last_arena: String = ""
var last_fighter: String = ""   # training: the bender you last trained with
var last_build: Dictionary = {"atk": 0, "def": 0, "mob": 0}  # build stats (the signature comes with the bender)
## Auto-aim: every power is aimed at the rival; the arrows only move and dodge.
## Toggled from the in-game menu (Esc). SHIFT still aims by hand while held.
var auto_aim: bool = true

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		player_name = cfg.get_value("player", "name", "")
		last_ip = cfg.get_value("network", "last_ip", "")
		last_port = cfg.get_value("network", "last_port", 7777)
		last_arena = cfg.get_value("match", "arena", "")
		last_fighter = cfg.get_value("training", "fighter", "")
		last_build = cfg.get_value("build", "build", last_build)
		auto_aim = cfg.get_value("controls", "auto_aim", true)
	if player_name.strip_edges() == "":
		player_name = _default_name()

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("network", "last_ip", last_ip)
	cfg.set_value("network", "last_port", last_port)
	cfg.set_value("match", "arena", last_arena)
	cfg.set_value("training", "fighter", last_fighter)
	cfg.set_value("build", "build", last_build)
	cfg.set_value("controls", "auto_aim", auto_aim)
	cfg.save(PATH)

static func clean_name(n: String) -> String:
	var s := n.strip_edges().replace("\n", " ")
	return s.substr(0, 16) if s != "" else "Bender"

func _default_name() -> String:
	var user := OS.get_environment("USER")
	if user != "":
		return clean_name(user.capitalize())
	return "Bender"
