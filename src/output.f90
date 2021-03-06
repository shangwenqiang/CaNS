module mod_output
  use mpi
  use decomp_2d_io
  use mod_param     , only: dims
  use mod_common_mpi, only:ierr,myid,coord
  implicit none
  private
  public out0d,out1d,out1d_2,out2d,out3d
  contains
  subroutine out0d(fname,n,var)
    implicit none
    character(len=*), intent(in) :: fname
    integer, intent(in) :: n
    real(8), intent(in), dimension(:) :: var
    integer :: iunit
    character(len=30) :: cfmt
    integer :: i
    !
    write(cfmt,'(A,I3,A)') '(',n,'E15.7)' 
    iunit = 10
    if (myid .eq. 0) then
      open(iunit,file=fname,position='append')
      write(iunit,trim(cfmt)) (var(i),i=1,n) 
      close(iunit)
    endif
    return
  end subroutine out0d
  !
  subroutine out1d(fname,n,idir,z,dzlzi,p)
    implicit none
    character(len=*), intent(in) :: fname
    integer, intent(in), dimension(3) :: n
    integer, intent(in) :: idir
    real(8), intent(in), dimension(0:) :: z,dzlzi
    real(8), intent(in), dimension(0:,0:,0:) :: p
    real(8), allocatable, dimension(:) :: p1d
    integer :: i,j,k,ii,jj
    integer :: iunit
    integer, dimension(3) :: ng
    !
    ng(:) = n(:)
    ng(1:2) = n(1:2)*dims(1:2)
    iunit = 10
    select case(idir)
    case(3)
      allocate(p1d(n(3)))
      do k=1,ng(3)
        p1d(k) = 0.
        do j=1,n(2)
          do i=1,n(1)
            p1d(k) = p1d(k) + p(i,j,k)
          enddo
        enddo
      enddo
      call mpi_allreduce(MPI_IN_PLACE,p1d(1),ng(3),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      p1d(:) = p1d(:)/(1.*ng(1)*ng(2))
      if(myid.eq.0) then
        open(unit=iunit,file=fname)
        do k=1,n(3)
          write(iunit,'(2E15.7)') z(k),p1d(k)
        enddo
        close(iunit)
      endif
    case(2)
      allocate(p1d(ng(2)))
      p1d(:) = 0.
      do j=1,n(2)
        jj = coord(2)*n(2)+j
        p1d(jj) = 0.
        do k=1,n(3)
          do i=1,n(1)
            p1d(jj) = p1d(jj) + p(i,j,k)*dzlzi(k)
          enddo
        enddo
      enddo
      call mpi_allreduce(MPI_IN_PLACE,p1d(1),ng(2),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      p1d(:) = p1d(:)/(1.*ng(1))
      if(myid.eq.0) then
        open(unit=iunit,file=fname)
        do j=1,ng(2)
          write(iunit,'(2E15.7)') (1.d0*j-.5d0)/(1.d0*ng(2)),p1d(j)
        enddo
        close(iunit)
      endif
    case(1)
      allocate(p1d(ng(1)))
      p1d(:) = 0.
      do i=1,n(1)
        ii = coord(1)*n(1)+i
        p1d(i) = 0.
        do k=1,n(3)
          do j=1,n(2)
            p1d(ii) = p1d(ii) + p(i,j,k)*dzlzi(k)
          enddo
        enddo
      enddo
      call mpi_allreduce(MPI_IN_PLACE,p1d(1),ng(1),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      p1d(:) = p1d(:)/(1.*ng(2))
      if(myid.eq.0) then
        open(unit=iunit,file=fname)
        do i=1,ng(1)
          write(iunit,'(2E15.7)') (1.d0*i-.5d0)/(1.d0*n(1)),p1d(j)
        enddo
        close(iunit)
      endif
    end select
    deallocate(p1d)
  end subroutine out1d
  !
  subroutine out1d_2(fname,n,idir,z,u,v,w)
    implicit none
    character(len=*), intent(in) :: fname
    integer, intent(in), dimension(3) :: n
    integer, intent(in) :: idir
    real(8), intent(in), dimension(0:) :: z
    real(8), intent(in), dimension(0:,0:,0:) :: u,v,w
    real(8), allocatable, dimension(:) :: um,vm,wm,u2,v2,w2,uw
    integer :: i,j,k
    integer :: iunit
    integer, dimension(3) :: ng
    integer :: q
    !
    ng(:) = n(:)
    ng(1:2) = n(1:2)*dims(1:2)
    iunit = 10
    select case(idir)
    case(3)
      q = n(3)
      allocate(um(q),vm(q),wm(q),u2(q),v2(q),w2(q),uw(q))
      do k=1,n(3)
        um(k) = 0.
        vm(k) = 0.
        wm(k) = 0.
        u2(k) = 0.
        v2(k) = 0.
        w2(k) = 0.
        uw(k) = 0.
        do j=1,n(2)
          do i=1,n(1)
            um(k) = um(k) + u(i,j,k)
            vm(k) = vm(k) + v(i,j,k)
            wm(k) = wm(k) + w(i,j,k)
            u2(k) = u2(k) + u(i,j,k)**2
            v2(k) = v2(k) + v(i,j,k)**2
            w2(k) = w2(k) + w(i,j,k)**2
            uw(k) = uw(k) + 0.25*(u(i,j,k+1) + u(i,j,k))* & ! varying z grids should be taken into account
                                 (w(i+1,j,k) + w(i,j,k))    ! varying z grids should be taken into account
          enddo
        enddo
      enddo
      call mpi_allreduce(MPI_IN_PLACE,um(1),n(3),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      call mpi_allreduce(MPI_IN_PLACE,vm(1),n(3),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      call mpi_allreduce(MPI_IN_PLACE,wm(1),n(3),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      call mpi_allreduce(MPI_IN_PLACE,u2(1),n(3),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      call mpi_allreduce(MPI_IN_PLACE,v2(1),n(3),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      call mpi_allreduce(MPI_IN_PLACE,w2(1),n(3),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      call mpi_allreduce(MPI_IN_PLACE,uw(1),n(3),MPI_REAL8,MPI_SUM,MPI_COMM_WORLD,ierr)
      um(:) = um(:)/(1.*ng(1)*ng(2))
      vm(:) = vm(:)/(1.*ng(1)*ng(2))
      wm(:) = wm(:)/(1.*ng(1)*ng(2))
      u2(:) = sqrt(u2(:)/(1.*ng(1)*ng(2)) - um(:)**2)
      v2(:) = sqrt(v2(:)/(1.*ng(1)*ng(2)) - vm(:)**2)
      w2(:) = sqrt(w2(:)/(1.*ng(1)*ng(2)) - wm(:)**2)
      uw(:) = uw(:)/(1.*ng(1)*ng(2)) - um(:)*wm(:)
      if(myid.eq.0) then
        open(unit=iunit,file=fname)
        do k=1,n(3)
          write(iunit,'(8E15.7)') z(k),um(k),vm(k),wm(k), &
                                       u2(k),v2(k),w2(k), &
                                       uw(k)
        enddo
        close(iunit)
      endif
      deallocate(um,vm,wm,u2,v2,w2,uw)
    case(2)
    case(1)
    end select
  end subroutine out1d_2
  !
  subroutine out2d(fname,inorm,islice,p)
    implicit none
    character(len=*), intent(in) :: fname
    integer, intent(in) :: inorm,islice
    real(8),intent(in), dimension(:,:,:) :: p
    !
    select case(inorm)
    case(1) !normal to x --> yz plane
       call decomp_2d_write_plane(3,p,inorm,islice,fname)
    case(2) !normal to y --> zx plane
       call decomp_2d_write_plane(3,p,inorm,islice,fname)
    case(3) !normal to z --> xy plane
       call decomp_2d_write_plane(3,p,inorm,islice,fname)
    end select
    return
  end subroutine out2d
  subroutine out3d(fname,nskip,p)
    implicit none
    character(len=*), intent(in) :: fname
    integer, intent(in), dimension(3) :: nskip
    real(8),intent(in), dimension(:,:,:) :: p
    integer :: fh
    integer(kind=MPI_OFFSET_KIND) :: filesize,disp
    !
    call MPI_FILE_OPEN(MPI_COMM_WORLD, fname, &
         MPI_MODE_CREATE+MPI_MODE_WRONLY, MPI_INFO_NULL,fh, ierr)
    filesize = 0_MPI_OFFSET_KIND
    call MPI_FILE_SET_SIZE(fh,filesize,ierr)
    disp = 0_MPI_OFFSET_KIND
    call decomp_2d_write_every(3,p,nskip(1),nskip(2),nskip(3),fname,.true.)
    call MPI_FILE_CLOSE(fh,ierr)
    return
  end subroutine out3d
end module mod_output
