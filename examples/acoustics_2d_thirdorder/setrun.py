"""
Module to set up run time parameters for Clawpack.

The values set in the function setrun are then written out to data files
that will be read in by the Fortran code.

"""

import os
import numpy as np

#------------------------------
def setrun(claw_pkg='amrclaw'):
#------------------------------

    """
    Define the parameters used for running Clawpack.

    INPUT:
        claw_pkg expected to be "amrclaw" for this setrun.

    OUTPUT:
        rundata - object of class ClawRunData

    """

    from clawpack.clawutil import data


    assert claw_pkg.lower() == 'amrclaw',  "Expected claw_pkg = 'amrclaw'"

    num_dim = 2
    rundata = data.ClawRunData(claw_pkg, num_dim)

    #------------------------------------------------------------------
    # Problem-specific parameters to be written to setprob.data:
    #------------------------------------------------------------------

    # Physical parameters used at some point
    trans_halfwidth = 0.0125
    trans_halfdepth = 0.1162 #how far the transducer face is from the center of the pipe
    domain_inner_radius = 0.08
    domain_outer_radius = 0.23

    probdata = rundata.new_UserData(name='probdata',fname='setprob.data')
    probdata.add_param('rho',       1000.,  'density of medium')
    probdata.add_param('bulk',      2.202256e-3,  'bulk modulus')

    #------------------------------------------------------------------
    # Standard Clawpack parameters to be written to claw.data:
    #   (or to amrclaw.data for AMR)
    #------------------------------------------------------------------

    clawdata = rundata.clawdata  # initialized when rundata instantiated


    # Set single grid parameters first.
    # See below for AMR parameters.


    # ---------------
    # Spatial domain:
    # ---------------

    # Number of space dimensions:
    clawdata.num_dim = num_dim

    # Lower and upper edge of computational domain:
    clawdata.lower[0] = 0.08                      # xlower
    clawdata.upper[0] = 0.23                    # xupper
    clawdata.lower[1] = 0.0                                  # ylower
    clawdata.upper[1] = 0.25*(clawdata.upper[0]-clawdata.lower[0])  # yupper

    # Number of grid cells:

#    clawdata.num_cells[0] = 43   # 4265, 2875  14.7%
                                  # 4785, 3225
    clawdata.num_cells[0] = 86   # 4751, 3205  4.98%
#    clawdata.num_cells[0] = 172  # 4914, 3310  1.72%
#    clawdata.num_cells[0] = 344

    clawdata.num_cells[1] = int(np.floor(0.25*clawdata.num_cells[0]))


    # ---------------
    # Size of system:
    # ---------------

    # Number of equations in the system:
    clawdata.num_eqn = 3

    # Number of auxiliary variables in the aux array (initialized in setaux)
    clawdata.num_aux = 0

    # Index of aux array corresponding to capacity function, if there is one:
    clawdata.capa_index = 0


    # -------------
    # Initial time:
    # -------------

    clawdata.t0 = 0.000000


    # Restart from checkpoint file of a previous run?
    # Note: If restarting, you must also change the Makefile to set:
    #    RESTART = True
    # If restarting, t0 above should be from original run, and the
    # restart_file 'fort.chkNNNNN' specified below should be in
    # the OUTDIR indicated in Makefile.

    clawdata.restart = False               # True to restart from prior results
    clawdata.restart_file = 'fort.chk00006'  # File to use for restart data


    # -------------
    # Output times:
    #--------------

    # Specify at what times the results should be written to fort.q files.
    # Note that the time integration stops after the final output time.

    clawdata.output_style = 1

    if clawdata.output_style==1:
        # Output ntimes frames at equally spaced times up to tfinal:
        # Can specify num_output_times = 0 for no output
        clawdata.num_output_times = 10
        clawdata.tfinal = 50.0
        clawdata.output_t0 = True  # output at initial (or restart) time?

    elif clawdata.output_style == 2:
        # Specify a list or numpy array of output times:
        # Include t0 if you want output at the initial time.
        clawdata.output_times =  [0.0,47.0]

    elif clawdata.output_style == 3:
        # Output every step_interval timesteps over total_steps timesteps:
        clawdata.output_step_interval = 1
        clawdata.total_steps = 5
        clawdata.output_t0 = True  # output at initial (or restart) time?


    clawdata.output_format = 'ascii'       # 'ascii', 'binary', 'netcdf'

    clawdata.output_q_components = 'all'   # could be list such as [True,True]
    clawdata.output_aux_components = 'none'  # could be list
    clawdata.output_aux_onlyonce = True    # output aux arrays only at t0


    # ---------------------------------------------------
    # Verbosity of messages to screen during integration:
    # ---------------------------------------------------

    # The current t, dt, and cfl will be printed every time step
    # at AMR levels <= verbosity.  Set verbosity = 0 for no printing.
    #   (E.g. verbosity == 2 means print only on levels 1 and 2.)
    clawdata.verbosity = 1



    # --------------
    # Time stepping:
    # --------------

    # if dt_variable==True:  variable time steps used based on cfl_desired,
    # if dt_variable==False: fixed time steps dt = dt_initial always used.
    clawdata.dt_variable = True

    # Initial time step for variable dt.
    # (If dt_variable==0 then dt=dt_initial for all steps)
    clawdata.dt_initial = 1.500000e-08

    # Max time step to be allowed if variable dt used:
    clawdata.dt_max = 1.000000e+99

    # Desired Courant number if variable dt used
    clawdata.cfl_desired = 0.900000
    # max Courant number to allow without retaking step with a smaller dt:
    clawdata.cfl_max = 1.000000

    # Maximum number of time steps to allow between output times:
    clawdata.steps_max = 50000


    # ------------------
    # Method to be used:
    # ------------------

    # Order of accuracy:  1 => Godunov,  2 => Lax-Wendroff plus limiters
    clawdata.order = 3

    # Use dimensional splitting? (not yet available for AMR)
    clawdata.dimensional_split = 'unsplit'

    # For unsplit method, transverse_waves can be
    #  0 or 'none'      ==> donor cell (only normal solver used)
    #  1 or 'increment' ==> corner transport of waves
    #  2 or 'all'       ==> corner transport of 2nd order corrections too
    clawdata.transverse_waves = 2


    # Number of waves in the Riemann solution:
    clawdata.num_waves = 2

    # List of limiters to use for each wave family:
    # Required:  len(limiter) == num_waves
    # Some options:
    #   0 or 'none'     ==> no limiter (Lax-Wendroff)
    #   1 or 'minmod'   ==> minmod
    #   2 or 'superbee' ==> superbee
    #   3 or 'vanleer'  ==> van Leer
    #   4 or 'mc'       ==> MC limiter
    clawdata.limiter = ['none','none']

    clawdata.use_fwaves = False    # True ==> use f-wave version of algorithms

    # Source terms splitting:
    #   src_split == 0 or 'none'    ==> no source term (src routine never called)
    #   src_split == 1 or 'godunov' ==> Godunov (1st order) splitting used,
    #   src_split == 2 or 'strang'  ==> Strang (2nd order) splitting used,  not recommended.
    clawdata.source_split = 1


    # --------------------
    # Boundary conditions:
    # --------------------

    # Number of ghost cells (usually 2)
    clawdata.num_ghost = 2

    # Choice of BCs at xlower and xupper:
    #   0 or 'user'     => user specified (must modify bcNamr.f to use this option)
    #   1 or 'extrap'   => extrapolation (non-reflecting outflow)
    #   2 or 'periodic' => periodic (must specify this at both boundaries)
    #   3 or 'wall'     => solid wall for systems where q(2) is normal velocity

    clawdata.bc_lower[0] = 'extrap'   # at xlower
    clawdata.bc_upper[0] = 'extrap'   # at xupper

    clawdata.bc_lower[1] = 'wall'     # at ylower
    clawdata.bc_upper[1] = 'extrap'   # at yupper


    # ---------------
    # Gauges:
    # ---------------
    gauges = rundata.gaugedata.gauges
    for j,x in enumerate(np.linspace(0.12,0.18,7)):
        gauges.append([j, x, 0.0, 0.0, 1e9])
#    gauges.append([1, 0.15, 0.0, 0.0, 1e9])
#    gauges.append([2, 0.19, 0.0, 0.0, 1e9])
#    gauges.append([3, 0.15, 0.04, 0.0, 1e9])
#    gauges.append([4, 0.19, 0.02*np.sqrt(2.0), 0.0, 1e9])

    # for gauges append lines of the form  [gaugeno, x, y, t1, t2]

    # Add gauges at pipe wall
#    theta = [0.0, 0.5*np.arcsin((clawdata.upper[1]-clawdata.lower[1])/pipe_inner_radius), np.arcsin((clawdata.upper[1]-clawdata.lower[1])/pipe_inner_radius)]
#    for j in range(3):
#        rundata.gaugedata.gauges.append([j, -trans_halfdepth + pipe_inner_radius*np.cos(theta[j]), pipe_inner_radius*np.sin(theta[j]), 0.0, 1e9])
#    for j in range(3):
#        rundata.gaugedata.gauges.append([j+3, -trans_halfdepth + 0.8*pipe_inner_radius*np.cos(theta[j]), 0.8*pipe_inner_radius*np.sin(theta[j]), 0.0, 1e9])

    #for j,rj in enumerate(np.linspace(clawdata.lower[0],clawdata.upper[0],3)):
    #    rundata.gaugedata.gauges.append([j, rj, 0.001, 0., 1e9])
    #    rundata.gaugedata.gauges.append([j, rj/np.sqrt(2.), rj/np.sqrt(2.), 0., 1e9])
    #    rundata.gaugedata.gauges.append([20+j, 0.001, rj, 0., 1e9])

    # --------------
    # Checkpointing:
    # --------------

    # Specify when checkpoint files should be created that can be
    # used to restart a computation.

    clawdata.checkpt_style = 2

    if clawdata.checkpt_style == 0:
        # Do not checkpoint at all
        pass

    elif clawdata.checkpt_style == 1:
        # Checkpoint only at tfinal.
        pass

    elif clawdata.checkpt_style == 2:
        # Specify a list of checkpoint times.
        clawdata.checkpt_times = [20.0,47.0]

    elif clawdata.checkpt_style == 3:
        # Checkpoint every checkpt_interval timesteps (on Level 1)
        # and at the final time.
        clawdata.checkpt_interval = 5



    # ---------------
    # AMR parameters:
    # ---------------

    amrdata = rundata.amrdata

    # max number of refinement levels:
    amrdata.amr_levels_max = 3

    # List of refinement ratios at each level (length at least amr_level_max-1)
    amrdata.refinement_ratios_x = [8,8]
    amrdata.refinement_ratios_y = [8,8]
    amrdata.refinement_ratios_t = [8,8]


    # Specify type of each aux variable in clawdata.auxtype.
    # This must be a list of length num_aux, each element of which is one of:
    #   'center',  'capacity', 'xleft', or 'yleft'  (see documentation).
    amrdata.aux_type = []


    # Flag for refinement based on Richardson error estimater:
    amrdata.flag_richardson = False    # use Richardson?
    amrdata.flag_richardson_tol = 1.00000e+00  # Richardson tolerance

    # Flag for refinement using routine flag2refine:
    amrdata.flag2refine = True      # use this?
    amrdata.flag2refine_tol = 5e-9 # tolerance used in this routine
    # User can modify flag2refine to change the criterion for flagging.
    # Default: check maximum absolute difference of first component of q
    # between a cell and each of its neighbors.

    # steps to take on each level L between regriddings of level L+1:
    amrdata.regrid_interval = 2

    # width of buffer zone around flagged points:
    # (typically the same as regrid_interval so waves don't escape):
    amrdata.regrid_buffer_width  = 3

    # clustering alg. cutoff for (# flagged pts) / (total # of cells refined)
    # (closer to 1.0 => more small grids may be needed to cover flagged cells)
    amrdata.clustering_cutoff = 0.7

    # print info about each regridding up to this level:
    amrdata.verbosity_regrid = 0


    # ---------------
    # Regions:
    # ---------------
    rundata.regiondata.regions = []
    # to specify regions of refinement append lines of the form
    #  [minlevel,maxlevel,t1,t2,x1,x2,y1,y2]

    #  ----- For developers -----
    # Toggle debugging print statements:
    amrdata.dprint = False      # print domain flags
    amrdata.eprint = False      # print err est flags
    amrdata.edebug = False      # even more err est flags
    amrdata.gprint = False      # grid bisection/clustering
    amrdata.nprint = False      # proper nesting output
    amrdata.pprint = False      # proj. of tagged points
    amrdata.rprint = False      # print regridding summary
    amrdata.sprint = False      # space/memory output
    amrdata.tprint = False      # time step reporting each level
    amrdata.uprint = False      # update/upbnd reporting

    return rundata

    # end of function setrun
    # ----------------------


if __name__ == '__main__':
    # Set up run-time parameters and write all data files.
    import sys
    rundata = setrun(*sys.argv[1:])
    rundata.write()
