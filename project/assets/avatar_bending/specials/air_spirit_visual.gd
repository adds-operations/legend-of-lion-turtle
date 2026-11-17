class_name AirSpiritVisual
extends RefCounted
## One helper per fighter. Drive it from confirmed cast state.

const SPIRIT_SHADER := preload("res://assets/avatar_bending/specials/air_spirit.gdshader")

var _body: CanvasItem
var _previous_material: Material
var _material: ShaderMaterial

func update(body: CanvasItem, original_element: StringName, equipped_special: StringName, spirit_active: bool) -> void:
    var eligible := original_element == &"air" and equipped_special == &"spirit_form"
    if not eligible or not spirit_active or not is_instance_valid(body):
        clear()
        return
    if _body == body:
        return
    clear()
    _body = body
    _previous_material = body.material
    _material = ShaderMaterial.new()
    _material.shader = SPIRIT_SHADER
    body.material = _material

func clear() -> void:
    if is_instance_valid(_body) and _body.material == _material:
        _body.material = _previous_material
    _body = null
    _previous_material = null
    _material = null
