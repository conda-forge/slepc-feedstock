#!/bin/bash
set -eu
export PETSC_DIR=$PREFIX
export SLEPC_DIR=$SRC_DIR
export SLEPC_ARCH=arch-conda-c-opt

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
        sedinplace s%${path}%\${PREFIX}%g $f
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

cat $slepcvariables

make MAKE_NP=${CPU_COUNT} V=1
make install

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
