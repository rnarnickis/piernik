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
!! \brief This module implements relaxing TVD scheme
!!
!! The implementation was based on TVD split MHD code by Pen et al. (2003).
!<
module rtvd ! split orig

! pulled by RTVD

   implicit none

   private
   public  :: tvdb, relaxing_tvd

contains
!/*
!>
!! \brief Subroutine computes magnetic field evolution
!!
!! The original RTVD MHD scheme incorporates magnetic field evolution via the Constrained transport (CT)
!! algorithm by Evans & Hawley (1988). The idea behind the CT scheme is to integrate numerically the induction equation
!! \f{equation}
!! \frac{\partial\vec{B}}{\partial t} = \nabla\times (\vec{v}  \times \vec{B}),
!! \f}
!! in a manner ensuring that the condition
!! \f{equation}
!! \nabla \cdot \vec{B} = 0,
!! \f}
!! is fulfilled to the machine accuracy.
!!
!! The divergence-free evolution of magnetic-field on a discrete computational
!! grid can be realized if the last equation holds for the discrete representation of the initial
!! condition, and that subsequent updates of \f$B\f$ do not change the total magnetic
!! flux threading cell faces.
!!
!! Time variations of magnetic flux threading surface \f$S\f$ bounded by contour \f$C\f$, due to Stokes theorem, can be written as
!! \f{equation}
!! \frac{\partial\Phi_S}{\partial t} = \frac{\partial}{\partial t} \int_S \vec{B} \cdot \vec{d\sigma} = \int_S \nabla \times ( \vec{v} \times \vec{B})\cdot \vec{d \sigma} =  \oint_{C} (\vec{v} \times \vec{B}) \cdot \vec{dl},
!! \f}
!! where \f$\vec{E}= \vec{v} \times \vec{B}\f$ is electric field, named also electromotive force (EMF).
!!
!! In a discrete representation variations of magnetic %fluxes, in %timestep \f$\Delta t\f$, threading faces of cell \f$(i,j,k)\f$ are
!! given by
!! \f{eqnarray}
!! \frac{\Phi^{x,n+1}_{i+1/2,j,k} - \Phi^{x,n}_{i+1/2,j,k}}{\Delta t} &=&
!! {E}^y_{i+1/2,j,k-1/2} \Delta y + {E}^z_{i+1/2,j+1/2,k} \Delta z     \nonumber\\
!! &-&{E}^y_{i+1/2,j,k+1/2} \Delta y - {E}^z_{i+1/2,j-1/2,k} \Delta z,  \nonumber
!! \f}
!! \f{eqnarray}
!! \frac{\Phi^{y,n+1}_{i,j+1/2,k} - \Phi^{y,n}_{i,j+1/2,k}}{\Delta t} &=&
!! {E}^x_{i,j+1/2,k+1/2} \Delta x + {E}^z_{i-1/2,j+1/2,k} \Delta z      \nonumber\\
!! &-&{E}^x_{i,j+1/2,k-1/2} \Delta x - {E}^z_{i+1/2,j+1/2,k} \Delta z,  \nonumber
!! \f}
!! \f{eqnarray}
!! \frac{\Phi^{z,n+1}_{i,j,k+1/2} - \Phi^{z,n}_{i,j,k+1/2}}{\Delta t} &=&
!! {E}^x_{i,j-1/2,k+1/2} \Delta x + {E}^y_{i+1/2,j,k+1/2} \Delta y      \nonumber\\
!! &-&{E}^x_{i,j+1/2,k+1/2} \Delta x - {E}^y_{i-1/2,j,k+1/2} \Delta y,  \nonumber
!! \f}
!! Variations of magnetic flux threading remaining three faces of cell \f$(i,j,k)\f$ can be written in a similar manner. We note that each EMF
!! contribution appears twice with opposite sign. Thus, the total change of magnetic flux, piercing all cell-faces, vanishes to machine accuracy.
!!
!! To present the idea in a slightly different way, following Pen et al. (2003),  we consider the three components of the induction
!! equation written in the explicit form:
!! \f{eqnarray}
!! \partial_t B_x &=& \partial_y (\mathrm{v_x B_y}) + \partial_z (v_x B_z) - \partial_y (v_y B_x) - \partial_z (v_z B_x),\\
!! \partial_t B_y &=& \partial_x (v_y B_x) + \partial_z (v_y B_z) - \partial_x (\mathrm{v_x B_y}) - \partial_z (v_z B_y),\\
!! \partial_t B_z &=& \partial_x (v_z B_x) + \partial_y (v_z B_y) - \partial_x (v_x B_z) - \partial_y (v_y B_z).
!! \f}
!!
!!We note that each combination of \f$v_a B_b\f$ appears twice in these equations. Let us consider \f$v_x B_y\f$.
!!Once  \f$v_x B_y\f$ is computed for numerical integration of the second equation, it should be also used for
!!integration of the first equation, to ensure cancellation of electromotive forces contributing to the total change of magnetic flux threading
!!cell faces.
!!
!!The scheme proposed by Pen et al. (2003), consists of the following steps:
!!\n (1) Computation of the edge-centered EMF component \f$ v_x B_y\f$.
!!\n (2) Update of \f$B_y\f$, according to the equation \f$\partial_t B_y = \partial_x (v_x B_y)\f$.
!!\n (3) Update of \f$B_x\f$, according to the equation \f$\partial_t B_x = \partial_y (v_x B_y)\f$.
!!
!!Analogous procedure applies to remaining EMF components.
!<
!*/
   subroutine tvdb(vibj, b, vg, n, dt, idi)

      use constants, only: big, half

      implicit none

      integer(kind=4),             intent(in)    :: n       !< array size
      real,                        intent(in)    :: dt      !< time step
      real,                        intent(in)    :: idi     !< cell length, depends on direction x, y or z
      real, dimension(:), pointer, intent(inout) :: vibj    !< face-centered electromotive force components (b*vg)
      real, dimension(:), pointer, intent(in)    :: b       !< magnetic field
      real, dimension(n),          intent(in)    :: vg      !< velocity in the center of cell boundary
! locals
      real, dimension(n)                         :: b1      !< magnetic field
      real, dimension(n)                         :: vibj1   !< face-centered electromotive force (EMF) components (b*vg)
      real, dimension(n)                         :: vh      !< velocity interpolated to the cell edges
      real                                       :: dti     !< dt/di
      real                                       :: v       !< auxiliary variable to compute EMF
      real                                       :: w       !< EMF component
      real                                       :: dw      !< The second-order correction to EMF component
      real                                       :: dwm     !< face centered EMF interpolated to left cell-edge
      real                                       :: dwp     !< face centered EMF interpolated to right cell-edge
      integer                                    :: i       !< auxiliary array indicator
      integer                                    :: ip      !< i+1
      integer                                    :: ipp     !< i+2
      integer                                    :: im      !< i-1

! unlike the B field, the vibj lives on the right cell boundary
      vh = 0.0

! velocity interpolation to the cell boundaries

      vh(1:n-1) =(vg(1:n-1)+ vg(2:n))*half;     vh(n) = vh(n-1)

      dti = dt*idi

! face-centered EMF components computation, depending on the sign of vh, the components are upwinded  to cell edges, leading to 1st order EMF

      where (vh > 0.)
         vibj1=b*vg
      elsewhere
         vibj1=eoshift(b*vg,1,boundary=big)
      endwhere

! values of magnetic field computation in Runge-Kutta half step

      ! TODO: GEOFACTOR missing
      b1(2:n) = b(2:n) - (vibj1(2:n) - vibj1(1:n-1)) * dti * half;    b1(1) = b(2)

      do i = 3, n-3
         ip  = i  + 1
         ipp = ip + 1
         im  = i  - 1
         v   = vh(i)

! recomputation of EMF components (w) with b1 and face centered EMF interpolation to cell-edges (dwp, dwm), depending on the sign of v.

         if (v > 0.0) then
            w   = vg(i) * b1(i)
            dwp = (vg(ip) * b1(ip) - w) * half
            dwm = (w - vg(im) * b1(im)) * half
         else
            w   = vg(ip) * b1(ip)
            dwp = (w - vg(ipp) * b1(ipp)) * half
            dwm = (vg(i) * b1(i) - w) * half
         endif

! the second-order corrections to the EMF components computation with the aid of the van Leer monotonic interpolation and 2nd order EMF computation

         dw=0.0
         if (dwm * dwp > 0.0) dw = 2.0 * dwm * dwp / (dwm + dwp)
         vibj(i) = (w + dw) * dt
      enddo
      return
   end subroutine tvdb
!/*
!>
!! \brief Subroutine implements the Relaxing TVD scheme for conserved physical quantities
!!
!! The main point of the Relaxing TVD scheme is to decompose vectors of conservative variables \f$u\f$ and %fluxes \f$F\f$
!! into left-moving and right-moving waves:
!! \f{equation}
!! u=u^L+u^P,
!! \f}
!! where
!! \f{equation}
!! u^L=\frac{1}{2}\left(U-\frac{F}{c}\right), u^P=\frac{1}{2}\left(U+\frac{F}{c}\right).
!! \f}
!! The symbol \f$c\f$ stands for freezing speed - a function that satisfies \f$c\ge \max\left(|v\pm c_f|\right)\f$,
!! \f$v\f$ is the fluid velocity and \f$c_f\f$ is the fast magnetosonic speed.
!! The %fluxes then can be written as
!! \f{equation}
!! F^L=-cu^L, F^P=cu^P,
!! \f}
!! and their sum is the flux of \f$u\f$
!! \f{equation}
!! F=F^L+F^P.
!! \f}
!!
!! To make time integration PIERNIK uses Runge-Kutta scheme. We can choose between the first and the second order accuracy.
!! The second order scheme consists of the following steps:
!! \n (1) First order %fluxes \f$\vec{F}_{i\pm 1/2}^{(1)L,R}\f$   are
!!    calculated together with source terms \f$\vec{S}_i(\vec{u})\f$ at \f$t^n\f$.
!! \n (2) Fluxes and source terms derived in the first step are used to calculate
!!    \f$\vec{u}^{n+1/2}\f$ at \f$t^{n+1/2}\f$.
!! \n (3) Second order %fluxes \f$\vec{F}_{i+1/2}^{(2)}\f$, obtained via monotonic, upwind
!!    interpolation to cell boundaries,  and source terms \f$\vec{S}\f$ are evaluated for
!!    \f$\vec{u}^{n+1/2}\f$ at \f$t^{n+1/2}\f$.
!! \n (4) Update of \f$\Delta\vec{u}\f$, corresponding to the full
!!    %timestep \f$\Delta t\f$ is done, using %fluxes and source terms calculated
!!    at the intermediate time step \f$t^{n+1/2}\f$.
!!
!! To achieve second order spatial accuracy, a monotone upwind interpolation of %fluxes onto cell boundaries is made,
!! with the aid of a flux limiter, to obtain the Monotone Upwind Scheme for Conservation Laws (MUSCL) (step (3) in Runge-Kutta scheme).
!! The monotone interpolation is used to avoid spurious oscillations in discrete solutions of higher order.
!! The Total Variation Diminishing property of the numerical scheme is related to the measure of the overall amount
!! of oscillations, called Total Variation.
!!
!! \todo Do not pass i1 and i2, pass optional pointer to gravacc instead
!<
!*/

! OPT: 15% of CPU time spent in the relaxing_tvd routine is attributed to the entry point. The rest is more or less evenly distributed across all array operations
! OPT: \todo try to pass pointers instead of arrays, or assemble the arrays here
! OPT: n is usually short enough for all the data to fit L2 cache (checked on 512kB)
! OPT: we may also try to work on bigger parts of the u(:,:,:,:) at a time , but the exact amount may depend on size of the L2 cache
! OPT: try an explicit loop over n to see if better pipelining can be achieved

   subroutine relaxing_tvd(n, u, u0, bb, divv, cs_iso2, istep, sweep, i1, i2, dx, dt, cg, eflx, sources, adv_vel)

      use constants,        only: one, zero, half, GEO_XYZ, GEO_RPZ, LO, xdim, ydim, zdim
      use dataio_pub,       only: msg, die
      use domain,           only: dom
      use fluidindex,       only: iarr_all_dn, iarr_all_mx, iarr_all_my, flind, nmag
#ifndef ISO
      use fluidindex,       only: iarr_all_en
#endif /* !ISO */
      use fluxes,           only: flimiter, all_fluxes
      use fluxtypes,        only: ext_fluxes
      use fluidtypes,       only: component_fluid
      use func,             only: emag, ekin
      use global,           only: smalld, integration_order, use_smalld, smallei
      use grid_cont,        only: grid_container
      use gridgeometry,     only: gc, GC1, GC2, GC3, geometry_source_terms
      use mass_defect,      only: local_magic_mass
#ifdef BALSARA
      use interactions,     only: balsara_implicit_interactions
#else /* !BALSARA */
      use interactions,     only: fluid_interactions
#endif /* !BALSARA */
#ifdef GRAV
      use gravity,          only: grav_pot2accel
#endif /* GRAV */
#ifdef COSM_RAYS
      use initcosmicrays,   only: iarr_crs, smallecr
      use sourcecosmicrays, only: src_gpcr
#ifdef COSM_RAYS_SOURCES
      use initcosmicrays,   only: iarr_crn
      use sourcecosmicrays, only: src_crn
#endif /* COSM_RAYS_SOURCES */
#endif /* COSM_RAYS */
#ifdef CORIOLIS
      use coriolis,         only: coriolis_force
#endif /* CORIOLIS */
#ifdef NON_INERTIAL
      use non_inertial,     only: non_inertial_force
#endif /* NON_INERTIAL */
#ifdef SHEAR
      use shear,            only: shear_acc
#endif /* SHEAR */

      implicit none

      integer(kind=4),               intent(in)    :: n                  !< array size
      real, dimension(n, flind%all), intent(inout) :: u                  !< vector of conservative variables
      real, dimension(n, flind%all), intent(in)    :: u0                 !< vector of conservative variables
      real, dimension(n, nmag),      intent(in)    :: bb                 !< local copy of magnetic field
      real, dimension(:), pointer,   intent(in)    :: divv               !< vector of velocity divergence used in cosmic ray advection
      real, dimension(:), pointer,   intent(in)    :: cs_iso2            !< square of local isothermal sound speed
      integer,                       intent(in)    :: istep              !< step number in the time integration scheme
      integer(kind=4),               intent(in)    :: sweep              !< direction (x, y or z) we are doing calculations for
      integer,                       intent(in)    :: i1                 !< coordinate of sweep in the 1st remaining direction
      integer,                       intent(in)    :: i2                 !< coordinate of sweep in the 2nd remaining direction
      real,                          intent(in)    :: dx                 !< cell length
      real,                          intent(in)    :: dt                 !< time step
      type(grid_container), pointer, intent(in)    :: cg                 !< current grid piece
      type(ext_fluxes),              intent(inout) :: eflx               !< external fluxes
      logical,                       intent(in)    :: sources            !< apply source terms
      real, dimension(n, flind%fluids), intent(in), optional :: adv_vel  !< advection velocity

#ifdef GRAV
      integer                                      :: ind                !< fluid index
      real, dimension(n)                           :: gravacc            !< acceleration caused by gravitation
#endif /* GRAV */

      real                                         :: dtx                !< dt/dx
      real, dimension(n, flind%all)                 :: cfr                !< freezing speed
!locals
      real, dimension(n, flind%fluids)              :: acc                !< acceleration
      real, dimension(n, flind%all)                 :: w                  !< auxiliary vector to calculate fluxes
      real, dimension(n, flind%all)                 :: fr                 !< flux of the right-moving waves
      real, dimension(n, flind%all)                 :: fl                 !< flux of the left-moving waves
      real, dimension(n, flind%all)                 :: fu                 !< sum of fluxes of right- and left-moving waves
      real, dimension(n, flind%all)                 :: dfp                !< second order correction of left/right-moving waves flux on the right cell boundary
      real, dimension(n, flind%all)                 :: dfm                !< second order correction of left/right-moving waves flux on the left cell boundary
      real, dimension(n, flind%all)                 :: u1                 !< updated vector of conservative variables (after one timestep in second order scheme)
      real, dimension(n, flind%fluids)              :: geosrc             !< source terms caused by geometry of coordinate system
      real, dimension(n, flind%fluids), target      :: pressure           !< gas pressure
      real, dimension(n, flind%fluids), target      :: density            !< gas density
      real, dimension(n, flind%fluids), target      :: vel_sweep          !< velocity in the direction of current sweep
      real, dimension(:,:),            pointer      :: dens, vx
      logical                                       :: full_dim

#ifdef COSM_RAYS
      real, dimension(n)                            :: grad_pcr
      real, dimension(n, flind%crs%all)             :: decr
#ifdef COSM_RAYS_SOURCES
      real, dimension(n, flind%crn%all)             :: srccrn
#endif /* COSM_RAYS_SOURCES */
#endif /* COSM_RAYS */

      real, dimension(n)              :: kin_ener, int_ener, mag_ener

      real, dimension(2,2), parameter              :: rk2coef = reshape( [ one, half, zero, one ], [ 2, 2 ] )

      class(component_fluid), pointer :: pfl
      integer :: ifl

#if !(defined COSM_RAYS && defined IONIZED)
      integer                                      :: dummy
      if (.false.) dummy = size(divv(:)) ! suppress compiler warnings
#endif /* !(COSM_RAYS && IONIZED) */

      !OPT: try to avoid these explicit initializations of u1(:,:) and u0(:,:)
      dtx      = dt / dx
      full_dim = n > 1

      u1 = u

      if (present(adv_vel)) vel_sweep = adv_vel !TODO can be done better
      vx   => vel_sweep
      dens => density

      density(:,:) = u(:, iarr_all_dn)

      if (full_dim) then
         ! Fluxes calculation for cells centers
         call all_fluxes(n, w, cfr, u1, bb, pressure, vel_sweep, cs_iso2, present(adv_vel))
         ! Right and left fluxes decoupling

         ! original code
         ! fl(1:n-1, :) = (cfr(2:n, :)*u1(2:n, :) - wl(2:n, :)) * 0.5
         ! fr          = (cfr*u1 + w) * 0.5
         ! following is equivalent but faster

         fl(1:n-1, :) = (u1(2:n, :) * cfr(2:n, :) - w(2:n, :)) * half
         fl(n, :) = fl(n-1, :)
         fr(2:n, :) = fl(1:n-1, :) + w(2:n, :)
         fr(1, :) = fr(2, :)

         if (istep == 2) then

            ! Second order flux corrections
            dfp(1:n-1, :) = half * (fr(2:n, :) - fr(1:n-1, :)); dfp(n, :) = dfp(n-1, :)
            dfm(2:n, :)   = dfp(1:n-1, :);                      dfm(1, :) = dfm(2, :)
            ! Flux limiter application
            call flimiter(fr, dfm, dfp)

            dfp(1:n-1, :) = half * (fl(1:n-1, :) - fl(2:n, :)); dfp(n, :) = dfp(n-1, :)
            dfm(2:n, :)   = dfp(1:n-1, :);                      dfm(1, :) = dfm(2, :)
            call flimiter(fl, dfm, dfp)
            !OPT 60% of D1mr and 40% D1mw occurred in few above lines (D1mr = 0.1% Dr, D1mw = 0.5% Dw)
            ! That ^^ should be fixed now, please confirm
         endif

         ! u update
         fu = fr - fl

         ! Setting uflx to 0 can be used to enforce reflecting boundary
         ! To enforce diode boundaries one can either:
         ! * Set fl or fr to 0 (depending on side)
         ! or
         ! * Set f0 to 0 only when it would produce incoming flux.
         ! I don't remember which approach was already (unsuccesfully) tested
         ! \todo Get rid of use of cg
         ! \todo remove transpositions by changing index order in eflx
         if (associated(eflx%li)) fu(eflx%li%index - cg%lhn(sweep, LO) + 1, :) = eflx%li%uflx
         if (associated(eflx%ri)) fu(eflx%ri%index - cg%lhn(sweep, LO)    , :) = eflx%ri%uflx
         if (associated(eflx%lo)) eflx%lo%uflx = fu(eflx%lo%index - cg%lhn(sweep, LO),     :)
         if (associated(eflx%ro)) eflx%ro%uflx = fu(eflx%ro%index - cg%lhn(sweep, LO) + 1, :)

         if (dom%geometry_type == GEO_RPZ) then
            if (sweep == ydim) then
               !> BEWARE: iarr_all_mx points to the y-momentum in y-sweep
               if (associated(eflx%li)) fu(eflx%li%index - cg%lhn(sweep, LO) + 1, iarr_all_mx) = eflx%li%uflx(iarr_all_mx) / cg%x(i2)
               if (associated(eflx%ri)) fu(eflx%ri%index - cg%lhn(sweep, LO),     iarr_all_mx) = eflx%ri%uflx(iarr_all_mx) / cg%x(i2)
               if (associated(eflx%lo)) eflx%lo%uflx(iarr_all_mx) = fu(eflx%lo%index - cg%lhn(sweep, LO),     iarr_all_mx) * cg%x(i2)
               if (associated(eflx%ro)) eflx%ro%uflx(iarr_all_mx) = fu(eflx%ro%index - cg%lhn(sweep, LO) + 1, iarr_all_mx) * cg%x(i2)
            else if (sweep == zdim) then
               if (associated(eflx%li)) fu(eflx%li%index - cg%lhn(sweep, LO) + 1, :) = eflx%li%uflx / cg%x(i1)
               if (associated(eflx%ri)) fu(eflx%ri%index - cg%lhn(sweep, LO),     :) = eflx%ri%uflx / cg%x(i1)
               if (associated(eflx%lo)) eflx%lo%uflx = fu(eflx%lo%index - cg%lhn(sweep, LO),     :) * cg%x(i1)
               if (associated(eflx%ro)) eflx%ro%uflx = fu(eflx%ro%index - cg%lhn(sweep, LO) + 1, :) * cg%x(i1)
               if (associated(eflx%li)) fu(eflx%li%index - cg%lhn(sweep, LO) + 1, iarr_all_my) = eflx%li%uflx(iarr_all_my) / cg%x(i1)**2
               if (associated(eflx%ri)) fu(eflx%ri%index - cg%lhn(sweep, LO),     iarr_all_my) = eflx%ri%uflx(iarr_all_my) / cg%x(i1)**2
               if (associated(eflx%lo)) eflx%lo%uflx(iarr_all_my) = fu(eflx%lo%index - cg%lhn(sweep, LO),     iarr_all_my) * cg%x(i1)**2
               if (associated(eflx%ro)) eflx%ro%uflx(iarr_all_my) = fu(eflx%ro%index - cg%lhn(sweep, LO) + 1, iarr_all_my) * cg%x(i1)**2
            endif
         endif

         if (dom%geometry_type == GEO_XYZ) then
            u1(2:n, :) = u0(2:n, :) - rk2coef(integration_order,istep) *                  dtx * (                fu(2:n, :) -                fu(1:n-1, :) )
         else
            u1(2:n, :) = u0(2:n, :) - rk2coef(integration_order,istep) * gc(GC1,2:n, :) * dtx * ( gc(GC2,2:n, :)*fu(2:n, :) - gc(GC3,2:n, :)*fu(1:n-1, :) )
         endif
         u1(1, :)   = u1(2, :)
      else
         ! normally vx => vel_sweep is calculated in fluxes, since we don't go
         ! there we need to do it manually here
         vel_sweep = u1(:, iarr_all_mx) / u1(:, iarr_all_dn)
      endif ! (n > 1)

      if (use_smalld) then
         ! This is needed e.g. for outflow boundaries in presence of perp. gravity
         select case (dom%geometry_type)
            case (GEO_XYZ)
               local_magic_mass(:) = local_magic_mass(:) - sum(u1(dom%nb+1:n-dom%nb, iarr_all_dn), dim=1) * cg%dvol
               u1(:, iarr_all_dn) = max(u1(:, iarr_all_dn),smalld)
               local_magic_mass(:) = local_magic_mass(:) + sum(u1(dom%nb+1:n-dom%nb, iarr_all_dn), dim=1) * cg%dvol
            case (GEO_RPZ)
               select case (sweep)
                  case (xdim)
                     do ifl = lbound(iarr_all_dn, dim=1), ubound(iarr_all_dn, dim=1)
                        local_magic_mass(ifl) = local_magic_mass(ifl) - sum(u1(dom%nb+1:n-dom%nb, iarr_all_dn(ifl)) * cg%x(cg%is:cg%ie)) * cg%dvol
                     enddo
                     u1(:, iarr_all_dn) = max(u1(:, iarr_all_dn),smalld)
                     do ifl = lbound(iarr_all_dn, dim=1), ubound(iarr_all_dn, dim=1)
                        local_magic_mass(ifl) = local_magic_mass(ifl) + sum(u1(dom%nb+1:n-dom%nb, iarr_all_dn(ifl)) * cg%x(cg%is:cg%ie)) * cg%dvol
                     enddo
                  case (ydim)
                     local_magic_mass(:) = local_magic_mass(:) - sum(u1(dom%nb+1:n-dom%nb, iarr_all_dn), dim=1) * cg%dvol * cg%x(i2)
                     u1(:, iarr_all_dn) = max(u1(:, iarr_all_dn),smalld)
                     local_magic_mass(:) = local_magic_mass(:) + sum(u1(dom%nb+1:n-dom%nb, iarr_all_dn), dim=1) * cg%dvol * cg%x(i2)
                  case (zdim)
                     local_magic_mass(:) = local_magic_mass(:) - sum(u1(dom%nb+1:n-dom%nb, iarr_all_dn), dim=1) * cg%dvol * cg%x(i1)
                     u1(:, iarr_all_dn) = max(u1(:, iarr_all_dn),smalld)
                     local_magic_mass(:) = local_magic_mass(:) + sum(u1(dom%nb+1:n-dom%nb, iarr_all_dn), dim=1) * cg%dvol * cg%x(i1)
               end select
            case default
               call die("[rtvd:relaxing_tvd] Unsupported geometry")
         end select
      else
         if (any(u1(:, iarr_all_dn) < 0.0)) then
            write(msg,'(3A,I4,1X,I4,A)') "[rtvd:relaxing_tvd] negative density in sweep ",sweep,"( ", i1, i2, " )"
            call die(msg)
         endif
      endif

! Source terms -------------------------------------
      if (sources) then
         geosrc = geometry_source_terms(u, pressure, sweep, cg)  ! n safe

         u1(:, iarr_all_mx) = u1(:, iarr_all_mx) + rk2coef(integration_order,istep)*geosrc(:,:)*dt ! n safe

         acc = 0.0
#ifndef BALSARA
         acc = acc + fluid_interactions(dens, vx)  ! n safe
#else /* !BALSARA */
         call balsara_implicit_interactions(u1, u0, vx, cs_iso2, dt, istep) ! n safe
#endif /* !BALSARA */
#ifdef SHEAR
         acc = acc + shear_acc(sweep,u) ! n safe
#endif /* SHEAR */
#ifdef CORIOLIS
         acc = acc + coriolis_force(sweep,u) ! n safe
#endif /* CORIOLIS */
#ifdef NON_INERTIAL
         acc = acc + non_inertial_force(sweep, u, cg)
#endif /* NON_INERTIAL */

         if (full_dim) then
#ifdef GRAV
            call grav_pot2accel(sweep, i1, i2, n, gravacc, istep, cg)

            do ind = 1, flind%fluids
               acc(:, ind) =  acc(:, ind) + gravacc(:)
            enddo
#endif /* !GRAV */

            acc(n, :) = acc(n-1, :)
            acc(1, :) = acc(2, :)
         endif

         u1(:, iarr_all_mx) = u1(:, iarr_all_mx) + rk2coef(integration_order,istep)*acc(:,:)*u(:, iarr_all_dn)*dt
#ifndef ISO
         u1(:, iarr_all_en) = u1(:, iarr_all_en) + rk2coef(integration_order,istep)*acc(:,:)*u(:, iarr_all_mx)*dt
#endif /* !ISO */

! --------------------------------------------------

#if defined COSM_RAYS && defined IONIZED
         if (full_dim) then
            call src_gpcr(u, n, dx, divv, decr, grad_pcr)
            u1(:,                iarr_crs(:)) = u1(:,               iarr_crs(:)) + rk2coef(integration_order,istep) * decr(:,:) * dt
            u1(:,                iarr_crs(:)) = max(smallecr, u1(:, iarr_crs(:)))
            u1(:, iarr_all_mx(flind%ion%pos)) = u1(:, iarr_all_mx(flind%ion%pos)) + rk2coef(integration_order,istep) * grad_pcr * dt
#ifndef ISO
            u1(:, iarr_all_en(flind%ion%pos)) = u1(:, iarr_all_en(flind%ion%pos)) + rk2coef(integration_order,istep) * vx(:, flind%ion%pos) * grad_pcr * dt
#endif /* !ISO */
         endif
#ifdef COSM_RAYS_SOURCES
         call src_crn(u, n, srccrn, rk2coef(integration_order, istep) * dt) ! n safe
         u1(:, iarr_crn) = u1(:, iarr_crn) +  rk2coef(integration_order, istep)*srccrn(:,:)*dt
#endif /* COSM_RAYS_SOURCES */
#endif /* COSM_RAYS && IONIZED */
      endif ! sources

      do ifl = 1, flind%fluids
         pfl => flind%all_fluids(ifl)%fl
         if (pfl%has_energy) then
            kin_ener = ekin(u1(:, pfl%imx), u1(:, pfl%imy), u1(:, pfl%imz), u1(:, pfl%idn))
            if (pfl%is_magnetized) then
               mag_ener = emag(bb(:, xdim), bb(:, ydim), bb(:, zdim))
               int_ener = u1(:, pfl%ien) - kin_ener - mag_ener
            else
               int_ener = u1(:, pfl%ien) - kin_ener
            endif

            int_ener = max(int_ener, smallei)

            u1(:, pfl%ien) = int_ener + kin_ener
            if (pfl%is_magnetized) u1(:, pfl%ien) = u1(:, pfl%ien) + mag_ener
         endif
      enddo

      u(:,:) = u1(:,:)

   end subroutine relaxing_tvd

!==========================================================================================
end module rtvd
