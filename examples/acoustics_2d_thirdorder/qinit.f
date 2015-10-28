
c
c
c
c     =====================================================
       subroutine qinit(meqn,mbc,mx,my,xlower,ylower,
     &                   dx,dy,q,maux,aux)
c     =====================================================
c
c     # Set initial conditions for q.
c     # Acoustics with smooth radially symmetric profile to test accuracy
c
       implicit double precision (a-h,o-z)
       dimension q(meqn,1-mbc:mx+mbc, 1-mbc:my+mbc)
       dimension aux(maux,1-mbc:mx+mbc, 1-mbc:my+mbc)
c

      common /cparam/ rho,bulk,cc,zz

       do 20 i=1,mx
          xcell = xlower + (i-0.5d0)*dx
          do 20 j=1,my
             ycell = ylower + (j-0.5d0)*dy
             if (ycell < 0.0125d0) then
                q(1,i,j) = 1.d-5*dexp(-((xcell-0.1162d0)/4.5d-4)**2)
             else
                q(1,i,j) = 0.d0
             end if
             q(2,i,j) = 0.d0
             q(3,i,j) = 0.d0
  20         continue

       return
       end
