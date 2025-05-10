window_width  := 800;
window_height := 500;

should_quit_game := false;

drop\       _texture: Texture;
bucket\     _texture: Texture;
background\ _texture: Texture;

key_up:     bool;
key_down:   bool;
key_left:   bool;
key_right:  bool;

bucket_pos := Vector2.{x = #run xx window_width / 2.0, y = 20};

main :: () {
    window := create_window(window_width, window_height, "Bucket Game");
    Simp.set_render_target(window);

    load_assets();

    while !should_quit_game {
        reset_temporary_storage();

        update_window_events();
        for get_window_resizes() {
            Simp.update_window(it.window);
            if it.window != window then continue;

            window_width  = it.width;
            window_height = it.height;
        }
        for event: events_this_frame {
            if event.type == .QUIT {
                should_quit_game = true;
                break;
            }

            if event.type == .KEYBOARD {
                key := event.key_code;

                if key == .ARROW_LEFT   then key_left   = xx event.key_pressed;
                if key == .ARROW_RIGHT  then key_right  = xx event.key_pressed;
            }
        }

        if key_left     then bucket_pos.x -= 10;
        if key_right    then bucket_pos.x += 10;

        Simp.clear_render_target(.2, .3, .3, 1);

        Simp.set_shader_for_images(*bucket_texture);
        Simp.immediate_quad(bucket_pos.x, bucket_pos.y, bucket_pos.x + 50, bucket_pos.y + 50, Vector4.{1,1,1,1});

        Simp.swap_buffers(window);
    }
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
#import "System";
#import "Hash_Table";
#import "Simple_Package";
#import "Window_Creation";

Simp   :: #import "Simp";

Texture :: Simp.Texture;