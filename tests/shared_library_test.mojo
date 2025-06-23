from sys.ffi import c_int, external_call
from testing import assert_equal

def main():
    print("Calling external function...")
    result = external_call["foo", c_int]()
    print("Result from external function:", result)
    assert_equal(result, 42)
