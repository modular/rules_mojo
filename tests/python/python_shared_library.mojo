from os import abort

from python import Python, PythonObject
from python.bindings import PythonModuleBuilder
from python._cpython import PyObjectPtr


@export
fn PyInit_python_shared_library() -> PythonObject:
    """Create a Python module with a function binding for `mojo_count_args`."""

    try:
        var b = PythonModuleBuilder("python_shared_library")
        b.def_py_c_function(
            mojo_count_args,
            "mojo_count_args",
            docstring="Count the provided arguments",
        )
        return b.finalize()
    except e:
        return abort[PythonObject](
            String("failed to create Python module: ", e)
        )


@export
fn mojo_count_args(py_self: PyObjectPtr, args: PyObjectPtr) -> PyObjectPtr:
    ref cpython = Python().cpython()

    var count = cpython.PyObject_Length(args)
    return cpython.PyLong_FromSsize_t(count)
