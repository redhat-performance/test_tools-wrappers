import pytest
import tempfile

from pathlib import Path

from .util import run_script

DETECT_OS_SCRIPT="./detect_os"

def create_os_release_file(dest: Path, os_name: str = "fedora", os_version: str = "43"):
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
    create_os_release_file(d, name)
    stdout, stderr, rtc = run_script([DETECT_OS_SCRIPT, "--os-release-file", d])
    assert rtc == 0
    assert stdout.decode('utf-8').strip() == name

@pytest.mark.parametrize("version", ["43", "22.04", "24.04", "9.6", "2023", "15.7"])
def test_detect_os_version(version: str, tmp_path):
    d = tmp_path / f"os-release"
    create_os_release_file(d, os_version=version)
    stdout, stderr, rtc = run_script([
        DETECT_OS_SCRIPT,
        "--os-release-file",
        d,
        "--os-version"
    ])

    assert rtc == 0
    assert stdout.decode('utf-8').strip() == version

@pytest.mark.parametrize("version", ["22.04", "24.04", "9.6", "15.7"])
def test_detect_os_major_version(version: str, tmp_path):
    d = tmp_path / f"os-release"
    create_os_release_file(d, os_version=version)
    stdout, stderr, rtc = run_script([
        DETECT_OS_SCRIPT,
        "--os-release-file",
        d,
        "--os-version",
        "--major-version"
    ])

    assert rtc == 0
    assert stdout.decode('utf-8').strip() == version.split('.')[0]

@pytest.mark.parametrize("version", ["22.04", "24.04", "9.6", "15.7"])
def test_detect_os_minor_version(version: str, tmp_path):
    d = tmp_path / f"os-release"
    create_os_release_file(d, os_version=version)
    stdout, stderr, rtc = run_script([
        DETECT_OS_SCRIPT,
        "--os-release-file",
        d,
        "--os-version",
        "--minor-version"
    ])

    assert rtc == 0
    assert stdout.decode('utf-8').strip() == version.split('.')[1]

@pytest.mark.parametrize("version,delim", [("2:9", ":"), ("89/2", "/")])
def test_detect_os_vers_sep(version: str, delim: str, tmp_path):
    d = tmp_path / f"os-release"
    create_os_release_file(d, os_version=version)
    stdout_major, stderr_major, rtc_major = run_script([
        DETECT_OS_SCRIPT,
        "--os-release-file",
        d,
        "--os-version",
        "--major-version",
        "--version-separator",
        delim
    ])

    assert rtc_major == 0
    assert stdout_major.decode('utf-8').strip() == version.split(delim)[0]

    stdout_minor, stderr_minor, rtc_minor = run_script([
        DETECT_OS_SCRIPT,
        "--os-release-file",
        d,
        "--os-version",
        "--minor-version",
        "--version-separator",
        delim
    ])

    assert rtc_minor == 0
    assert stdout_minor.decode('utf-8').strip() == version.split(delim)[1]
