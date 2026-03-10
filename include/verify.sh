#!/bin/bash

setup_verification() {
	# Ubuntu started shipping with their python3-typing extensions
	# which is too old for pydantic and should be installed via pip so it needs to be removed
	package_tool --remove_packages python3-typing-extensions
	package_tool --wrapper_config ${TOOLS_BIN}/deps/verification.json
}
