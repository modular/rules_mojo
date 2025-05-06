from python import Python
from testing import assert_equal
import os
import subprocess

def test_basic_numpy_example():
    var np = Python.import_module("numpy")
    var array = np.array(
        Python.list(
            Python.list(1, 2, 3),
            Python.list(4, 5, 6)
        )
    )
    assert_equal(array.shape, Python.tuple(2, 3))


def main():
    test_basic_numpy_example()
