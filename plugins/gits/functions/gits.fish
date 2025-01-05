function gits --description 'Git repository utilities for maintenance and analysis'
    if test (count $argv) -eq 0
        echo "Usage: gits <command>"
        echo "Commands:"
        echo "  info       - Show repository object count and size info"
        echo "  top10      - List 10 largest objects in repository"
        echo "  clean      - Run garbage collection"
        echo "  cleandeep  - Run aggressive garbage collection"
        echo "  cleanreflog   - Clean reflog"
        echo "  space      - Show space usage of tracked files"
        return 1
    end

    set -l cmd $argv[1]
    switch $cmd
        case info
            git count-objects -v
        case top10
            git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | sort -k3nr | head -n 10
        case clean
            git gc --prune=now
        case cleandeep
            git gc --aggressive --prune=now
        case cleanreflog
            git reflog expire --expire=now --all
        case space
            git ls-files | xargs du -ch
            du -sh .git
        case '*'
            echo "Unknown command: $cmd"
            return 1
    end
end
