#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors

. $CCTK_HOME/lib/make/bash_utils.sh

# Take care of requests to build the library in any case
OPENPMD_DIR_INPUT=$OPENPMD_DIR
if [ "$(echo "${OPENPMD_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]; then
    OPENPMD_BUILD=1
    OPENPMD_DIR=
else
    OPENPMD_BUILD=
fi

# default value for FORTRAN support
if [ -z "$OPENPMD_ENABLE_FORTRAN" ] ; then
    OPENPMD_ENABLE_FORTRAN="OFF"
fi

################################################################################
# Decide which libraries to link with
################################################################################

# Set up names of the libraries based on configuration variables. Also
# assign default values to variables.
# Try to find the library if build isn't explicitly requested
if [ -z "${OPENPMD_BUILD}" -a -z "${OPENPMD_INC_DIRS}" -a -z "${OPENPMD_LIB_DIRS}" -a -z "${OPENPMD_LIBS}" ]; then
    find_lib OPENPMD openPMD 1 1.0 "openPMD" "openPMD/openPMD.hpp" "$OPENPMD_DIR"
fi

THORN=openPMD

# configure library if build was requested or is needed (no usable
# library found)
if [ -n "$OPENPMD_BUILD" -o -z "${OPENPMD_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "Using bundled openPMD..."
    echo "END MESSAGE"
    OPENPMD_BUILD=1

    check_tools "tar patch"
    
    # Set locations
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${OPENPMD_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing openPMD into ${OPENPMD_INSTALL_DIR}"
        echo "END MESSAGE"
        INSTALL_DIR=${OPENPMD_INSTALL_DIR}
    fi
    OPENPMD_DIR=${INSTALL_DIR}
    # Fortran modules may be located in the lib directory
    OPENPMD_INC_DIRS="${OPENPMD_DIR}/include ${OPENPMD_DIR}/lib"
    OPENPMD_LIB_DIRS="${OPENPMD_DIR}/lib"
    OPENPMD_LIBS="amrex"
else
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    if [ ! -e ${DONE_FILE} ]; then
        mkdir ${SCRATCH_BUILD}/done 2> /dev/null || true
        date > ${DONE_FILE}
    fi
fi

if [ -n "$OPENPMD_DIR" ]; then
    : ${OPENPMD_RAW_LIB_DIRS:="$OPENPMD_LIB_DIRS"}
    # Fortran modules may be located in the lib directory
    OPENPMD_INC_DIRS="$OPENPMD_RAW_LIB_DIRS $OPENPMD_INC_DIRS"
    # We need the un-scrubbed inc dirs to look for a header file below.
    : ${OPENPMD_RAW_INC_DIRS:="$OPENPMD_INC_DIRS"}
else
    echo 'BEGIN ERROR'
    echo 'ERROR in openPMD configuration: Could neither find nor build library.'
    echo 'END ERROR'
    exit 1
fi

################################################################################
# Check for additional libraries
################################################################################


################################################################################
# Configure Cactus
################################################################################

# Pass configuration options to build script
echo "BEGIN MAKE_DEFINITION"
echo "OPENPMD_BUILD          = ${OPENPMD_BUILD}"
echo "OPENPMD_ENABLE_FORTRAN = ${OPENPMD_ENABLE_FORTRAN}"
echo "LIBSZ_DIR           = ${LIBSZ_DIR}"
echo "LIBZ_DIR            = ${LIBZ_DIR}"
echo "OPENPMD_INSTALL_DIR    = ${OPENPMD_INSTALL_DIR}"
echo "END MAKE_DEFINITION"

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "OPENPMD_DIR            = ${OPENPMD_DIR}"
echo "OPENPMD_ENABLE_FORTRAN = ${OPENPMD_ENABLE_FORTRAN}"
echo "OPENPMD_INC_DIRS       = ${OPENPMD_INC_DIRS} ${ZLIB_INC_DIRS}"
echo "OPENPMD_LIB_DIRS       = ${OPENPMD_LIB_DIRS} ${ZLIB_LIB_DIRS}"
echo "OPENPMD_LIBS           = ${OPENPMD_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(OPENPMD_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(OPENPMD_LIB_DIRS)'
echo 'LIBRARY           $(OPENPMD_LIBS)'
