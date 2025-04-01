#!/bin/bash
set -e

pkg-config --cflags SLEPc
pkg-config --libs   SLEPc

# Fix gethostbyname() issues in Azure Pipelines
if [[ $(uname) == Darwin ]]; then
    export HYDRA_IFACE=lo0
fi

export PETSC_DIR=${PREFIX}
export SLEPC_DIR=${PREFIX}
cd "tests"
if [[ -n "${cuda_compiler_version}" ]]; then
    make testdlopen
    # aarch64 failing tests
    # ./testdlopen: /lib64/libm.so.6: version `GLIBC_2.27' not found (required by $PREFIX/lib/./libcurand.so.10)
    if [[ "${target_platform}" != "linux-aarch64" ]]; then
        ./testdlopen
    fi
else
    make test10
    make test14f

    # FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
    # See https://github.com/conda-forge/conda-smithy/pull/337
    # See https://github.com/pmodels/mpich/pull/2755
    make runtest10  MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
    make runtest14f MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
fi
