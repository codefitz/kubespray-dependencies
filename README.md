# Kubespray Dependencies

---

## Introduction

This script helps to extract information from the [Kubespray](https://github.com/kubernetes-sigs/kubespray) repository regarding Ansible, Python, and Kubernetes (kubectl) versions supported in each branch. The information is extracted from the `ansible.md` file (found at `docs/ansible.md` or `docs/ansible/ansible.md`)  and the relevant YML files in the repository.

## Prerequisites

- Bash shell
- [yq](https://github.com/mikefarah/yq) - A portable command-line YAML processor.
- git

## Installation

1. Ensure you have `yq` installed. If not, you can get it [here](https://github.com/mikefarah/yq) or install using `apt`.
2. Clone this repository or copy the script.

## Usage

```bash
chmod +x dependency-hell.sh
./dependency-hell.sh [--k8s-version desired_k8s_version] [--python-version desired_python_version]
```

### Options:

- `--k8s-version`: Extract branches that support a specific Kubernetes version.
- `--python-version`: Extract branches that support a specific Python version.

For instance, to find out which branches support Kubernetes v1.20.7 and Python 3.8:

```bash
./dependency-hell.sh --k8s-version v1.20.7 --python-version 3.8
```

## Examples

1. Extracting versions without any filters:

    ```bash
    ./dependency-hell.sh
    ```

2. Extracting branches that support Kubernetes version `v1.20.7`:

    ```bash
    ./dependency-hell.sh --k8s-version v1.20.7
    ```

3. Extracting branches that support Python version `3.8`:

    ```bash
    ./dependency-hell.sh --python-version 3.8
    ```

## How It Works

The script operates as follows:

1. It checks for the installation of `yq`.
2. The desired Kubernetes and/or Python version to filter are specified through the command-line options.
3. The Kubespray repository is cloned (if not already present).
4. The script traverses through each branch, reading from the `ansible.md` file located at `docs/ansible.md` or `docs/ansible/ansible.md`.
5. Relevant information is extracted and displayed based on the provided filters.