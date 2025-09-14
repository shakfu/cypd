from setuptools import setup


setup(
    name="libpd",
    setup_requires=["cffi>=1.0.0"],
    cffi_modules=["libpd/_libpd_build.py:ffibuilder"],
    install_requires=["cffi>=1.0.0"],
    packages=['libpd'],
)

