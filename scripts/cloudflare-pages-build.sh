#!/usr/bin/env bash
set -euo pipefail

bash "$(cd "$(dirname "$0")" && pwd)/build-web-export.sh"
