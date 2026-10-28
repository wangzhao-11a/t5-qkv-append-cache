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


def _arguments(inputs, attributes):
    if not isinstance(inputs, (tuple, list)) or len(inputs) != 3:
        raise ValueError("inputs must be a tuple/list of exactly three tensors")
    if not isinstance(attributes, dict):
        raise TypeError("attributes must be a dictionary")
    if attributes.keys() - {"headNum", "headDim"}:
        raise ValueError("unknown attributes")
    values = []
    for name, upper in (("headNum", 128), ("headDim", 256)):
        if name not in attributes:
            values.append(-2)  # Internal inference sentinel; never accepted from caller.
        else:
            value = attributes[name]
            if type(value) is not int or not 1 <= value <= upper:
                raise ValueError(f"{name} must be an integer in [1, {upper}]")
            values.append(value)
    return values


def run(inputs, attributes):
    h, d = _arguments(inputs, attributes)
    return tuple(_extension().execute(inputs, h, d, False))


def run_direct(inputs, attributes):
    h, d = _arguments(inputs, attributes)
    return tuple(_extension().execute(inputs, h, d, True))


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
        h, d = _arguments(inputs, self._attributes)
        shape = _extension().validate(inputs, h, d)
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
    h, d = _arguments(inputs, attributes)
    shape = _extension().validate(inputs, h, d)
    return Prepared(inputs, attributes, shape)
