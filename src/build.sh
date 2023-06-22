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
NAME=openPMD-api-0.15.1
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

echo "openPMD: Applying patches..."
pushd ${NAME}
${PATCH?} -p1 < ${SRCDIR}/../dist/hdf5_version.patch
${PATCH?} -p1 < ${SRCDIR}/../dist/explicit_specialization.patch
# Some (ancient but still used) versions of patch don't support the
# patch format used here but also don't report an error using the exit
# code. So we use this patch to test for this
${PATCH?} -p1 < ${SRCDIR}/../dist/patchtest.patch
if [ ! -e .patch_tmp ]; then
    echo 'BEGIN ERROR'
    echo 'The version of patch is too old to understand this patch format.'
    echo 'Please set the PATCH environment variable to a more recent '
    echo 'version of the patch command.'
    echo 'END ERROR'
    exit 1
fi
rm -f .patch_tmp
popd

echo "openPMD: Configuring..."
cd ${NAME}

unset LIBS

if [ "${CCTK_DEBUG_MODE}" = yes ]; then
    OPENPMD_BUILD_TYPE=Debug
else
    OPENPMD_BUILD_TYPE=Release
fi

if [ -n "${HAVE_CAPABILITY_HDF5}" ]; then
  # this is fairly ugly. It assumes an "include" directory in HDF5_DIR and it
  # parses include file for HDF5 information to check if HDF5 is compatible
  # with openPMD.
  H5PUBCONFFILES="H5pubconf.h H5pubconf-64.h H5pubconf-32.h"
  for dir in ${HDF5_DIR}/include; do
    for file in $H5PUBCONFFILES ; do
      if [ -r "$dir/$file" ]; then
        H5PUBCONF="$H5PUBCONF $dir/$file"
        break
      fi
    done
  done
  if [ -z "$H5PUBCONF" ]; then
    if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
      echo "${THORN}: Could not find H5pubconf.h to determine parallel HDF5, will proceed without HDF5."
      openPMD_USE_HDF5=OFF
    fi
  else
    if grep -qe '#define H5_HAVE_PARALLEL 1' $H5PUBCONF 2> /dev/null; then
      openPMD_USE_HDF5=ON
    else
      openPMD_USE_HDF5=OFF
    fi
  fi
else
  openPMD_USE_HDF5=OFF
fi

if [ -n "${HAVE_CAPABILITY_ADIOS2}" ]; then
  openPMD_USE_ADIOS2=ON
else
  openPMD_USE_ADIOS2=OFF
fi

if [ -n "${HAVE_CAPABILITY_MPI}" ]; then
  openPMD_USE_MPI=ON
else
  openPMD_USE_MPI=OFF
fi

mkdir build
cd build
# CarpetX requires MPI aware openPMD
# openPMD fails to compile with C++17 on Intel 19+g++8.4
# shared libs cause issues with other parts of ExternalLibraries that are built
# only statically (eg hDF5).
${CMAKE_DIR:+${CMAKE_DIR}/bin/}cmake -DCMAKE_BUILD_TYPE=${OPENPMD_BUILD_TYPE} \
-DopenPMD_USE_HDF5=${openPMD_USE_HDF5} -DHDF5_ROOT=${HDF5_DIR} \
-DopenPMD_USE_ADIOS2=${openPMD_USE_ADIOS2} -DADIOS2_ROOT=${ADIOS2_DIR} \
-DopenPMD_USE_MPI=${openPMD_USE_MPI} \
-DBUILD_SHARED_LIBS=OFF \
-DBUILD_CLI_TOOLS=OFF -DBUILD_TESTING=OFF \
-DCMAKE_CXX_STANDARD=14 \
-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DCMAKE_INSTALL_LIBDIR=lib \
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
