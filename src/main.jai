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

current_dt: float = 0.016667;
last_time: float64;
DT_MAX :: 0.15;

main :: () {
    random_seed(xx,force current_time_consensus());

    window_width = playfield_width;
    window_height = playfield_height;

    last_time = seconds_since_init();

    window := create_window(window_width, window_height, "Bucket Game");
    Simp.set_render_target(window);

    load_assets();
    resize_playfield();

    entity_manager: Entity_Manager;

    player := entity_create(*entity_manager, .PLAYER);
    assert(player.allocated);
    entity_manager.player_handle = player.handle;

    while !should_quit_game {
        reset_temporary_storage();

        { // Calculate current delta time
            now := seconds_since_init();
            delta := now - last_time;
            current_dt = delta.(float);

            if current_dt > DT_MAX then current_dt = DT_MAX;
            last_time = now;
        }

        handle_events(window);
        update(*entity_manager);
        draw(*entity_manager);
        Simp.swap_buffers(window);
    }
}

DROP_TIMER_MAX :: 0.5;
drop_timer := DROP_TIMER_MAX;

update :: (using manager: *Entity_Manager) {
    drop_timer -= current_dt;
    if drop_timer < 0 {
        entity_create(manager, .DROP);
        drop_timer = DROP_TIMER_MAX;
    }

    for *entity: entities {
        if !entity.allocated continue;
        if entity.kind == {
          case .PLAYER;
            player_update(entity);
          case .DROP;
            drop_update(entity, manager);
        }
        if entity.has_physics {
            entity.position += entity.velocity * current_dt;
        }
    }
}

player_update :: (using entity: *Entity) {
    if key_left  then position.x -= .5 * current_dt;
    if key_right then position.x += .5 * current_dt;
    half := size.x/2;
    Clamp(*position.x, half, 1 - half);
}

drop_update :: (using entity: *Entity, manager: *Entity_Manager) {
    player := find(manager, manager.player_handle);
    if player.allocated {
        intersect := is_intersecting(entity, player);
        if intersect then entity_destroy(entity);
    }

    if position.y < -size.y {
        entity_destroy(entity);
    }
}

handle_events :: (window: Window_Type) {
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

#load "draw.jai";
#load "entity_manager.jai";

#import "File";
#import "Math";
#import "Basic";
#import "Input";
#import "String";
#import "Random";
#import "System";
#import "Sloppy_Math";
#import "Window_Creation";

Simp   :: #import "Simp";

Texture :: Simp.Texture;