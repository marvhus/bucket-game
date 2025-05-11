ASPECT  :: (800. / 500.);
VPIXELS :: 1000;

playfield_width  := (VPIXELS * ASPECT).(s32);
playfield_height := VPIXELS.(s32);

window_width, window_height: s32;
window_aspect := ASPECT;

should_quit_game := false;

key_up:     bool;
key_down:   bool;
key_left:   bool;
key_right:  bool;

drop\       _texture: Texture;
bucket\     _texture: Texture;
background\ _texture: Texture;

current_dt: float = 0.016667;
last_time: float64;
DT_MAX :: 0.15;

bucket: Bucket;
drops: [512]Drop;
drop_timer := 1.;

main :: () {
    random_seed(xx,force current_time_consensus());

    window_width = playfield_width;
    window_height = playfield_height;

    last_time = seconds_since_init();

    window := create_window(window_width, window_height, "Bucket Game");
    Simp.set_render_target(window);

    load_assets();
    resize_playfield();

    while !should_quit_game {
        reset_temporary_storage();

        update_window_events();
        for get_window_resizes() {
            Simp.update_window(it.window);
            if it.window != window then continue;
            should_reinit := (it.width != window_width) || (it.height != window_height);

            window_width  = it.width;
            window_height = it.height;

            if should_reinit then resize_playfield();
        }
        for event: events_this_frame {
            if event.type == .QUIT {
                should_quit_game = true;
                break;
            }

            if event.type == .KEYBOARD {
                key := event.key_code;
                pressed := event.key_pressed.(bool);

                if key == .ARROW_LEFT  then key_left  = pressed;
                if key == .ARROW_RIGHT then key_right = pressed;
            }
        }

        { // Calculate current delta time
            now := seconds_since_init();
            delta := now - last_time;
            current_dt = delta.(float);

            if current_dt > DT_MAX then current_dt = DT_MAX;
            last_time = now;
        }

        update(*bucket);
        update_drops();

        Simp.clear_render_target(.2, .3, .3, 1);

        playfield_p0 := window_coords_from_absolute(.{0, 0});
        playfield_p1 := window_coords_from_absolute(.{xx playfield_width, xx playfield_height});
        Simp.set_scissor(xx playfield_p0.x, xx playfield_p0.y, xx playfield_p1.x, xx playfield_p1.y);

        { // Draw background
            using Simp;
            set_shader_for_images(*background_texture);
            color := Vector4.{1,1,1,1};
            immediate_quad(playfield_p0.x, playfield_p0.y, playfield_p1.x, playfield_p1.y, color);
        }

        { // Draw bucket
            using bucket;
            color := Vector4.{1,1,1,1};
            render_sprite_quad_centered(*bucket_texture, position, size, color);
        }

        for drop: drops { // Drap drops
            using drop;
            if !active then continue;
            color := Vector4.{1,1,1,1};
            render_sprite_quad_centered(*drop_texture, position, size, color);
        }

        Simp.clear_scissor();

        Simp.swap_buffers(window);
    }
}

Bucket :: struct {
    position := Vector2.{0.5, 0.05};
    size     := Vector2.{0.075, 0.075};
}
update :: (using bucket: *Bucket) {
    if key_left  then position.x -= .5 * current_dt;
    if key_right then position.x += .5 * current_dt;
    Clamp(*position.x, 0.025, 0.975);
}
intersects_bucket :: (drop: Drop) -> bool {
    // TODO(mvh): Detect when the bucket slides into the side of the drop, rather than collecting it.
    //            Maybe this can be done through by also checking if the y pos is close to the top of the bucket.
    bucket_p0 := bucket.position - bucket.size / 2;
    bucket_p1 := bucket.position + bucket.size / 2;

    drop_p0 := drop.position - drop.size / 2;
    drop_p1 := drop.position + drop.size / 2;

    intersecting := bucket_p0.x < drop_p1.x
                 && bucket_p1.x > drop_p0.x
                 && bucket_p0.y < drop_p1.y
                 && bucket_p1.y > drop_p0.y;
    return intersecting;
}

Drop :: struct {
    active := false;
    position: Vector2;
    size := Vector2.{0.04, 0.04};
}
DROP_GRAVITY :: 0.25;
update_drops :: () {
    drop_timer -= current_dt;
    if drop_timer <= 0 {
        spawn_drop();
        drop_timer = 1;
    }

    for *drop: drops {
        using drop;
        if !active then continue;

        position.y -= DROP_GRAVITY * current_dt;
        if position.y < -size.y then active = false;

        if intersects_bucket(drop) then active = false;
    }
}
spawn_drop :: () {
    for *drop: drops {
        using drop;
        if active then continue;

        active = true;
        position.x = random_get_zero_to_one() * 0.9 + 0.05;
        position.y = 1;
        return;
    }
    assert(false, "Ran out of inactive drop entities.");
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

resize_playfield :: () {
    // If height is zero, then a division by zero might happen... not good.
    if !window_height then return;

    window_aspect = window_width / window_height.(float);

    if values_are_close(window_aspect, ASPECT) {
        // Window size is close to a scaled version of playfield.
        playfield_width  = window_width;
        playfield_height = window_height;
        return;
    }
    if window_aspect > ASPECT {
        // Window is wider than playfield aspect ratio.
        // Add verical bars to the sides.
        playfield_height = window_height;
        playfield_width  = (window_height * ASPECT).(s32);
        return;
    }
    // Window is taller than playfield apect ratio.
    // Add horizontal bars to the top and bottom.
    playfield_width  = window_width;
    playfield_height = (window_width / ASPECT).(s32);
}

// Convert from the playfield_width relative coords of entities to window coords.
window_coords_from_relative :: (v: Vector2) -> Vector2 {
    return window_coords_from_absolute(v * playfield_width.(float));
}

// Convert playfield coordinates to window coordinates.
window_coords_from_absolute :: (v: Vector2) -> Vector2 {
    result := v;

    delta: float;
    if window_aspect > ASPECT {
        delta = (window_width - playfield_width) / 2.;
        result.x += delta;
    } else {
        delta = (window_height - playfield_height) / 2.;
        result.y += delta;
    }
    assert(delta >= 0, "Negative delta (%) ????", delta);

    return result;
}

load_assets :: () {
    bin_path := path_strip_filename(get_path_of_running_executable());
    package_path := tprint("%/%", bin_path, ASSETS_PACKAGE_NAME);

    package: Load_Package;
    if init_from_file(*package, package_path) == false {
        log_error("Failed to load the assets package.\n");
        exit(1);
    }

    load_texure :: (lookup: type_of(package.lookup), name: string) -> Texture {
        entry, success := table_find(*lookup, name);
        assert(success, tprint("Unable to find texture % in package", name));

        result: Texture;
        success = Simp.texture_load_from_memory(*result, entry.data);
        assert(success, tprint("Unable to load texture %", name));

        return result;
    }

    drop\       _texture = load_texure(package.lookup, "res/drop.png");
    bucket\     _texture = load_texure(package.lookup, "res/bucket.png");
    background\ _texture = load_texure(package.lookup, "res/background.png");
}

#import "File";
#import "Math";
#import "Basic";
#import "Input";
#import "String";
#import "Random";
#import "System";
#import "Hash_Table";
#import "Sloppy_Math";
#import "Simple_Package";
#import "Window_Creation";

Simp   :: #import "Simp";

Texture :: Simp.Texture;