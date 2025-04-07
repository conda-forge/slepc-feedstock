#!/bin/bash
set -eu
export PETSC_DIR=$PREFIX
export SLEPC_DIR=$SRC_DIR
export SLEPC_ARCH=arch-conda-c-opt

# scrub debug-prefix-map args, which cause problems in pkg-config
export CFLAGS=$(echo ${CFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export CXXFLAGS=$(echo ${CXXFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export FFLAGS=$(echo ${FFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')

unset CXX

# openmpi:
export OMPI_CC=$CC
export OPAL_PREFIX=$PREFIX

# Add symlinks in ${PREFIX}/bin
ln -s ${BUILD_PREFIX}/bin/make     ${PREFIX}/bin
ln -s ${BUILD_PREFIX}/bin/dsymutil ${PREFIX}/bin

# Set cuda target
if [[ "${cuda_compiler_version}" != "None" ]]; then
  if [[ "${target_platform}" == "linux-64" ]]; then
    export CUDA_CONDA_TARGET_NAME=x86_64-linux
  elif [[ "${target_platform}" == "linux-aarch64" ]]; then
    export CUDA_CONDA_TARGET_NAME=sbsa-linux
  elif [[ "${target_platform}" == "linux-ppc64le" ]]; then
    export CUDA_CONDA_TARGET_NAME=ppc64le-linux
  else
    echo "unexpected cuda target_platform=${target_platform}"
    exit 1
  fi
fi

python ./configure \
  --prefix=$PREFIX || (cat configure.log && exit 1)

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

# Patch some linking variables post-configure
# PETSC_SNES_LIB contains _all_ petsc external libraries
# resulting in major over-linking
# further, SLEPC_LIB also pulls in the full PETSC_SNES_LIB, when it should be just petsc, slepc,
# and SLEPC_LIB_BASIC is also incorrect
# also note that we have to use -lscalapack, not ${SCALAPACK_LIB}
# because slepc config explicitly forces an empty `SCALAPACK_LIB = `

slepcvariables=$(ls installed-*/lib/slepc/conf/slepcvariables)
echo "patching $slepcvariables"
test -f $slepcvariables

cat >> $slepcvariables << 'EOF'
# conda-forge overrides to avoid over-linking
SLEPC_LIB_BASIC = -lslepc
PETSC_SNES_LIB = ${CC_LINKER_SLFLAG}${SLEPC_LIB_DIR} -L${SLEPC_LIB_DIR} ${PETSC_LIB_BASIC} ${BLASLAPACK_LIB} -lscalapack
SLEPC_LIB = ${CC_LINKER_SLFLAG}${SLEPC_LIB_DIR} -L${SLEPC_LIB_DIR} ${SLEPC_LIB_BASIC} ${PETSC_LIB_BASIC}
EOF

# The PETSc CUDA build does not store the location of the headers
if [[ "${cuda_compiler_version}" != "None" ]]; then
  if [[ -n "${CUDA_HOME:-}" ]]; then # cuda 11.8
    # CUDA in $CUDA_HOME/targets/xxx
    cuda_dir=$CUDA_HOME
  else
    # CUDA in $PREFIX/targets/xxx
    cuda_dir=$PREFIX # cuda 12 and later
  fi
  cuda_incl=$cuda_dir/targets/${CUDA_CONDA_TARGET_NAME}/include

  echo "CUDACPPFLAGS+=$cuda_incl" >> $slepcvariables
  echo "CXXPPFLAGS+=$cuda_incl" >> $slepcvariables
  echo "CPPFLAGS+=$cuda_incl" >> $slepcvariables
fi
cat $slepcvariables

make MAKE_NP=${CPU_COUNT} V=1
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

if [[ "${target_platform}" == osx-* ]]; then
  # check install_name patch
  otool -L $PREFIX/lib/libslepc.dylib
fi
