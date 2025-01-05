function lnabs --description 'Create symbolic link with absolute path'
    if test (count $argv) -ne 2
        echo "Usage: lnabs SOURCE TARGET"
        echo "Creates a symbolic link using absolute path of the source"
        return 1
    end

    set -l src $argv[1]
    set -l target $argv[2]

    # Convert source to absolute path
    set -l abs_src (realpath $src)
    if test $status -ne 0
        echo "Error: Could not resolve absolute path for '$src'"
        return 1
    end

    # Create symbolic link
    ln -s $abs_src $target
    if test $status -ne 0
        echo "Error: Failed to create symbolic link"
        return 1
    end

    echo "Created symbolic link:"
    echo "Source (absolute): $abs_src"
    echo "Target: $target"
end