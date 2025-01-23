function http_test
    argparse 'h/help' 'n/number=' -- $argv

    if set -q _flag_help
        echo "Usage: http_test [-n number_of_requests] URL"
        echo "Tests HTTP response time for a given URL"
        echo "Options:"
        echo "  -n, --number    Number of requests to make (default: 1)"
        return 0
    end

    if test (count $argv) -eq 0
        echo "Error: URL is required"
        return 1
    end

    set -l url $argv[1]
    set -l num_requests 1
    if set -q _flag_number
        set num_requests $_flag_number
    end

    set -l format "\nTime Summary:\n"\
                  "DNS Lookup:   %{time_namelookup}s\n"\
                  "TCP Connect:  %{time_connect}s\n"\
                  "TLS Setup:    %{time_appconnect}s\n"\
                  "First Byte:   %{time_starttransfer}s\n"\
                  "Total Time:   %{time_total}s\n"\
                  "HTTP Code:    %{http_code}\n"

    for i in (seq $num_requests)
        if test $num_requests -gt 1
            echo "Request $i of $num_requests"
        end
        curl -w "$format" -o /dev/null -s $url
        if test $num_requests -gt 1
            echo "-------------------"
        end
    end
end