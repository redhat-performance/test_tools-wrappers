import pytest
import tempfile

from pathlib import Path

from .util import run_script

DETECT_OS_SCRIPT="./detect_os"

def create_os_release_file(os_name: str, os_version: str, dest: Path):
    dest.write_text(
    f"""
        NAME="{os_name} Linux"
        VERSION_ID={os_version}
        ID={os_name}
        VERSION_CODE_NAME=""
    """
    )
    

def test_detect_os_invalid_opts():
    stdout, stderr, rtc = run_script([DETECT_OS_SCRIPT, "--invalid"])
    assert rtc != 0

@pytest.mark.parametrize("flag", ["--help", "--usage", "-h"])
def test_detect_os_help(flag):
    stdout, stderr, rtc = run_script([DETECT_OS_SCRIPT, flag])
    print(rtc)
    assert rtc == 0

@pytest.mark.parametrize("name", ["sles", "rhel", "fedora", "ubuntu", "amzn"])
def test_detect_os_name(name: str, tmp_path):
    d = tmp_path / f"os-release"
    create_os_release_file(name, "42", d)
    stdout, stderr, rtc = run_script([DETECT_OS_SCRIPT, "--os-release-file", d])
    assert rtc == 0
    assert stdout.decode('utf-8').strip() == name
