#!/usr/bin/env python
import sys,os
import reader

import matplotlib.pyplot as plt
import numpy


class plotter:
    def __init__(self, dataiterator):
        # TODO: How to use the iterator directly ?
        xarr = None
        yarr = None
        for x,y in dataiterator:
            if xarr == None:
                xarr = numpy.array(x)
            else:
                xarr = numpy.append(xarr, x)
            if yarr == None:
                yarr = numpy.array(y)
            else:
                yarr = numpy.append(yarr, y)


        plt.plot(xarr, yarr)
        plt.show()


if __name__ == "__main__":
    if (len(sys.argv) < 1):
        exit(1)
    fp = open(sys.argv[1], 'rb')
    reader = reader.rawiterator(fp)
    myplotter = plotter(reader)
