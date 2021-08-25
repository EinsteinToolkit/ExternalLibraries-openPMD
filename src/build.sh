#! /bin/bash

################################################################################
# Build
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors



# Set locations
THORN=openPMD
NAME=openPMD-api-0.14.1
SRCDIR="$(dirname $0)"
BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
if [ -z "${OPENPMD_INSTALL_DIR}" ]; then
    INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
else
    echo "BEGIN MESSAGE"
    echo "Installing openPMD into ${OPENPMD_INSTALL_DIR}"
    echo "END MESSAGE"
    INSTALL_DIR=${OPENPMD_INSTALL_DIR}
fi
DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
OPENPMD_DIR=${INSTALL_DIR}

echo "openPMD: Preparing directory structure..."
cd ${SCRATCH_BUILD}
mkdir build external done 2> /dev/null || true
rm -rf ${BUILD_DIR} ${INSTALL_DIR}
mkdir ${BUILD_DIR} ${INSTALL_DIR}

# Build core library
echo "openPMD: Unpacking archive..."
pushd ${BUILD_DIR}
${TAR?} xf ${SRCDIR}/../dist/${NAME}.tar

echo "openPMD: Configuring..."
cd ${NAME}

unset LIBS

if [ "${CCTK_DEBUG_MODE}" = yes ]; then
    OPENPMD_BUILD_TYPE=Debug
else
    OPENPMD_BUILD_TYPE=Release
fi

if [ -n "${HAVE_CAPABILITY_HDF5}" ]; then
  openPMD_USE_HDF5=ON
else
  openPMD_USE_HDF5=OFF
fi

if [ -n "${HAVE_CAPABILITY_ADIOS}" ]; then
  openPMD_USE_ADIOS2=ON
else
  openPMD_USE_ADIOS2=OFF
fi

mkdir build
cd build
# cannot use MPI and HDF5 at the same time since the ET's HDF5 is not parallel
# openPMD fails to compile with C++17 on Intel 19+g++8.4
# shared libs cause issues with other parts of ExternalLibraries that are built
# only statically (eg hDF5).
${CMAKE_DIR:+${CMAKE_DIR}/bin/}cmake -DCMAKE_BUILD_TYPE=${OPENPMD_BUILD_TYPE} \
-DopenPMD_USE_HDF5=${openPMD_USE_HDF5} -DHDF5_ROOT=${HDF5_DIR} \
-DopenPMD_USE_ADIOS2=${openPMD_USE_ADIOS2} -DADIOS2_ROOT=${ADIOS_DIR} \
-DopenPMD_USE_MPI=OFF \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_CLI_TOOLS=OFF -DBULD_TESTING=OFF \
-DCMAKE_CXX_STANDARD=14 \
-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
-DopenPMD_USE_PYTHON=OFF -DopenPMD_BUILD_TESTING=OFF -DopenPMD_BUILD_EXAMPLES=OFF ..

echo "openPMD: Building..."
${MAKE}

echo "openPMD: Installing..."
${MAKE} install
popd

echo "openPMD: Cleaning up..."
rm -rf ${BUILD_DIR}

date > ${DONE_FILE}
echo "openPMD: Done."
