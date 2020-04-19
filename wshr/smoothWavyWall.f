C-----------------------------------------------------------------------
c
c	Ramesh's Periodic Hill w/ wall shape function & ~ target res
c
C
C  user specified routines:
C     - userbc : boundary conditions
C     - useric : initial conditions
C     - uservp : variable properties
C     - userf  : local acceleration term for fluid
C     - userq  : local source term for scalars
C     - userchk: general purpose routine for checking errors etc.
C
C-----------------------------------------------------------------------
#define DELTA 0.2
#define XLEN 1.
#define YLEN 1.
#define ZLEN 1.
C-----------------------------------------------------------------------
      include 'wallShear.usr'
C-----------------------------------------------------------------------
      subroutine uservp(ix,iy,iz,eg) ! set variable properties
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'

      integer e,f,eg
c     e = gllel(eg)

      udiff  = 0.0
      utrans = 0.0

      return
      end
c-----------------------------------------------------------------------
      subroutine userf(ix,iy,iz,eg) ! set acceleration term
c
c     Note: this is an acceleration term, NOT a force!
c     Thus, ffx will subsequently be multiplied by rho(x,t).
c
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'

      integer e,f,eg
c     e = gllel(eg)

      ffx = 0.0
      ffy = 0.0
      ffz = 0.0

      return
      end
c-----------------------------------------------------------------------
      subroutine userq(ix,iy,iz,eg) ! set source term
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'

      integer e,f,eg
c     e = gllel(eg)

      qvol   = 0.0

      return
      end
c-----------------------------------------------------------------------
      subroutine userbc(ix,iy,iz,iside,ieg) ! set up boundary conditions
c     NOTE ::: This subroutine MAY NOT be called by every process
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'

c      if (cbc(iside,gllel(ieg),ifield).eq.'v01')

c	Empty/no call to with BCs P, W, SYM!

      ux   = 0.0
      uy   = 0.0
      uz   = 0.0
      temp = 0.0

      return
      end
c-----------------------------------------------------------------------
      subroutine useric(ix,iy,iz,ieg) ! set up initial conditions
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'

      integer idum
      save    idum 
      data    idum / 0 /

      integer ie

      ie = gllel(ieg)

      x = xm1(ix,iy,iz,ie)
      y = ym1(ix,iy,iz,ie)
      z = zm1(ix,iy,iz,ie)
 
      ux = y**2 + x**4 + z**7
      uy = 0.
      uz = 0.

      return
      end
c-----------------------------------------------------------------------
      subroutine userchk()
      include 'SIZE'
      include 'TOTAL'

      integer f,ifld,idir
      character*3 bctyp
  
      real Tx(lx1,ly1,lz1,lelv) ! shear stress X-comp
      real Ty(lx1,ly1,lz1,lelv) !              Y   
      real Tz(lx1,ly1,lz1,lelv) !              Z


ccccccccc     for verification
ccccccccc
      integer ntot,e,i,j
      real dsty,vsc
      real x  ,y  ,z  ,tmp
      real n1 ,n2 ,n3
      real t1 ,t2 ,t3
      real s11,s12,s13
      real s21,s22,s23
      real s31,s32,s33
      real udx,udy,udz
      real vdx,vdy,vdz
      real wdx,wdy,wdz
ccccccccc     
ccccccccc

      ifxyo = .true.
      ifto  = .true.

      f     = 1
      bctyp = 'W  '
      ifld  = 1
      call comp_wallShear(Tx,Ty,Tz,vx,vy,vz,f,bctyp,ifld)

ccccccccc     for verification
ccccccccc
      ntot = lx1*ly1*lz1*nelv
      dsty = param(1)
      vsc  = param(2)
 
      call dsset(nx1,ny1,nz1) ! initialize skpdat array

      do e=1,nelv
        if (cbc(f,e,ifld).eq.bctyp) then
          iface  = eface1(f)   ! surface to volume shifts
          js1    = skpdat(1,iface)
          jf1    = skpdat(2,iface)
          jskip1 = skpdat(3,iface)
          js2    = skpdat(4,iface)
          jf2    = skpdat(5,iface)
          jskip2 = skpdat(6,iface)

          k = 0
          do j2=js2,jf2,jskip2
          do j1=js1,jf1,jskip1
            k = k + 1
 
            x = xm1(j1,j2,1,e)
            y = ym1(j1,j2,1,e)
            z = zm1(j1,j2,1,e)
 
            ! normals of bottom surface
            tmp = 1 + ssx(x,DELTA)**2
            tmp = sqrt(tmp)
            n1 = ssx(x,DELTA)/tmp
            n2 = -1.0        /tmp
            n3 =  0.0

            ! gradients of velocity field for strain-rate tensor 
            udx = 4.*x**3
            udy = 2.*y**1
            udz = 7.*z**6
            vdx = 0.
            vdy = 0.
            vdz = 0.
            wdx = 0.
            wdy = 0.
            wdz = 0.

            s11 = udx + udx
            s21 = udy + vdx
            s31 = udz + wdx
 
            s12 = vdx + udy
            s22 = vdy + vdy 
            s32 = vdz + wdy 
 
            s13 = wdx + udz
            s23 = wdy + vdz
            s33 = wdz + wdz
 
            t1 = -(s11*n1 + s12*n2 + s13*n3)*vsc
            t2 = -(s21*n1 + s22*n2 + s23*n3)*vsc
            t3 = -(s31*n1 + s32*n2 + s33*n3)*vsc
 
            Tx(j1,j2,1,e) = abs(Tx(j1,j2,1,e) - t1)
            Ty(j1,j2,1,e) = abs(Ty(j1,j2,1,e) - t2)
            Tz(j1,j2,1,e) = abs(Tz(j1,j2,1,e) - t3)
 
          enddo
          enddo

        endif
      enddo

      tmp = glmax(Tx,ntot)
      if(nid.eq.0) write(6,*) "max error in x-shear is ", tmp
      tmp = glmax(Ty,ntot)
      if(nid.eq.0) write(6,*) "max error in y-shear is ", tmp
      tmp = glmax(Tz,ntot)
      if(nid.eq.0) write(6,*) "max error in z-shear is ", tmp
ccccccccc
ccccccccc

c     call exitt

      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat()   ! This routine to modify element vertices
      include 'SIZE'
      include 'TOTAL'

      common /cdsmag/ ediff(lx1,ly1,lz1,lelv)

      n=8*nelv
      xmin = glmin(xc,n)
      xmax = glmax(xc,n)
      ymin = glmin(yc,n)
      ymax = glmax(yc,n)
      zmin = glmin(zc,n)
      zmax = glmax(zc,n)

      xscale = XLEN/(xmax-xmin)
      yscale = YLEN/(ymax-ymin)
      zscale = ZLEN/(zmax-zmin)

      do i=1,n
         xc(i,1) = xscale*xc(i,1)
         yc(i,1) = yscale*yc(i,1)
         zc(i,1) = zscale*zc(i,1)
      enddo

      ! element vertices unchanged since XLEN = (xmax-xmin) = 1

      n = nx1*ny1*nz1*nelt 
      call cfill(ediff,param(2),n)  ! initialize viscosity

      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat2()  ! This routine to modify mesh coordinates
      include 'SIZE'
      include 'TOTAL'

       nt = nx1*ny1*nz1*nelt
 
       call rescale_x(xm1, 0.0, 1.0)
       call rescale_x(ym1, 0.0, 1.0)
       call rescale_x(zm1, 0.0, 1.0)
       ! box \vect{x} \in [0,1]^3

       del = 0.2
       do i=1,nt
         x  = xm1(i,1,1,1)
         y  = ym1(i,1,1,1)
         z  = zm1(i,1,1,1)
 
         yw = ss(x,DELTA)
 
         yy = (1. - yw/1.0)*y + yw
         ym1(i,1,1,1) = yy
       enddo

      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat3()
      include 'SIZE'
      include 'TOTAL'

      return
      end
c-----------------------------------------------------------------------
      function ss(x,d)          ! bottom surface y = ss(x,d)

      ss = 1.0 - (2.0*x-1.0)**2
      ss = ss*d

      return
      end
c-----------------------------------------------------------------------
      function ssx(x,d)          ! d(ss)/dx

      ssx = -4.0*(2.0*x-1)
      ssx = ssx*d

      return
      end
C=======================================================================

c automatically added by makenek
      subroutine usrsetvert(glo_num,nel,nx,ny,nz) ! to modify glo_num
      integer*8 glo_num(1)

      return
      end

c automatically added by makenek
      subroutine userqtl

      call userqtl_scig

      return
      end
