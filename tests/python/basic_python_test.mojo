from python import Python
from testing import assert_true

def main():
    sys = Python.import_module("sys")
    print("Python executable:", sys.executable)
    assert_true(not sys.executable.startswith("/usr"))
