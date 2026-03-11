from std.python import Python
from std.os import getenv
from std.testing import assert_true

def main() raises:
    sys = Python.import_module("sys")
    print("Python executable:", sys.executable)
    print("Python version:", sys.version)
    assert_true(sys.version.startswith(getenv("EXPECTED_PYTHON_VERSION")))
    assert_true(not sys.executable.startswith("/usr"))
    assert_true(not sys.executable.startswith("/bin"))
