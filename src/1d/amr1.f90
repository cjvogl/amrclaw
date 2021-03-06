!
!  Use adaptive mesh refinement to solve the hyperbolic 1-d equation:
!
!              u  +  f(u)     = 0
!               t         x
!
! or the more general non-conservation law form:
!              u  +  A u     = 0
!               t         x
!
!  using the wave propagation method as in CLAWPACK in combination
!  with the locally uniform embedded grids of AMR.
!
!  Estimate error with Richardson extrap. (in errest.f)
!  + gradient checking (in errsp.f).  Initial conditions set
!  in (qinit.f), b.c.'s in (physbd.f).
!
!  Specify rectangular domain from
!           (xlower) to (xupper).
!
!
! =========================================================================
!
!  This software is made available for research and instructional use only.
!  You may copy and use this software without charge for these non-commercial
!  purposes, provided that the copyright notice and associated text is
!  reproduced on all copies.  For all other uses (including distribution of
!  modified versions), please contact the author at the address given below.
!
!  *** This software is made available "as is" without any assurance that it
!  *** will work for your purposes.  The software may in fact have defects, so
!  *** use the software at your own risk.
!
!  --------------------------------------
!    AMRCLAW Version 5.0,  2012
!    Homepage: http://www.clawpack.org
!  --------------------------------------
!
!   Authors:
!
!             Marsha J. Berger
!             Courant Institute of Mathematical Sciences
!             New York University
!             251 Mercer St.
!             New York, NY 10012
!             berger@cims.nyu.edu
!
!             Randall J. LeVeque
!             Applied Mathematics
!             Box 352420
!             University of Washington,
!             Seattle, WA 98195-2420
!             rjl@uw.edu
!
! =========================================================================
!
!   Modified for 1d problem by Brisa Davis, 2016
!
! =========================================================================
program amr1

    use amr_module, only: dbugunit, parmunit, outunit, inunit, matunit
    use amr_module, only: mxnest, rinfinity, iinfinity
    use amr_module, only: xupper, xlower
    use amr_module, only: hxposs, intratx, kratio
    use amr_module, only: cfl, cflv1, cflmax, evol

    use amr_module, only: checkpt_style, checkpt_interval, tchk, nchkpt
    use amr_module, only: rstfile, check_a

    use amr_module, only: max1d, maxvar, maxlv

    use amr_module, only: method, mthlim, use_fwaves, numgrids
    use amr_module, only: nghost, mwaves, mcapa, auxtype
    use amr_module, only: tol, tolsp, flag_richardson, flag_gradient

    use amr_module, only: nghost, mthbc
    use amr_module, only: xperdom

    use amr_module, only: nstop, nout, iout, tfinal, tout, output_style
    use amr_module, only: output_format, printout, verbosity_regrid
    use amr_module, only: output_q_components, output_aux_components
    use amr_module, only: output_aux_onlyonce, matlabu

    use amr_module, only: lfine, lentot, iregridcount, avenumgrids
    use amr_module, only: tvoll, tvollCPU, rvoll, rvol, mstart, possk, ibuff
    use amr_module, only: timeRegridding,timeUpdating, timeValout
    use amr_module, only: timeBound,timeStepgrid, timeFlagger,timeBufnst,timeFilvalTot
    use amr_module, only: timeBoundCPU,timeStepGridCPU,timeSetauxCPU,timeRegriddingCPU
    use amr_module, only: timeSetaux, timeSetauxCPU, timeValoutCPU
    use amr_module, only: kcheck, iorder, lendim, lenmax

    use amr_module, only: dprint, eprint, edebug, gprint, nprint, pprint
    use amr_module, only: rprint, sprint, tprint, uprint

    use amr_module, only: t0, tstart_thisrun

    use regions_module, only: set_regions
    use gauges_module, only: set_gauges, num_gauges

    implicit none

    ! Local variables
    integer :: i, iaux, mw, level
    integer :: ndim, nvar, naux, mcapa1, mindim
    integer :: nstart, nsteps, nv1, nx, lentotsave, num_gauge_SAVE
    integer :: omp_get_max_threads, maxthreads
    real(kind=8) :: time, ratmet, cut, dtinit, dt_max
    logical :: vtime, rest, output_t0    

    ! Timing variables
    integer :: clock_start, clock_finish, clock_rate, ttotal
    real(kind=8) :: cpu_start, cpu_finish,ttotalcpu
    integer, parameter :: timing_unit = 48

    ! Common block variables
    real(kind=8) :: dxmin

    common /comfine/ dxmin

    character(len=364) :: format_string
    character(len=*), parameter :: clawfile = 'claw.data'
    character(len=*), parameter :: amrfile = 'amr.data'
    character(len=*), parameter :: outfile = 'fort.amr'
    character(len=*), parameter :: dbugfile = 'fort.debug'
    character(len=*), parameter :: matfile = 'fort.nplot'
    character(len=*), parameter :: parmfile = 'fort.parameters'
    character(len=*), parameter :: timing_file = 'timing.txt'

    ! Open parameter and debug files
    open(dbugunit,file=dbugfile,status='unknown',form='formatted')
    open(parmunit,file=parmfile,status='unknown',form='formatted')

    maxthreads = 1    !! default, if no openmp

    ! Open AMRClaw primary parameter file
    call opendatafile(inunit,clawfile)

    ! Number of space dimensions, not really a parameter but we read it in and
    ! check to make sure everyone is on the same page. 
    read(inunit,"(i1)") ndim  
    if (ndim /= 1) then
        print *,'Error ***   ndim = 1 is required,  ndim = ',ndim
        print *,'*** Are you sure input has been converted'
        print *,'*** to Clawpack 5.x form?'
        stop
    endif
          
    ! Domain variables
    read(inunit,*) xlower
    read(inunit,*) xupper
    read(inunit,*) nx
    read(inunit,*) nvar    ! meqn
    read(inunit,*) mwaves
    read(inunit,*) naux
    read(inunit,*) t0

    ! ==========================================================================
    ! Output Options
    ! Output style
    read(inunit,*) output_style
    if (output_style == 1) then
        read(inunit,*) nout
        read(inunit,*) tfinal
        read(inunit,*) output_t0

        iout = 0
    else if (output_style == 2) then
        read(inunit,*) nout
        allocate(tout(nout))
        read(inunit,*) (tout(i), i=1,nout)
        output_t0 = (tout(1) == t0)
        ! Move output times down one index
        if (output_t0) then
            nout = nout - 1
            do i=1,nout
                tout(i) = tout(i+1)
            enddo
        endif
        iout = 0
        tfinal = tout(nout)
    else if (output_style == 3) then
        read(inunit,*) iout
        read(inunit,*) nstop
        read(inunit,*) output_t0
        nout = 0
        tfinal = rinfinity
    else
        stop "Error ***   Invalid output style."
    endif

    ! Error checking
    if ((output_style == 1) .and. (nout > 0)) then
        allocate(tout(nout))
        do i=1,nout
            tout(i) = t0 + i * (tfinal - t0) / real(nout,kind=8)
        enddo
    endif

    ! What and how to output
    read(inunit,*) output_format
    allocate(output_q_components(nvar))
    read(inunit,*) (output_q_components(i),i=1,nvar)
    if (naux > 0) then
        allocate(output_aux_components(naux))
        read(inunit,*) (output_aux_components(i),i=1,naux)
        read(inunit,*) output_aux_onlyonce
    endif
    ! ==========================================================================

    ! ==========================================================================
    !  Algorithm parameters

    read(inunit,*) possk(1)   ! dt_initial
    read(inunit,*) dt_max     ! largest allowable dt
    read(inunit,*) cflv1      ! cfl_max
    read(inunit,*) cfl        ! clf_desired
    read(inunit,*) nv1        ! steps_max
      
    if (output_style /= 3) then
        !nstop = nv1
        nstop = iinfinity   ! basically disabled this test
    endif

    read(inunit,*) vtime      ! dt_variable
    if (vtime) then
        method(1) = 2
    else
        method(1) = 1
    endif

    read(inunit,*) method(2)  ! order
    iorder = method(2)

    read(inunit,*) method(3)   ! verbosity
    read(inunit,*) method(4)   ! src_split
    read(inunit,*) mcapa1
    
    read(inunit,*) use_fwaves
    allocate(mthlim(mwaves))
    read(inunit,*) (mthlim(mw), mw=1,mwaves)

    ! Boundary conditions
    read(inunit,*) nghost
    read(inunit,*) mthbc(1)
    read(inunit,*) mthbc(2)

    ! 1 = left, 2 = right
    xperdom = (mthbc(1) == 2 .and. mthbc(2) == 2)

    if ((mthbc(1).eq.2 .and. mthbc(2).ne.2) .or. &
        (mthbc(2).eq.2 .and. mthbc(1).ne.2)) then
        
        print *, '*** ERROR ***  periodic boundary conditions: '
        print *, '  mthbc(1) and mthbc(2) must BOTH be set to 2'
        stop
    endif

    !if ((mthbc(3).eq.5 .and. mthbc(4).ne.5) .or. &
    !    (mthbc(4).eq.5 .and. mthbc(3).ne.5)) then
    
    !    print *, '*** ERROR ***  sphere bcs at top and bottom: '
    !    print *, '  mthbc(3) and mthbc(4) must BOTH be set to 5'
    !    stop
    !endif

    ! ==========================================================================
    !  Restart and Checkpointing

    read(inunit,*) rest
    read(inunit,*) rstfile

    read(inunit,*) checkpt_style
    if (checkpt_style == 0) then
        ! Never checkpoint:
        checkpt_interval = iinfinity

    else if (abs(checkpt_style) == 2) then
        read(inunit,*) nchkpt
        allocate(tchk(nchkpt))
        read(inunit,*) (tchk(i), i=1,nchkpt)

    else if (abs(checkpt_style) == 3) then
        ! Checkpoint every checkpt_interval steps on coarse grid
        read(inunit,*) checkpt_interval
    endif

    close(inunit)

    ! ==========================================================================
    !  Refinement Control
    call opendatafile(inunit, amrfile)

    read(inunit,*) mxnest
    if (mxnest <= 0) then
        stop 'Error ***   mxnest (amrlevels_max) <= 0 not allowed'
    endif
          
    if (mxnest > maxlv) then
        stop 'Error ***   mxnest > max. allowable levels (maxlv) in common'
    endif
      
    ! Anisotropic refinement always allowed in 5.x:
    read(inunit,*) (intratx(i),i=1,max(1,mxnest-1))
    read(inunit,*) (kratio(i), i=1,max(1,mxnest-1))
    read(inunit,*)

    do i=1,mxnest-1
        if ((intratx(i) > max1d)) then
            print *, ""
            format_string = "(' *** Error: Refinement ratios must be no " // &
                            "larger than max1d = ',i5,/,'     (set max1d" // &
                            " in amr_module.f90)')"
            print format_string, max1d
            stop
        endif
    enddo

    if (naux > 0) then
        allocate(auxtype(naux))
        read(inunit,*) (auxtype(iaux), iaux=1,naux)
    endif
    read(inunit,*)

    read(inunit,*) flag_richardson
    read(inunit,*) tol            ! for richardson
    read(inunit,*) flag_gradient
    read(inunit,*) tolsp          ! for gradient
    read(inunit,*) kcheck
    read(inunit,*) ibuff
    read(inunit,*) cut
    read(inunit,*) verbosity_regrid

    ! read verbose/debugging flags
    read(inunit,*) dprint
    read(inunit,*) eprint
    read(inunit,*) edebug
    read(inunit,*) gprint
    read(inunit,*) nprint
    read(inunit,*) pprint
    read(inunit,*) rprint
    read(inunit,*) sprint
    read(inunit,*) tprint
    read(inunit,*) uprint

    close(inunit)
    ! Finished with reading in parameters
    ! ==========================================================================

    ! Look for capacity function via auxtypes:
    mcapa = 0
    do iaux = 1, naux
        if (auxtype(iaux) == "capacity") then
            if (mcapa /= 0) then
                print *, " only 1 capacity allowed"
                stop
            else
                mcapa = iaux
            endif
        endif

        ! Change to Version 4.1 terminology:
        if (auxtype(iaux) == "leftface") auxtype(iaux) = "xleft"
        if (auxtype(iaux) == "bottomface") auxtype(iaux) = "yleft"
        if (.not. (auxtype(iaux) .eq."xleft" .or. &
                   auxtype(iaux) .eq. "capacity".or. &
                   auxtype(iaux) .eq. "center"))  then
            print *," unknown type for auxiliary variables"
            print *," use  xleft/center/capacity"
            stop
        endif
    enddo

    ! Error checking of input data
    if (mcapa /= mcapa1) then
        stop 'Error ***  mcapa does not agree with auxtype'
    endif
    if (nvar > maxvar) then
        stop 'Error ***   nvar > maxvar in common'
    endif
    if (2*nghost > nx) then
        mindim = 2 * nghost
        print *, 'Error ***   need finer domain >', mindim, ' cells'
        stop
    endif
    if (mcapa > naux) then
        stop 'Error ***   mcapa > naux in input file'
    endif

    if (.not. vtime .and. nout /= 0) then
        print *,        ' cannot specify output times with fixed dt'
        stop
    endif


    ! Write out parameters
    write(parmunit,*) ' '
    write(parmunit,*) 'Running amrclaw with parameter values:'
    write(parmunit,*) ' '


    print *, ' '
    print *, 'Running amrclaw ...  '
    print *, ' '

    hxposs(1) = (xupper - xlower) / nx

    ! initialize frame number for output.  
    ! Note: might be reset in restrt if this is a restart
    if (output_t0) then
        matlabu   = 0
    else
        matlabu   = 1
    endif

    ! Boolean check_a tells which checkpoint file to use next if alternating
    ! between only two files via check_twofiles.f, unused otherwise.
    ! May be reset in call to restrt, otherwise default to using aaaaa file.
    check_a = .true.   

    if (rest) then

        open(outunit, file=outfile, status='unknown', position='append', &
                      form='formatted')

        call restrt(nsteps,time,nvar,naux)
        nstart  = nsteps
        tstart_thisrun = time
        print *, ' '
        print *, 'Restarting from previous run'
        print *, '   at time = ',time
        print *, ' '
        ! Call user routine to set up problem parameters:
        call setprob()

        ! Non-user data files
        call set_regions()
        call set_gauges(rest, nvar)

    else

        open(outunit, file=outfile, status='unknown', form='formatted')

        tstart_thisrun = t0

        ! Call user routine to set up problem parameters:
        call setprob()

        ! Non-user data files
        call set_regions()
        call set_gauges(rest, nvar)

        cflmax = 0.d0   ! otherwise use previously heckpointed val

        lentot = 0
        lenmax = 0
        lendim = 0
        rvol   = 0.0d0
        do i   = 1, mxnest
            rvoll(i) = 0.0d0
        enddo
        evol = 0.0d0
        call stst1()


        ! changed 4/24/09: store dxmin,dymin for setaux before
        ! grids are made, in order to average up from finest grid.
        dxmin = hxposs(mxnest)

        call domain(nvar,vtime,nx,naux,t0)

        ! Hold off on gauges until grids are set. 
        ! The fake call to advance at the very first timestep 
        ! looks at the gauge array but it is not yet built
        num_gauge_SAVE = num_gauges
        num_gauges = 0
        call setgrd(nvar,cut,naux,dtinit,t0)
        num_gauges = num_gauge_SAVE

! commented out to match 4-x version
!!$        if (possk(1) .gt. dtinit*cflv1/cfl .and. vtime) then
!!$            ! initial time step was too large. reset to dt from setgrd
!!$            print *, "*** Initial time step reset for desired cfl"
!!$            possk(1) = dtinit
!!$            do i = 2, mxnest-1
!!$                possk(i) = possk(i-1)*kratio(i-1)
!!$            end do
!!$        endif

        time = t0
        nstart = 0
    endif

    write(parmunit,*) ' '
    write(parmunit,*) '--------------------------------------------'
    write(parmunit,*) ' '
    write(parmunit,*) '   rest = ', rest, '   (restart?)'
    write(parmunit,*) '   start time = ',time
    write(parmunit,*) ' '

!$   maxthreads = omp_get_max_threads() 
     write(outunit,*)" max threads set to ",maxthreads
     print *," max threads set to ",maxthreads
    
    !
    !  print out program parameters for this run
    !
    format_string = "(/' amrclaw parameters:',//," // &
                      "' error tol            ',e12.5,/," // &
                      "' spatial error tol    ',e12.5,/," // &
                      "' order of integrator     ',i9,/," // &
                      "' error checking interval ',i9,/," // &
                      "' buffer zone size        ',i9,/," // &
                      "' nghost                  ',i9,/," // &
                      "' volume ratio cutoff  ',e12.5,/," // &
                      "' max. refinement level   ',i9,/," // &
                      "' user sub. calling times ',i9,/," // &
                      "' cfl # (if var. delt) ',e12.5,/)"
    write(outunit,format_string) tol,tolsp,iorder,kcheck,ibuff,nghost,cut, &
                                 mxnest,checkpt_interval,cfl
    format_string = "(' xupper(upper corner) ',e12.5,/," // &
                     "' xlower(lower corner) ',e12.5,/," // &
                     "' nx = no. cells in x dir.',i9,/," // &
                     "' refinement ratios       ',6i5,/,/)"
    write(outunit,format_string) xupper,xlower,nx
    write(outunit,"(' refinement ratios:       ',6i5,/)"  ) &
                                                        (intratx(i),i=1,mxnest)
    write(outunit,"(' no. auxiliary vars.     ',i9)") naux
    write(outunit,"('       var ',i5,' of type ', a10)") &
                                                (iaux,auxtype(iaux),iaux=1,naux)
    if (mcapa > 0) write(outunit,"(' capacity fn. is aux. var',i9)") mcapa

    print *, ' '
    print *, 'Done reading data, starting computation ...  '
    print *, ' '


    call outtre (mstart,printout,nvar,naux)
    write(outunit,*) "  original total mass ..."
    call conck(1,nvar,naux,time,rest)
    if (output_t0) then
        call valout(1,lfine,time,nvar,naux)
    endif
    close(parmunit)

    ! Timing
    call system_clock(clock_start,clock_rate)
    call cpu_time(cpu_start)

    ! --------------------------------------------------------
    !  Tick is the main routine which drives the computation:
    ! --------------------------------------------------------

    call tick(nvar,cut,nstart,vtime,time,naux,t0,rest,dt_max)
    ! --------------------------------------------------------

    call system_clock(clock_finish,clock_rate)
    call cpu_time(cpu_finish)
    
    
    !output timing data
    open(timing_unit, file=timing_file, status='unknown', form='formatted')
    write(*,*)
    write(timing_unit,*)
    format_string="('============================== Timing Data ==============================')"
    write(timing_unit,format_string)
    write(*,format_string)
    
    write(*,*)
    write(timing_unit,*)
    
    !Integration time
    format_string="('Integration Time (stepgrid + BC + overhead)')"
    write(timing_unit,format_string)
    write(*,format_string)
    
    !Advanc time
    format_string="('Level           Wall Time (seconds)    CPU Time (seconds)   Total Cell Updates')"
    write(timing_unit,format_string)
    write(*,format_string)
    ttotalcpu=0.d0
    ttotal=0
    do level=1,mxnest
        format_string="(i3,'           ',1f15.3,'        ',1f15.3,'    ', e17.3)"
        write(timing_unit,format_string) level, &
             real(tvoll(level),kind=8) / real(clock_rate,kind=8), tvollCPU(level), rvoll(level)
        write(*,format_string) level, &
             real(tvoll(level),kind=8) / real(clock_rate,kind=8), tvollCPU(level), rvoll(level)
        ttotalcpu=ttotalcpu+tvollCPU(level)
        ttotal=ttotal+tvoll(level)
    end do
    
    format_string="('total         ',1f15.3,'        ',1f15.3,'    ', e17.3)"
    write(timing_unit,format_string) &
             real(ttotal,kind=8) / real(clock_rate,kind=8), ttotalCPU, rvol
    write(*,format_string) &
             real(ttotal,kind=8) / real(clock_rate,kind=8), ttotalCPU, rvol
    
    write(*,*)
    write(timing_unit,*)
    
    
    format_string="('All levels:')"
    write(*,format_string)
    write(timing_unit,format_string)
    
    
    
    !stepgrid
    format_string="('stepgrid      ',1f15.3,'        ',1f15.3,'    ',e17.3)"
    write(timing_unit,format_string) &
         real(timeStepgrid,kind=8) / real(clock_rate,kind=8), timeStepgridCPU
    write(*,format_string) &
         real(timeStepgrid,kind=8) / real(clock_rate,kind=8), timeStepgridCPU
    
    !bound
    format_string="('BC/ghost cells',1f15.3,'        ',1f15.3)"
    write(timing_unit,format_string) &
         real(timeBound,kind=8) / real(clock_rate,kind=8), timeBoundCPU
    write(*,format_string) &
         real(timeBound,kind=8) / real(clock_rate,kind=8), timeBoundCPU
    
    !regridding time
    format_string="('Regridding    ',1f15.3,'        ',1f15.3,'  ')"
    write(timing_unit,format_string) &
            real(timeRegridding,kind=8) / real(clock_rate,kind=8), timeRegriddingCPU
    write(*,format_string) &
            real(timeRegridding,kind=8) / real(clock_rate,kind=8), timeRegriddingCPU
    
    !output time
    format_string="('Output (valout)',1f14.3,'        ',1f15.3,'  ')"
    write(timing_unit,format_string) &
            real(timeValout,kind=8) / real(clock_rate,kind=8), timeValoutCPU
    write(*,format_string) &
            real(timeValout,kind=8) / real(clock_rate,kind=8), timeValoutCPU
    
    write(*,*)
    write(timing_unit,*)
    
    !Total Time
    format_string="('Total time:   ',1f15.3,'        ',1f15.3,'  ')"
    write(timing_unit,format_string) &
            real(clock_finish - clock_start,kind=8) / real(clock_rate,kind=8), &
            cpu_finish-cpu_start
    write(*,format_string) &
            real(clock_finish - clock_start,kind=8) / real(clock_rate,kind=8), &
            cpu_finish-cpu_start
    
    format_string="('Using',i3,' thread(s)')"
    write(timing_unit,format_string) maxthreads
    write(*,format_string) maxthreads
    
    
    write(*,*)
    write(timing_unit,*)
    
    
    write(*,"('Note: The CPU times are summed over all threads.')")
    write(timing_unit,"('Note: The CPU times are summed over all threads.')")
    write(*,"('      Total time includes more than the subroutines listed above')")
    write(timing_unit,"('      Total time includes more than the subroutines listed above')")
    
    
    !end of timing data
    write(*,*)
    write(timing_unit,*)
    format_string="('=========================================================================')"
    write(timing_unit,format_string)
    write(*,format_string)
    write(*,*)
    write(timing_unit,*)
    close(timing_unit)
    
    
    
    
    !write(*,*) " "
    !write(outunit,*) " "
    !format_string = "('Total time to solution = ',1f16.8,' s, using ',i3,' threads')"
    !write(outunit,format_string) &
    !        real(clock_finish - clock_start,kind=8) / real(clock_rate,kind=8), maxthreads
    !write(*,format_string) &
    !        real(clock_finish - clock_start,kind=8) / real(clock_rate,kind=8), maxthreads

    !do level = 1, mxnest            
    !  format_string = "('Total advanc time on level ',i3,' = ',1f16.8,' s')"
    !  write(outunit,format_string) level, &
    !         real(tvoll(level),kind=8) / real(clock_rate,kind=8)
    !  write(*,format_string) level, &
    !         real(tvoll(level),kind=8) / real(clock_rate,kind=8)
    !end do
    !write(*,*) " "
    !write(outunit,*)" "

    !format_string = "('Total updating   time            ',1f16.8,' s')"
    !write(outunit,format_string)  real(timeUpdating,kind=8) / real(clock_rate,kind=8)
    !write(*,format_string) real(timeUpdating,kind=8) / real(clock_rate,kind=8)

    !format_string = "('Total valout     time            ',1f16.8,' s')"
    !write(outunit,format_string)  real(timeValout,kind=8) / real(clock_rate,kind=8)
    !write(*,format_string) real(timeValout,kind=8) / real(clock_rate,kind=8)

    !format_string = "('Total regridding time            ',1f16.8,' s')"
    !write(outunit,format_string)  &
    !         real(timeRegridding,kind=8) / real(clock_rate,kind=8)
    !write(*,format_string)  &
    !         real(timeRegridding,kind=8) / real(clock_rate,kind=8)

    ! Done with computation, cleanup:
    lentotsave = lentot
    call cleanup(nvar,naux)
    if (lentot /= 0) then
        write(outunit,*) lentot," words not accounted for in memory cleanup"
        print *,         lentot," words not accounted for in memory cleanup"
    endif
    
    !
    ! report on statistics
    !
    open(matunit,file=matfile,status='unknown',form='formatted')
    write(matunit,*) matlabu-1
    write(matunit,*) mxnest
    close(matunit)

    write(outunit,*)
    write(outunit,*)
    do i = 1, mxnest
      if (iregridcount(i) > 0) then
        write(outunit,801) i,avenumgrids(i)/iregridcount(i),iregridcount(i)
 801    format("for level ",i3, " average num. grids = ",f10.2," over ",i10,  &
               " regridding steps")
        write(outunit,802) i,numgrids(i)
 802    format("for level ",i3,"  current num. grids = ",i7)
      endif
    end do

    write(outunit,*)
    write(outunit,*)
    write(outunit,"('current  space usage = ',i12)") lentotsave
    write(outunit,"('maximum  space usage = ',i12)") lenmax
    write(outunit,"('need space dimension = ',i12,/)") lendim

    write(outunit,"('number of cells advanced for time integration = ',f20.6)")&
                    rvol
    do level = 1,mxnest
        write(outunit,"(3x,'# cells advanced on level ',i4,' = ',f20.2)") &
                    level, rvoll(level)
    enddo

    write(outunit,"('number of cells advanced for error estimation = ',f20.6,/)") &
                     evol
    if (evol + rvol > 0.d0) then
        ratmet = rvol / (evol + rvol) * 100.0d0
    else
        ratmet = 0.0d0
    endif
    write(outunit,"(' percentage of cells advanced in time  = ', f10.2)") ratmet
    write(outunit,"(' maximum Courant number seen = ', f10.2)") cflmax

    write(outunit,"(//,' ------  end of AMRCLAW integration --------  ')")

    ! Close output and debug files.
    close(outunit)
    close(dbugunit)

end program amr1
