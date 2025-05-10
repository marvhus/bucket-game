OUTPUT_PATH         :: "bin";
INTERMEDIATE_PATH   :: ".build";
EXE_NAME            :: "bucket-game";
ASSETS_PACKAGE_NAME :: "assets.package";

#run,stallable {
    set_build_options_dc(.{ do_output = false });

    args := get_build_options().compile_time_command_line;

    no_package := array_find(args, "no-package");
    no_build   := array_find(args, "no-build");
    do_run     := array_find(args, "run");


    if no_package == false
    && package_assets() == false {
        compiler_set_workspace_status(.FAILED);
        return;
    }
    if no_build == false
    && build() == false {
        compiler_set_workspace_status(.FAILED);
        return;
    }

    if do_run == true
    && run() == false {
        compiler_set_workspace_status(.FAILED);
        return;
    }
}

run :: () -> success: bool {
    log("\n==== Running ====\n");

    command := tprint("./%", EXE_NAME);
    result := run_command(command, working_directory = OUTPUT_PATH, print_captured_output = true);

    return result.exit_code == 0;
}

package_assets :: () -> success: bool {
    log("\n==== Packaging ====\n");

    // @TODO(mvh): Figure out this dynamically.
    files := string.[
        "res/background.png",
        "res/bucket.png",
        "res/drop.png",
    ];

    package: Create_Package;

    init(*package);
    defer deinit(*package);

    for file_path: files {
        content, success := read_entire_file(file_path);
        if success == false {
            log_error("Aborting assets packaging.\n");
            return false;
        }

        log("Adding '%'\n", file_path);
        add(*package, file_path, xx content);
    }

    package_path := tprint("%/%", OUTPUT_PATH, ASSETS_PACKAGE_NAME);
    log("Saving to '%'\n", package_path);
    return write(*package, package_path);
}

build :: () -> success: bool {
    log("\n==== Building ====\n");

    workspace := compiler_create_workspace("Dani Jam 2025");
    if !workspace {
        log_error("Failed to create workspace.\n");
        return false;
    }

    // Set up output path
    make_directory_if_it_does_not_exist(OUTPUT_PATH);
    if !write_entire_file(tprint("%/.gitignore", OUTPUT_PATH), "*\n") {
        log_error("Unable to create .gitignore file for ./%\n", OUTPUT_PATH);
    }

    // Set up intermediate path
    make_directory_if_it_does_not_exist(INTERMEDIATE_PATH);
    if !write_entire_file(tprint("%/.gitignore", INTERMEDIATE_PATH), "*\n") {
        log_error("Unable to create .gitignore file for ./%\n", INTERMEDIATE_PATH);
    }

    { // Set build options.
        opts := get_build_options(workspace);

        { // Tell linker to link math.h
            args: [..]string;
            array_add(*args, ..opts.additional_linker_arguments);
            array_add(*args, "-lm");
            opts.additional_linker_arguments = args;
        }

        ////////////////////////
        //////// Release ///////
        //set_optimization(*opts, .OPTIMIZED);
        //opts.backend = .LLVM;
        ///////// Debug ////////
        set_optimization(*opts, .DEBUG);
        opts.backend = .X64;
        ////////////////////////

        opts.text_output_flags = .OUTPUT_TIMING_INFO;

        opts.output_path = OUTPUT_PATH;
        opts.output_executable_name = EXE_NAME;

        opts.intermediate_path = INTERMEDIATE_PATH;

        set_build_options(opts, workspace);
    }

    { // Hook into compiler message loop to see if the build fails.
        compiler_begin_intercept(workspace);
        add_build_file("src/main.jai", workspace);
        add_build_string(tprint("ASSETS_PACKAGE_NAME :: \"%\";", ASSETS_PACKAGE_NAME), workspace);

        success := true;
        while success {
            message := compiler_wait_for_message();
            if message.kind == {
                case .COMPLETE;
                    break;
                case .ERROR;
                    log_error("Failed during compile\n");
                    success = false;
            }
        }

        compiler_end_intercept(workspace);
        return success;
    }
}

#import "File";
#import "Basic";
#import "Process";
#import "Compiler";
#import "Simple_Package";
