#!/bin/bash -eu

set -o pipefail

output="$($1)"
[[ "${output}" == "Compiled with compiler: "*rustc* ]] || { echo >&2 "Unexpected output: ${output}"; exit 1;}
