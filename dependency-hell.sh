#!/bin/bash

# Ensure yq is installed
if ! command -v yq &> /dev/null
then
    echo "yq could not be found. Please install it first."
    exit
fi

# Initialize optional parameters
DESIRED_K8S_VERSION=""
DESIRED_PYTHON_VERSION=""

# Extract the versions from the Python version support
expand_python_versions() {
    input_versions="$1"
    expanded_versions=""

    # Convert comma-separated string to array
    IFS=',' read -ra ADDR <<< "$input_versions"

    for version in "${ADDR[@]}"; do
        # Check if it's a range or a single version
        if [[ "$version" =~ ^([0-9]+\.[0-9]+)-([0-9]+\.[0-9]+)$ ]]; then
            start_version="${BASH_REMATCH[1]}"
            end_version="${BASH_REMATCH[2]}"
            start_minor=${start_version#*.}
            end_minor=${end_version#*.}
            for ((i=start_minor; i<=end_minor; i++)); do
                expanded_versions+="${start_version%%.*}.$i, "
            done
        else
            # It's a single version, add it as is
            expanded_versions+="$version, "
        fi
    done

    # Remove the trailing comma and space
    expanded_versions="${expanded_versions%, }"

    echo "$expanded_versions"
}

# Function to extract kubectl versions
    extract_kubectl_versions() {
        FILE_PATH=$1

        if yq e 'has("kubectl_checksums.amd64")' "$FILE_PATH" > /dev/null && \
           yq e '.kubectl_checksums.amd64 != null' "$FILE_PATH" > /dev/null && \
           yq e '.kubectl_checksums.amd64 | type' "$FILE_PATH" | grep -q "map"; then
            yq e '.kubectl_checksums.amd64 | keys | .[]' "$FILE_PATH" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g'
        else
            echo ""
        fi
    }

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --k8s-version)
        DESIRED_K8S_VERSION="$2"
        shift
        shift
        ;;
        --python-version)
        DESIRED_PYTHON_VERSION="$2"
        shift
        shift
        ;;
        *)
        echo "Unknown argument: $key"
        exit 1
        ;;
    esac
done

# Clone the kubespray repo
if [ ! -d "kubespray" ]; then
    git clone https://github.com/kubernetes-sigs/kubespray.git > /dev/null 2>&1
fi

# Path to the local clone of the kubespray repository
LOCAL_REPO_PATH="./kubespray"

# Store the current directory to come back later
CURRENT_DIR=$(pwd)

# Change directory to the kubespray repo
cd "$LOCAL_REPO_PATH" || exit

# Relative paths to the checksums.yml and main.yml within the repo
CHECKSUMS_FILE_PATH="roles/download/defaults/main/checksums.yml"
MAIN_FILE_PATH="roles/download/defaults/main.yml"

# Fetch all branches and populate the BRANCHES array
BRANCHES=$(git for-each-ref refs/heads/ --format='%(refname:short)')

for branch in $BRANCHES; do
    # Checkout the desired branch and suppress the output
    git checkout "$branch" > /dev/null 2>&1

    declare -a table

    # Extract information from ansible.md
    table=()
    count=1
    while IFS= read -r line; do
        count=$((count + 1))
        # Look for lines that match the pattern of the table rows
        if [[ "$line" =~ ^\|[[:space:]]*([0-9]+\.[0-9]+)[[:space:]]*\|[[:space:]]*([0-9]+\.[0-9]+(-[0-9]+\.[0-9]+)?(,[0-9]+\.[0-9]+(-[0-9]+\.[0-9]+)?)?)[[:space:]]*\| ]]; then
            ansible_version="${BASH_REMATCH[1]}"
            python_version="${BASH_REMATCH[2]}"
            python_version_expanded=$(expand_python_versions "$python_version")
            IFS=', ' read -ra VERSION_LIST <<< "$python_version_expanded"
            
            # Filter based on desired versions
            python_match=false

            table+=("Ansible: $ansible_version")
            table+=("Python: $python_version_expanded ($python_version)")
            table+=("-")

            for version in "${VERSION_LIST[@]}"; do
                if [ "$version" == "$DESIRED_PYTHON_VERSION" ]; then
                    python_match=true
                    break 2
                fi
            done
        fi
    done < docs/ansible.md

    # If the checksums.yml file exists, parse it
    if [ -f $CHECKSUMS_FILE_PATH ]; then
        KUBECTL_VERSIONS=$(extract_kubectl_versions $CHECKSUMS_FILE_PATH)
    # Else if the main.yml file exists, parse it
    elif [ -f $MAIN_FILE_PATH ]; then
        KUBECTL_VERSIONS=$(extract_kubectl_versions $MAIN_FILE_PATH)
    else
        KUBECTL_VERSIONS=""
    fi

    # Filter based on desired versions
    k8s_match=false

    if echo "$KUBECTL_VERSIONS" | grep -q "$DESIRED_K8S_VERSION"; then
        if [ ! "$DESIRED_K8S_VERSION" == "" ]; then
            k8s_match=true
        fi
    fi

    if [ ${#table[@]} == 0 ]; then
        python_match=false
    fi

    # Evaluate and print the results
    if [ "$python_match" == true ] || [ "$k8s_match" == true ]; then
        if [ "$python_match" == true ] && [ "$k8s_match" == true ]; then
            echo "Kubespray Version (BRANCH): $branch"
            echo ""
            for row in "${table[@]}"; do
                echo "$row"
            done
            echo "Kubernetes Versions (kubectl) supported:"
            echo "$KUBECTL_VERSIONS"
            echo "-----------------------------"
        elif [ -n "$DESIRED_PYTHON_VERSION" ] && [ "$python_match" == true ] && [ -z "$DESIRED_K8S_VERSION" ]; then
            echo "Kubespray Version (BRANCH): $branch"
            echo ""
            for row in "${table[@]}"; do
                echo "$row"
            done
            if [ ! "$KUBECTL_VERSIONS" == "" ]; then
                echo "Kubernetes Versions (kubectl) supported:"
                echo "$KUBECTL_VERSIONS"
            fi
            echo "-----------------------------"
        elif [ -n "$DESIRED_K8S_VERSION" ] && [ "$k8s_match" == true ] && [ -z "$DESIRED_PYTHON_VERSION" ]; then
            echo "Kubespray Version (BRANCH): $branch"
            echo ""
            for row in "${table[@]}"; do
                echo "$row"
            done
            echo "Kubernetes Versions (kubectl) supported:"
            echo "$KUBECTL_VERSIONS"
            echo "-----------------------------"
        fi
    elif [ -z "$DESIRED_K8S_VERSION" ] && [ -z "$DESIRED_PYTHON_VERSION" ]; then
        echo "Kubespray Version (BRANCH): $branch"
        echo ""
        for row in "${table[@]}"; do
            echo "$row"
        done
        if [ ! "$KUBECTL_VERSIONS" == "" ]; then
            echo "Kubernetes Versions (kubectl) supported:"
            echo "$KUBECTL_VERSIONS"
        fi
        echo "-----------------------------"
    fi

done

# Switch back to the original directory
cd "$CURRENT_DIR" || exit
