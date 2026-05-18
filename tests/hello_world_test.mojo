from std.testing import assert_equal
from package.package import foo


def test_basic() raises:
    assert_equal(foo(), 42)


def main() raises:
    print("Running tests...")
    test_basic()
