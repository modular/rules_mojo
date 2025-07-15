"""Transitions used by Mojo rules."""

_PYTHON_VERSION = "@rules_python//python/config_settings:python_version"

def _python_version_transition_impl(settings, attr):
    output = {_PYTHON_VERSION: settings[_PYTHON_VERSION]}
    if attr.python_version:
        if "_" in attr.python_version:
            fail("error: invalid python version: ", attr.python_version)
        output["@rules_python//python/config_settings:python_version"] = str(attr.python_version)

    return output

python_version_transition = transition(
    implementation = _python_version_transition_impl,
    inputs = [_PYTHON_VERSION],
    outputs = [_PYTHON_VERSION],
)
