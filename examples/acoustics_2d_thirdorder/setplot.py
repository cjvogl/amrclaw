
"""
Set up the plot figures, axes, and items to be done for each frame.

This module is imported by the plotting routines and then the
function setplot is called to set the plot parameters.

"""

import numpy as np


#--------------------------
def setplot(plotdata):
#--------------------------

    """
    Specify what is to be plotted at each frame.
    Input:  plotdata, an instance of clawpack.visclaw.data.ClawPlotData.
    Output: a modified version of plotdata.

    """


    from clawpack.visclaw import colormaps

    plotdata.clearfigures()  # clear any old figures,axes,items data


    # Figure for pressure
    # -------------------

    plotfigure = plotdata.new_plotfigure(name='Pressure', figno=0)

    # Set up for axes in this figure:
    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = 'auto'
    plotaxes.ylimits = 'auto'
    plotaxes.title = 'Pressure'
    plotaxes.scaled = True      # so aspect ratio is 1
    plotaxes.afteraxes = gauges

    # Set up for item on these axes:
    plotitem = plotaxes.new_plotitem(plot_type='2d_pcolor')
    plotitem.plot_var = 0
    plotitem.pcolor_cmap = colormaps.blue_white_red
    plotitem.add_colorbar = True
    plotitem.show = True       # show on plot?
    plotitem.pcolor_cmin = -1.0e-6
    plotitem.pcolor_cmax = 6.0e-6
    plotitem.amr_patchedges_show = [0]
    plotitem.amr_celledges_show = [0]
    plotitem.amr_data_show = [1,1,0]

    plotfigure = plotdata.new_plotfigure(name='Horizontal Velocity', figno=2)

    # Set up for axes in this figure:
    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = 'auto'
    plotaxes.ylimits = 'auto'
    plotaxes.title = 'Horizontal Velocity'
    plotaxes.scaled = True      # so aspect ratio is 1
    plotaxes.afteraxes = gauges

    # Set up for item on these axes:
    plotitem = plotaxes.new_plotitem(plot_type='2d_pcolor')
    plotitem.plot_var = 1
    plotitem.pcolor_cmap = colormaps.blue_white_red
    plotitem.add_colorbar = True
    plotitem.show = True       # show on plot?
    plotitem.pcolor_cmin = -3e-6
    plotitem.pcolor_cmax = 4e-6
    plotitem.amr_patchedges_show = [0]
    plotitem.amr_celledges_show = [0]
    plotitem.amr_data_show = [1,1,0]

    plotaxes.afteraxes = gauges

    # Figure for scatter plot
    # -----------------------

    plotfigure = plotdata.new_plotfigure(name='scatter', figno=4)
    plotfigure.show = False

    # Set up for axes in this figure:
    plotaxes = plotfigure.new_plotaxes()
    plotaxes.xlimits = [0,1.5]
    plotaxes.ylimits = [-2.,4.]
    plotaxes.title = 'Scatter plot'

    # Set up for item on these axes: scatter of 2d data
    plotitem = plotaxes.new_plotitem(plot_type='1d_from_2d_data')

    def p_vs_r(current_data):
        # Return radius of each grid cell and p value in the cell
        from pylab import sqrt
        x = current_data.x
        y = current_data.y
        r = sqrt(x**2 + y**2)
        q = current_data.q
        p = q[0,:,:]
        return r,p

    plotitem.map_2d_to_1d = p_vs_r
    plotitem.plot_var = 0
    plotitem.plotstyle = 'o'
    plotitem.color = 'b'
    plotitem.show = True       # show on plot?

    if 0:
        # Set up for item on these axes: 1d reference solution
        plotitem = plotaxes.new_plotitem(plot_type='1d_plot')
        plotitem.outdir = qref_dir
        plotitem.plot_var = 0
        plotitem.plotstyle = '-'
        plotitem.color = 'r'
        plotitem.kwargs = {'linewidth': 2}
        plotitem.show = True       # show on plot?
        plotaxes.afteraxes = "pylab.legend(('2d data', '1d reference solution'))"


    # Parameters used only when creating html and/or latex hardcopy
    # e.g., via clawpack.visclaw.frametools.printframes:

    plotdata.printfigs = True                # print figures
    plotdata.print_format = 'png'            # file format
    plotdata.print_framenos = 'all'          # list of frames to print
    plotdata.print_fignos = 'all'            # list of figures to print
    plotdata.html = True                     # create html files of plots?
    plotdata.html_homelink = '../README.html'   # pointer for top of index
    plotdata.html_movie = 'JSAnimation'      # new style, or "4.x" for old style
    plotdata.latex = True                    # create latex file of plots?
    plotdata.latex_figsperline = 2           # layout of plots
    plotdata.latex_framesperline = 1         # layout of plots
    plotdata.latex_makepdf = False           # also run pdflatex?

    return plotdata



# Plots position of pipe wall and gauges
def gauges(current_data):
      from clawpack.visclaw import gaugetools
      gaugetools.plot_gauge_locations(current_data.plotdata, \
         gaugenos='all', format_string='ko', add_labels=True)
