#!/bin/bash
set -eu
export PETSC_DIR=$PREFIX
export SLEPC_DIR=$SRC_DIR
export SLEPC_ARCH=arch-conda-c-opt

# scrub debug-prefix-map args, which cause problems in pkg-config
export CFLAGS=$(echo ${CFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export CXXFLAGS=$(echo ${CXXFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export FFLAGS=$(echo ${FFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')

unset CC
unset CXX

# Add symlinks in ${PREFIX}/bin
ln -s ${BUILD_PREFIX}/bin/make     ${PREFIX}/bin
ln -s ${BUILD_PREFIX}/bin/dsymutil ${PREFIX}/bin

python ./configure \
  --prefix=$PREFIX || (cat configure.log && exit 1) \
  --with-scalar-type=${scalar}

sedinplace() {
  if [[ $(uname) == Darwin ]]; then
    sed -i "" "$@"
  else
    sed -i"" "$@"
  fi
}

# Replace abspath of ${SLEPC_DIR} and ${BUILD_PREFIX} with ${PREFIX}
sedinplace s%\"arch-.*\"%\"${SLEPC_ARCH}\"%g installed-arch-*/include/slepc*.h
for path in $SLEPC_DIR $BUILD_PREFIX; do
    for f in $(grep -l "${path}" installed-arch-*/include/slepc*.h); do
        echo "Fixing ${path} in $f"
        sedinplace s%$path%\${PREFIX}%g $f
    done
done

make

# FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
# See https://github.com/conda-forge/conda-smithy/pull/337
# See https://github.com/pmodels/mpich/pull/2755
make check MPIEXEC="${RECIPE_DIR}/mpiexec.sh"

make install

# Remove symlinks in ${PREFIX}/bin
rm ${PREFIX}/bin/make
rm ${PREFIX}/bin/dsymutil

echo "Removing example files"
rm -fr $PREFIX/share/slepc/examples
echo "Removing data files"
rm -fr $PREFIX/share/slepc/datafiles
echo "Removing unneeded files"
rm -f  $PREFIX/lib/slepc/conf/files
rm -f  $PREFIX/lib/slepc/conf/*.log
rm -f  $PREFIX/lib/slepc/conf/*.pyc
rm -f  $PREFIX/lib/slepc/conf/uninstall.py
rm -fr $PREFIX/lib/libslepc.*.dylib.dSYM
