import pytest

from .util import run_script

DETECT_OS_SCRIPT="./detect_os"

def test_detect_os_invalid_opts():
    stdout, stderr, rtc = run_script([DETECT_OS_SCRIPT, "--invalid"])
    assert rtc != 0

@pytest.mark.parametrize("flag", ["--help", "--usage", "-h"])
def test_detect_os_help(flag):
    stdout, stderr, rtc = run_script([DETECT_OS_SCRIPT, flag])
    print(rtc)
    assert rtc == 0
