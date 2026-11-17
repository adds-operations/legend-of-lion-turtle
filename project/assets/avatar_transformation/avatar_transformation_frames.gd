class_name AvatarTransformationFrames
extends RefCounted

## Produces a fighter-local resource so the character pack remains reusable.
static func combine(base: SpriteFrames, transformation: SpriteFrames) -> SpriteFrames:
    var result := base.duplicate() as SpriteFrames
    for animation in transformation.get_animation_names():
        if result.has_animation(animation):
            result.remove_animation(animation)
        result.add_animation(animation)
        result.set_animation_speed(animation, transformation.get_animation_speed(animation))
        result.set_animation_loop(animation, transformation.get_animation_loop(animation))
        for index in range(transformation.get_frame_count(animation)):
            result.add_frame(
                animation,
                transformation.get_frame_texture(animation, index),
                transformation.get_frame_duration(animation, index)
            )
    return result
