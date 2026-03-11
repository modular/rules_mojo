from std.python import Python
from std.testing import assert_equal
import std.os
import std.subprocess

def test_basic_numpy_example() raises:
    var np = Python.import_module("numpy")
    var array = np.array(
        Python.list(
            Python.list(1, 2, 3),
            Python.list(4, 5, 6)
        )
    )
    assert_equal(String(array.shape), "(2, 3)")


def main() raises:
    test_basic_numpy_example()
