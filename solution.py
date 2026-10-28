"""NPU-only public entry. Does not compute, cache outputs or JIT-build on a call."""
from pathlib import Path
import importlib.machinery
import importlib.util

_EXTENSION = None


def _extension():
    global _EXTENSION
    if _EXTENSION is None:
        spec = importlib.machinery.PathFinder.find_spec("_t5_qkv", [str(Path(__file__).resolve().parent)])
        if spec is None or spec.loader is None:
            raise RuntimeError("NPU extension is not built. Run bash scripts/build.sh in the specified CANN environment.")
        _EXTENSION = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_EXTENSION)
    return _EXTENSION


def run(inputs, attributes):
    return _extension().execute(inputs, attributes, False)


def run_direct(inputs, attributes):
    return _extension().execute(inputs, attributes, True)


class Prepared:
    """Metadata-only plan; each call supplies inputs and creates fresh outputs.

    Current stream is resolved on every call, not at prepare time.
    """
    __slots__ = ("_attributes", "_shape", "_dtype", "_device")

    def __init__(self, inputs, attributes, shape):
        self._attributes = dict(attributes)
        self._shape = tuple(shape)
        self._dtype, self._device = inputs[0].dtype, inputs[0].device

    def _check(self, inputs):
        shape = _extension().validate(inputs, self._attributes)
        if (tuple(shape) != self._shape or inputs[0].dtype != self._dtype or inputs[0].device != self._device):
            raise ValueError("prepared metadata does not match inputs")

    def __call__(self, inputs):
        self._check(inputs)
        return run(inputs, self._attributes)

    def run(self, inputs):
        return self(inputs)

    def run_direct(self, inputs):
        self._check(inputs)
        return run_direct(inputs, self._attributes)


def prepare(inputs, attributes):
    shape = _extension().validate(inputs, attributes)
    return Prepared(inputs, attributes, shape)
