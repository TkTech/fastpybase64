from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext

# Only the base64 functions of simdutf are compiled. Enable more features here
# as the module grows (they default to 1 in the amalgamation).
DISABLED_SIMDUTF_FEATURES = ["DETECT_ENCODING", "ASCII", "LATIN1", "UTF8", "UTF16", "UTF32"]
DEFINES = [("NDEBUG", None)] + [(f"SIMDUTF_FEATURE_{name}", "0") for name in DISABLED_SIMDUTF_FEATURES]

ext = Extension(
    "fastpybase64",
    # src/fastpybase64.cpp includes vendor/simdutf.cpp (a unity build).
    sources=["src/fastpybase64.cpp"],
    depends=["vendor/simdutf.cpp", "vendor/simdutf.h"],
    include_dirs=["vendor"],
    language="c++",
    define_macros=DEFINES,
)


class BuildExt(build_ext):
    def build_extensions(self):
        msvc = self.compiler.compiler_type == "msvc"
        # -g0 drops the debug information that Python's default flags request
        # on Linux, which would otherwise make up most of the binary.
        args = ["/std:c++17", "/O2", "/EHsc", "/utf-8"] if msvc else ["-std=c++17", "-O3", "-g0"]
        for e in self.extensions:
            e.extra_compile_args = args
        super().build_extensions()


setup(ext_modules=[ext], cmdclass={"build_ext": BuildExt})
