"""A rule for creating shared libraries written in Mojo."""

load("//mojo/private:mojo_binary_test.bzl", _mojo_shared_library = "mojo_shared_library")

mojo_shared_library = _mojo_shared_library
