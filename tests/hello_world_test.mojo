from std.testing import assert_equal
from package.package import foo


fn test_basic() raises:
    assert_equal(foo(), 42)


fn main() raises:
    print("Running tests...")
    test_basic()
