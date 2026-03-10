#!/bin/bash

setup_verification() {
    os=$("$TOOLS_BIN"/detect_os)

    # Ubuntu started shipping with their python3-typing extensions
    # which is too old for pydantic and should be installed via pip so it needs to be removed
    if [[ "$os" == "ubuntu" ]]; then
        #Don't care if this fails, since then it means that it wasn't installed to begin with
        package_tool --remove_packages python3-typing-extensions &> /dev/null
    fi
	package_tool --wrapper_config ${TOOLS_BIN}/deps/verification.json
}

verify_results() {
    "$TOOLS_BIN/verify_results" $to_verify_flags "$@"
}
