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
if [[ "${cuda_compiler_version}" != "None" ]]; then
    make testdlopen
    # aarch64 failing tests
    # ./testdlopen: /lib64/libm.so.6: version `GLIBC_2.27' not found (required by $PREFIX/lib/./libcurand.so.10)
    if [[ "${target_platform}" != "linux-aarch64" ]]; then
        ./testdlopen
    fi
else
    make test10
    make test14f

    make runtest10 MPIEXEC=mpiexec
    make runtest14f MPIEXEC=mpiexec
fi
