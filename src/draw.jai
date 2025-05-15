drop\       _texture: Texture;
bucket\     _texture: Texture;
background\ _texture: Texture;

load_assets :: () {
    bin_path := path_strip_filename(get_path_of_running_executable());

    load_texure :: (bin_path: string, name: string) -> Texture {
        result: Texture;
        success := Simp.texture_load_from_file(*result, tprint("%/%", bin_path, name));
        assert(success, "Unable to load texture %", name);

        return result;
    }

    drop\       _texture = load_texure(bin_path, "data/drop.png");
    bucket\     _texture = load_texure(bin_path, "data/bucket.png");
    background\ _texture = load_texure(bin_path, "data/background.png");
}

draw :: (manager: *Entity_Manager) {
    Simp.clear_render_target(.2, .3, .3, 1);

    playfield_p0 := window_coords_from_absolute(.{0, 0});
    playfield_p1 := window_coords_from_absolute(.{xx playfield_width, xx playfield_height});
    Simp.set_scissor(xx playfield_p0.x, xx playfield_p0.y, xx playfield_p1.x, xx playfield_p1.y);

    { // Draw background.
        using Simp;
        set_shader_for_images(*background_texture);
        color := Vector4.{1,1,1,1};
        immediate_quad(playfield_p0.x, playfield_p0.y, playfield_p1.x, playfield_p1.y, color);
    }

    entities_draw(manager);

    Simp.clear_scissor();
}

#scope_file

entities_draw :: (using manager: *Entity_Manager) {
    for entity: entities {
        if !entity.allocated continue;
        if !entity.is_visible continue;
        if entity.kind == {
          case .PLAYER;
            player_draw(entity);
          case .DROP;
            player_draw(entity);
        }
    }
}

player_draw :: (using entity: Entity) {
    color :: Vector4.{1,1,1,1};
    render_sprite_quad_centered(texture, position, size, color);
}

drop_draw :: (using entity: Entity) {
    color :: Vector4.{1,1,1,1};
    render_sprite_quad_centered(*drop_texture, position, size, color);
}

render_sprite_quad_centered :: (texture: *Texture, _pos: Vector2, size: Vector2, color: Vector4) {
    using Simp;
    set_shader_for_images(texture);

    pos := window_coords_from_relative(_pos);
    h := Vector2.{size.x * .5 * playfield_width, 0                            };
    v := Vector2.{0                            , size.y * .5 * playfield_width};

    p0 := pos - h - v;
    p1 := pos + h - v;
    p2 := pos + h + v;
    p3 := pos - h + v;

    immediate_quad(p0, p1, p2, p3, color);
}
