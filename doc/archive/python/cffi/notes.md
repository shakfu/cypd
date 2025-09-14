# notes on cffi


```python
wrap: int f(double* x);

def python_f():
    x_ptr = ffi.new("double[1]")
    x_ptr[0] = old_value
    rc = lib.f(x_ptr)
    assert rc == 0
    return x_ptr[0]
```
