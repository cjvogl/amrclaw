c
c
c     =====================================================
      subroutine flux1(maxm,meqn,maux,mbc,mx,
     &                 q1d,dtdx1d,aux1,
     &                 faddm,faddp,cfl1d,wave,s,
     &                 amdq,apdq,cqxx,bmasdq,bpasdq,rp1)
c     =====================================================
c
c     # clawpack routine ...  modified for AMRCLAW
c
c     # Compute the modification to flux f that is generated by
c     # all interfaces along a 1D slice of the grid.
c     # This value is passed into the Riemann solver. The flux modifications
c     # go into the array fadd.  The notation is written assuming
c     # we are solving along a 1D slice in the x-direction.
c
c     # fadd(*,i,.) modifies F to the left of cell i
c
c     # The method used is specified by method(2:3):
c
c         method(2) = 1 if only first order increment waves are to be used.
c                   = 2 if second order correction terms are to be added, with
c                       a flux limiter as specified by mthlim.  
c
c         method(3) = 0 if no transverse propagation is to be applied.
c                       Increment and perhaps correction waves are propagated
c                       normal to the interface.
c
c     Note that if mcapa>0 then the capa array comes into the second 
c     order correction terms, and is already included in dtdx1d:
c        dtdx1d(i) = dt/dx                      if mcapa= 0
c                  = dt/(dx*aux(mcapa,i,jcom))  if mcapa = 1
c
c     Notation:
c        The jump in q (q1d(i,:)-q1d(i-1,:))  is split by rp1 into
c            amdq =  the left-going flux difference  A^- Delta q
c            apdq = the right-going flux difference  A^+ Delta q
c
c
      use amr_module
      implicit double precision (a-h,o-z)
      external rp1
      dimension    q1d(meqn,1-mbc:maxm+mbc)
      dimension   amdq(meqn,1-mbc:maxm+mbc)
      dimension   apdq(meqn,1-mbc:maxm+mbc)
      dimension   cqxx(meqn,1-mbc:maxm+mbc)
      dimension   faddm(meqn,1-mbc:maxm+mbc)
      dimension   faddp(meqn,1-mbc:maxm+mbc)
      dimension dtdx1d(1-mbc:maxm+mbc)
      dimension aux1(maux,1-mbc:maxm+mbc)
c
      dimension     s(mwaves, 1-mbc:maxm+mbc)
      dimension  wave(meqn, mwaves, 1-mbc:maxm+mbc)
c
      logical limit
      common /comxt/ dtcom,dxcom,tcom,icom
c
      limit = .false.
      do 5 mw=1,mwaves
         if (mthlim(mw) .gt. 0) limit = .true.
   5     continue
c
c     # initialize flux increments:
c     -----------------------------
c
       do 10 i = 1-mbc, mx+mbc
         do 20 m=1,meqn
            faddm(m,i) = 0.d0
            faddp(m,i) = 0.d0
   20    continue
   10  continue
c
c
c     # solve Riemann problem at each interface and compute Godunov updates
c     ---------------------------------------------------------------------
c
      call rp1(maxm,meqn,mwaves,maux,mbc,mx,q1d,q1d,
     &          aux1,aux1,wave,s,amdq,apdq)
c
c     # Set fadd for the donor-cell upwind method (Godunov)
      do 40 i=1,mx+1
         do 40 m=1,meqn
            faddp(m,i) = faddp(m,i) - apdq(m,i)
            faddm(m,i) = faddm(m,i) + amdq(m,i)
   40       continue
c
c     # compute maximum wave speed for checking Courant number:
      cfl1d = 0.d0
      do 50 mw=1,mwaves
         do 50 i=1,mx+1
c          # if s>0 use dtdx1d(i) to compute CFL,
c          # if s<0 use dtdx1d(i-1) to compute CFL:
            cfl1d = dmax1(cfl1d, dtdx1d(i)*s(mw,i),
     &                          -dtdx1d(i-1)*s(mw,i))
   50       continue
c
      if (method(2).eq.1) go to 130
c
c     # modify F fluxes for second order q_{xx} correction terms:
c     -----------------------------------------------------------
c
c     # apply limiter to waves:
      if (limit) call limiter(maxm,meqn,mwaves,mbc,mx,wave,s,mthlim)
c
      do 120 i = 1, mx+1
c
c        # For correction terms below, need average of dtdx in cell
c        # i-1 and i.  Compute these and overwrite dtdx1d:
c
c        # modified in Version 4.3 to use average only in cqxx, not transverse
         dtdxave = 0.5d0 * (dtdx1d(i-1) + dtdx1d(i))

c
c        # second order corrections:

         do 120 m=1,meqn
            cqxx(m,i) = 0.d0
            do 119 mw=1,mwaves
c
               if (use_fwaves) then
                   abs_sign = dsign(1.d0,s(mw,i))
                 else
                   abs_sign = dabs(s(mw,i))
                 endif

               cqxx(m,i) = cqxx(m,i) + abs_sign
     &             * (1.d0 - dabs(s(mw,i))*dtdxave) * wave(m,mw,i)
c
  119          continue
            faddm(m,i) = faddm(m,i) + 0.5d0 * cqxx(m,i)
            faddp(m,i) = faddp(m,i) + 0.5d0 * cqxx(m,i)
  120       continue
c
c
  130  continue
c
      return
      end
