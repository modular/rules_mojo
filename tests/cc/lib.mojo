from std.ffi import external_call

def call_foo():
    external_call["foo", NoneType]()
