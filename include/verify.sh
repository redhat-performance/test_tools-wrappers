#!/bin/bash

setup_verification() {
    os=$("$TOOLS_BIN"/detect_os)
    install_flags=""

    # Ubuntu started shipping with their python3-typing extensions
    # which is too old for pydantic and should be installed via pip so it needs to be removed
    if [[ "$os" == "ubuntu" ]]; then
        #Don't care if this fails, since then it means that it wasn't installed to begin with
        package_tool --remove_packages python3-typing-extensions &> /dev/null
    elif [[ "$os" == "sles" ]]; then
        # SLES's default python interpreter is python 3.6, which is too old for
        # pydantic 2.0.0+, so we need a newer intepreter
        install_flags="--python_exec python3.11"
    fi

	package_tool --wrapper_config ${TOOLS_BIN}/deps/verification.json $install_flags
}

verify_results() {
    cmd="python3"
    os=$("$TOOLS_BIN"/detect_os)
    
    if [[ "$os" == "sles" ]]; then
        cmd="python3.11"
    fi

    $cmd "$TOOLS_BIN/verify_results" $to_verify_flags "$@"
}
