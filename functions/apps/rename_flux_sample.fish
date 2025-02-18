function rename_by_hash
    set -l txt_file $argv[1]
    set -l jpeg_file $argv[2]
    
    if test ! -f $txt_file; or test ! -f $jpeg_file
        echo "Usage: rename_by_hash text_file jpeg_file"
        return 1
    end
    
    if set -l md5sum (md5 $txt_file | awk '{print $NF}')
        and set -l timestamp (gstat --format=%W $jpeg_file)
        mv $jpeg_file "$md5sum.t$timestamp.jpeg"
        and mv $txt_file "$md5sum.txt"
        echo "Files renamed successfully"
    else
        echo "Error occurred during renaming"
        return 1
    end
end
