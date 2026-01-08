from typing import List
import subprocess

"""
Runs a specified script and returns (in order)
Stdout from the process
stderr from the process
Return code of the process
"""
def run_script(path: List[str]) -> (str, str, int):
    proc = subprocess.Popen(path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    proc.wait()

    stdout = proc.stdout.read().strip()
    stderr = proc.stderr.read().strip()
    rtc = proc.returncode

    return stdout.decode('utf-8'), stderr.decode('utf-8'), rtc
