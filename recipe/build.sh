#!/bin/bash
set -eu
export PETSC_DIR=$PREFIX
export SLEPC_DIR=$SRC_DIR
export SLEPC_ARCH=arch-conda-c-opt

unset CC
unset CXX

python ./configure \
  --prefix=$PREFIX

sedinplace() { [[ $(uname) == Darwin ]] && sed -i "" $@ || sed -i"" $@; }
sedinplace s%\"arch-.*\"%\"${SLEPC_ARCH}\"%g installed-arch-*/include/slepc*.h
for path in $SLEPC_DIR $PREFIX; do
    sedinplace s%$path%\${SLEPC_DIR}%g installed-arch-*/include/slepc*.h
done

make

# FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
# See https://github.com/conda-forge/conda-smithy/pull/337
# See https://github.com/pmodels/mpich/pull/2755
make check MPIEXEC="${RECIPE_DIR}/mpiexec.sh"

make install

rm -fr $PREFIX/share/slepc/examples
rm -fr $PREFIX/share/slepc/datafiles
rm -f  $PREFIX/lib/slepc/conf/files
rm -f  $PREFIX/lib/slepc/conf/*.log
rm -fr $PREFIX/lib/libslepc.*.dylib.dSYM
