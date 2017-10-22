#!/bin/bash
set -e

export PETSC_DIR=${PREFIX}
export SLEPC_DIR=${PREFIX}
cd "src/eps/examples/tests"
make test10

# FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
# See https://github.com/conda-forge/conda-smithy/pull/337
# See https://github.com/pmodels/mpich/pull/2755
make runtest10_1 MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
