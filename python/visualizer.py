#!/usr/bin/env python
import sys,os
import reader

# boilerplate
from enthought.traits.api import HasTraits, Instance
from enthought.traits.ui.api import View, Item
from enthought.chaco.api import Plot, ArrayPlotData
from enthought.enable.component_editor import ComponentEditor

from numpy import linspace, sin, array, append

class LinePlot(HasTraits):
    plot = Instance(Plot)
    traits_view = View(
        Item('plot',editor=ComponentEditor(), show_label=False),
        width=500, height=500, resizable=True, title="Chaco Plot")

    def __init__(self, dataiterator):
        super(LinePlot, self).__init__()
        xarr = None
        yarr = None
        for x,y in dataiterator:
            if xarr == None:
                xarr = array(x)
            else:
                xarr = append(xarr, x)
            if yarr == None:
                yarr = array(y)
            else:
                yarr = append(yarr, y)
        print xarr
        print yarr
        
        # mangle the X for now, chaco seeminly can't handle datetimes
        xarr = array(xrange(len(yarr)))
        plotdata = ArrayPlotData(x=xarr,y=yarr)

        plot = Plot(plotdata)
        plot.plot(("x", "y"), type="line", color="blue")
        plot.title = "EEG plot"
        self.plot = plot

if __name__ == "__main__":
    if (len(sys.argv) < 1):
        exit(1)
    fp = open(sys.argv[1], 'rb')
    reader = reader.rawiterator(fp)
    myplot = LinePlot(reader)
    myplot.configure_traits()


