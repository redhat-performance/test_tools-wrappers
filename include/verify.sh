csv_to_json() {
    "${TOOLS_BIN}/csv_to_json" $to_json_flags "$@"
}

verify_results() {
    "${TOOLS_BIN}/verfiy_results" $to_verify_flags "$@"
}
