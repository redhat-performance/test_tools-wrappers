setup_verification() {
    # Remove typing extensions, as the version is usually too old
    # and cause problems when installing pydantic.
    # Ubuntu AMIs have started to include this package
    package_tool --remove_packages python3-typing-extensions \ 
        --wrapper_config "${TOOLS_BIN}/deps/verification.json" 2> /dev/null
}

csv_to_json() {
    "${TOOLS_BIN}/csv_to_json" $to_json_flags "$@"
}

verify_results() {
    "${TOOLS_BIN}/verfiy_results" $to_verify_flags "$@"
}
