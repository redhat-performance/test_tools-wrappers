import pytest

from .util import run_script

TARGET_SCRIPT="./convert_val"

@pytest.mark.parametrize("duration,unit,expected", [
        (1, 'h', '3600s'),
        (2, 'h', '7200s'),
        (1, 'm', '60s'),
        (5, 'm', '300s'),
        (90, 's', '90s')
    ])
def test_cvt_seconds(duration: int, unit: str, expected: str):
    stdout, stderr, rtc = run_script([
        TARGET_SCRIPT,
        "--time_val",
        "--from_unit",
        unit,
        "--to_unit", "s",
        "--value",
        str(duration)
    ])

    assert rtc == 0
    assert stdout == expected
