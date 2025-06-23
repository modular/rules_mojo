import python_shared_library

if __name__ == "__main__":
    result = python_shared_library.mojo_count_args(1, 2)
    assert result == 2
    print("Result from Mojo 🔥:", result)
