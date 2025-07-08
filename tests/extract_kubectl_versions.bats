#!/usr/bin/env bats

setup() {
    extract_kubectl_versions() {
        FILE_PATH=$1
        if yq e 'has("kubectl_checksums.amd64")' $FILE_PATH > /dev/null && \
           yq e '.kubectl_checksums.amd64 != null' $FILE_PATH > /dev/null && \
           yq e '.kubectl_checksums.amd64 | type' $FILE_PATH | grep -q "map"; then
            yq e '.kubectl_checksums.amd64 | keys | .[]' $FILE_PATH | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g'
        else
            echo ""
        fi
    }
}

@test "extract kubectl versions" {
    cat <<'YML' > tmp.yml
kubectl_checksums:
  amd64:
    v1.19.0: foo
    v1.20.0: bar
YML
    run extract_kubectl_versions tmp.yml
    [ "$status" -eq 0 ]
    [ "$output" = "v1.19.0, v1.20.0" ]
    rm tmp.yml
}

@test "missing section returns empty" {
    cat <<'YML' > tmp.yml
other: value
YML
    run extract_kubectl_versions tmp.yml
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm tmp.yml
}
