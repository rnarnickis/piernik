!
! PIERNIK Code Copyright (C) 2006 Michal Hanasz
!
!    This file is part of PIERNIK code.
!
!    PIERNIK is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    PIERNIK is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with PIERNIK.  If not, see <http://www.gnu.org/licenses/>.
!
!    Initial implementation of PIERNIK code was based on TVD split MHD code by
!    Ue-Li Pen
!        see: Pen, Arras & Wong (2003) for algorithm and
!             http://www.cita.utoronto.ca/~pen/MHD
!             for original source code "mhd.f90"
!
!    For full list of developers see $PIERNIK_HOME/license/pdt.txt
!
#include "piernik.h"
!>
!! \brief Module containing numerical %constants, enumerations, string lengths, etc.
!! \details Module constants contains numerical %constants, enumerations, string lengths, etc.
!! This module should not depend on anything else in the Piernik code and should not contain any functions or subroutines.
!<
module constants

   use iso_fortran_env, only: error_unit, output_unit

   implicit none

   public                                                ! QA_WARN no secrets are kept here

   ! precision
   integer, parameter :: pk = selected_real_kind(8)   !< Default kind of floats
   integer, parameter :: LONG = selected_int_kind(16)    ! We need at least 8-byte integers to count to 10**16, it is much more clear to type 0_LONG than 0_8
   integer, parameter :: INT4 = selected_int_kind(9)     ! Assume that all MPI and HDF5 calls expect 4-byte integers
   ! \todo define 1- and 2-byte integers and short (4-byte), long double (10-byte) or quad_precision (16-byte) reals if needed,

   ! integers and rationals
   real, parameter :: zero       = 0.0                   !< zero
   real, parameter :: one        = 1.0                   !< one
   real, parameter :: two        = 2.0                   !< two
   real, parameter :: half       = 0.5                   !< a half
   real, parameter :: onet       = 1./3.                 !< one third
   real, parameter :: twot       = 2./3.                 !< two thirds
   real, parameter :: oneq       = 1./4.                 !< one fourth
   real, parameter :: thrq       = 3./4.                 !< three fourths

   enum, bind(C)
      enumerator :: idn = 1, imx, imy, imz, ien
   end enum

   enum, bind(C)
      enumerator :: I_ZERO = 0, I_ONE, I_TWO, I_THREE, I_FOUR, I_FIVE, I_SIX, I_SEVEN, I_EIGHT, I_NINE, I_TEN
   end enum

   ! enumerator for length/mass/time/velocity/magnetic field units
   enum, bind(C)
      enumerator :: U_LEN = 1, U_MASS, U_TIME, U_VEL, U_MAG, U_ENER
   end enum

   ! irrational number approximations
   real, parameter :: pi         = 3.141592653589793238  !< Pi (Archimedes' constant)
   real, parameter :: dpi        = 2.*pi                 !< doubled Pi
   real, parameter :: fpi        = 4.*pi                 !< four Pi
   real, parameter :: e          = 2.718281828459045235  !< Napier's constant (base of Natural logarithm)

   ! some numerical representation extrema
   real, parameter :: big        = huge(real(1.0,4))     !< a constant used as the upper limit number
   real, parameter :: big_float  = huge(real(1.0,4))     !< replicated temporarily 'big' for compatibility \todo choose one and convert occurrences of the other one
   real, parameter :: dirtyH     = big                   !< If dirty_debug then pollute arrays with this insane value
   real, parameter :: dirtyL     = sqrt(dirtyH)          !< If dirty_debug then assume that the array got contaminated by dirtyH by checking against this value
   real, parameter :: small      = tiny(real(1.0,4))     !< a constant used as the lower limit number
   integer, parameter :: big_int = huge(int(1,4))

   ! dimensions
   enum, bind(C)
      enumerator :: xdim = 1, ydim, zdim                 !! parameters assigned to the x-, y- and z-direction
   end enum
   integer(kind=4), parameter :: ndims   = zdim - xdim + 1 !< We live in a 3-dimensional world
   integer(kind=4), parameter :: cor_dim = zdim+1        !< corner "direction", useful for selecting guardcell exchanges
   !>
   !! array of all positive permutations of xyzdim
   !<
   enum, bind(C)
      enumerator :: NORMAL = 1    ! Normal direction
      enumerator :: ORTHO1        ! First othogonal to the NORMAL (x -> y -> z -> x cycle)
      enumerator :: ORTHO2        ! Second othogonal to the NORMAL
   end enum
   integer(kind=4), dimension(xdim:zdim, NORMAL:ORTHO2) :: pdims = &
      reshape([xdim, ydim, zdim, ydim, zdim, xdim, zdim, xdim, ydim], [ndims, ndims])

   enum, bind(C)
      enumerator :: LO = 1, HI                           !! indices for low (left) and high (right) boundaries
   end enum

   ! string lengths
   integer, parameter :: cwdlen = 512                    !< allow for quite long CWD
   integer, parameter :: fmt_len = 128                   !< length of format string
   integer, parameter :: fnamelen = 128                  !< length of output filename
   integer, parameter :: cbuff_len = 32                  !< length for problem parameters
   integer, parameter :: units_len = 5 * cbuff_len       !< length for unit strings
   integer, parameter :: fplen = 24                      !< length of buffer for printed FP or integer number
   integer, parameter :: domlen = 16                     !< should be <= cbuff_len
   integer, parameter :: dsetnamelen = cbuff_len         !< length of dataset name and state variable names in hdf files
   integer, parameter :: idlen = 3                       !< COMMENT ME
   integer, parameter :: singlechar = 1                  !< a single character

   ! simulation state
   enum, bind(C)
      enumerator :: PIERNIK_START                        ! before initialization
      enumerator :: PIERNIK_INIT_MPI                     ! initialized MPI
      enumerator :: PIERNIK_INIT_GLOBAL                  ! initialized global parameters
      enumerator :: PIERNIK_INIT_DOMAIN                  ! initialized domain
      enumerator :: PIERNIK_INIT_FLUIDS                  ! initialized fluid properties
      enumerator :: PIERNIK_INIT_GRID                    ! initialized grids
      enumerator :: PIERNIK_INIT_IO_IC                   ! initialized all physics
      enumerator :: PIERNIK_INITIALIZED                  ! initialized I/O and IC, running
      enumerator :: PIERNIK_FINISHED                     ! finished simulation
      enumerator :: PIERNIK_CLEANUP                      ! finished post-simulation computations and I/O
   end enum

   ! grid geometry type
   enum, bind(C)
       enumerator :: GEO_XYZ, GEO_RPZ                    !! Cartesian (0) or cylindrical (1) grid with uniform cell spacing
       enumerator :: GEO_INVALID = GEO_XYZ - 1           !! non-recognized grid geometry (-1)
   end enum

   ! boundary conditions type
   enum, bind(C)
      enumerator :: BND_MPI                   !! internal, processor-processor boundary on the same level (by default equal to 0)
      enumerator :: BND_FC                    !! internal, processor-processor boundary with lower refinement level
      enumerator :: BND_MPI_FC                !! internal, processor-processor boundary partially on the same level, partially lower
      enumerator :: BND_PER                   !! periodic boundary
      enumerator :: BND_REF                   !! reflecting boundary
      enumerator :: BND_NEGREF                !! antireflecting boundary
      enumerator :: BND_ZERO                  !! zero-valued boundary
      enumerator :: BND_NONE                  !! do not touch external boundary
      enumerator :: BND_XTRAP                 !! linearly extrapolated boundary
      enumerator :: BND_OUT                   !! free boundary
      enumerator :: BND_OUTD                  !! one-way outflow boundary
      enumerator :: BND_OUTH                  !! hydrostatic boundary
      enumerator :: BND_OUTHD                 !! hydrostatic diode boundary (one-way outflow)
      enumerator :: BND_COR                   !! corner boundary
      enumerator :: BND_SHE                   !! shear boundary
      enumerator :: BND_USER                  !! user boundaries (provided in read_problem_par)
      enumerator :: BND_INVALID = BND_MPI - 1 !! non-recognized boundary
   end enum

   ! 3D and 4D array names
   ! fluids
   character(len=dsetnamelen), parameter :: fluid_n = "fluid"   !< main array
   character(len=dsetnamelen), parameter :: uh_n    = "uh"      !< auxiliary array for half-step values
   character(len=dsetnamelen), parameter :: u0_n    = "u0"      !< backup copy for timestep retrying
   ! magnetic field
   character(len=dsetnamelen), parameter :: mag_n   = "mag"     !< main array
   character(len=dsetnamelen), parameter :: b0_n    = "b0"      !< backup copy for timestep retrying
   ! gravitational potential
   character(len=dsetnamelen), parameter :: gp_n    = "gp"      !< static, external field, must be explicitly set to 0. if no external fields are applied
   character(len=dsetnamelen), parameter :: sgp_n   = "sgp"     !< current field from self-gravity
   character(len=dsetnamelen), parameter :: sgpm_n  = "sgpm"    !< previous field from self-gravity
   character(len=dsetnamelen), parameter :: gpot_n  = "gpot"    !< current sum of fields
   character(len=dsetnamelen), parameter :: hgpot_n = "hgpot"   !< sum of fields for half-step values
   ! misc
   character(len=dsetnamelen), parameter :: wcu_n   = "wcu"     !< (resistivity) COMMENT ME
   character(len=dsetnamelen), parameter :: cs_i2_n = "cs_iso2" !< map of imposed isothermal sound speed
   character(len=dsetnamelen), parameter :: wcr_n   = "wcr"     !< auxiliary array for CR diffusion
   character(len=dsetnamelen), parameter :: wa_n    = "wa"      !< general-purpose auxiliary 3D array

   ! timer names
   character(len=*), parameter :: tmr_fu  = "fluid_update"   !< main timer used to measure fluid_update step
   character(len=*), parameter :: tmr_hdf = "hdf_dump"       !< timer for I/O operations
   character(len=*), parameter :: tmr_mg  = "multigrid"      !< timer for gravity multigrid solver
   character(len=*), parameter :: tmr_mgd = "multigrid_diff" !< timer for gravityCR diffusion multigrid solver

   ! Handling boundary cells in the output
   enum, bind(C)
      enumerator :: AT_IGNORE       !! no output
      enumerator :: AT_NO_B         !! no boundary cells
      enumerator :: AT_OUT_B        !! external boundary cells
      enumerator :: AT_USER         !! user defined area type
   end enum

   ! Position of variable within a cell
   enum, bind(C)
      enumerator :: VAR_CENTER      !! cell-centered
      enumerator :: VAR_CORNER      !! corner (staggered-grid variable)
      enumerator :: VAR_XFACE       !! X-face
      enumerator :: VAR_YFACE       !! Y-face
      enumerator :: VAR_ZFACE       !! Z-face
   end enum

   ! Interpolation order
   enum, bind(C)
      enumerator :: O_INJ = 0  !! injection
      enumerator :: O_LIN = 1  !! linear
      enumerator :: O_I2  = 2  !! integral quadratic
      enumerator :: O_I3  = 3  !! integral cubic
      enumerator :: O_I4  = 4  !! integral quartic
      enumerator :: O_D2  = -2 !! direct quadratic
      enumerator :: O_D3  = -3 !! direct cubic
      enumerator :: O_D4  = -4 !! direct quartic
      enumerator :: O_D5  = -5 !! direct quintic
      enumerator :: O_D6  = -6 !! direct sextic
   end enum

   ! Fluid type index, used in flind%tag
   enum, bind(C)
      enumerator :: ION = 1, NEU, DST
   end enum

   ! Output type
   enum, bind(C)
      enumerator :: RES = 1, HDF, LOGF, TSL, INCEPTIVE, FINAL_DUMP, CHK
   end enum

   ! base level
   integer(kind=4), parameter :: base_level_id = 0 !< Base domain level id. Refinements are positively numbered, coarsened levels for use in multigrid solvers have negative numbers.
   integer(kind=4), parameter :: refinement_factor = 2 !< Resolution difference between consecutive levels. This is deeply hardwired into prolongation, restriction and such routines

   ! type of FFT transform used in multigrid
   enum, bind(C)
      enumerator :: fft_rcr  =  1 !< full
      enumerator :: fft_dst       !< discrete sine
      enumerator :: fft_none = -1 !< none
   end enum

   ! particle interpolation scheme
   enum, bind(C)
      enumerator :: I_NGP   ! Nearest grid point
      enumerator :: I_CIC   ! Cloud in cell
      enumerator :: I_TSC   ! Triangular shaped cloud
   end enum

   ! -1, 0, 1
   enum, bind(C)
      enumerator :: IM = -1
      enumerator :: I0
      enumerator :: IP
   end enum

   ! coordinate positions;
   !> \warning gridgeometry depends on the sequence
   enum, bind(C)
      enumerator :: CENTER
      enumerator :: LEFT
      enumerator :: RIGHT
      enumerator :: INV_CENTER
   end enum

   ! MPI reduction type
   enum, bind(C)
      enumerator :: pSUM = 1, pMIN, pMAX, pLOR, pLAND
   end enum

   ! different velocities used by fargo algorithm
   enum, bind(C)
      enumerator :: VEL_RES, VEL_CR
   end enum

   ! misc
   enum, bind(C)
      enumerator :: MINL, MAXL                           !< constants for func::get_extremum
      enumerator :: RD, WR                               !< constants for wd_{rd,wr} selection
   end enum
   integer, parameter :: stdout = output_unit
   integer, parameter :: stderr = error_unit
   integer(kind=4), parameter :: INVALID = -I_ONE

   integer(kind=4), dimension(ndims,ndims),       parameter :: idm  = reshape(int([ [1,0,0], [0,1,0], [0,0,1] ], kind=4),[ndims,ndims])   !< identity matrix 3x3
   integer(kind=4), dimension(ndims,ndims,LO:HI), parameter :: idm2 = reshape([idm,idm],[ndims,ndims,2_INT4])                             !< auxiliary matrix 3x3x2 based on identity matrix
   integer(kind=4), dimension(ndims),             parameter :: uv   = int([1,1,1], kind=4)                                                !< unity vector

end module constants
