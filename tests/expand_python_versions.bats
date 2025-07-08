#!/usr/bin/env bats

setup() {
    expand_python_versions() {
        input_versions="$1"
        expanded_versions=""
        IFS=',' read -ra ADDR <<< "$input_versions"
        for version in "${ADDR[@]}"; do
            if [[ "$version" =~ ^([0-9]+\.[0-9]+)-([0-9]+\.[0-9]+)$ ]]; then
                start_version="${BASH_REMATCH[1]}"
                end_version="${BASH_REMATCH[2]}"
                start_minor=${start_version#*.}
                end_minor=${end_version#*.}
                for ((i=start_minor; i<=end_minor; i++)); do
                    expanded_versions+="${start_version%%.*}.$i, "
                done
            else
                expanded_versions+="$version, "
            fi
        done
        expanded_versions="${expanded_versions%, }"
        echo "$expanded_versions"
    }
}

@test "expand range" {
    run expand_python_versions "3.7-3.9"
    [ "$status" -eq 0 ]
    [ "$output" = "3.7, 3.8, 3.9" ]
}

@test "expand range and single" {
    run expand_python_versions "3.7-3.9,3.10"
    [ "$status" -eq 0 ]
    [ "$output" = "3.7, 3.8, 3.9, 3.10" ]
}

@test "preserve whitespace" {
    run expand_python_versions "3.7-3.9, 3.10"
    [ "$status" -eq 0 ]
    [ "$output" = "3.7, 3.8, 3.9,  3.10" ]
}
