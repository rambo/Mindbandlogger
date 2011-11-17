#!/usr/bin/env python
import sys,os,time
import csv
from datetime import datetime,timedelta


class eeg_data(object):
    timestamp  = None
    raw        = None

class eeg_data_extended(eeg_data):
    quality    = None
    meditation = None
    attention  = None
    delta      = None
    theta      = None
    lowalpha   = None
    highalpha  = None
    lowbeta    = None
    highbeta   = None
    lowgamma   = None
    midgamma   = None
    

class read_normalizer:
    def __init__(self, fp):
        self.csvreader = csv.reader(fp, delimiter=',')
        self.csvbuffer = []
        self.retbuffer = []
        self.last_timestamp = None

    def read_until_next_full(self):
        try:
            while (True):
                self.csvbuffer.append(self.csvreader.next())
                if (    len(self.csvbuffer) > 1
                    and self.csvbuffer[-1][0] != ""):
                    # Full data row received
                    if not self.last_timestamp:
                        # We don't have previous timestamp, do a funky slice and recurse
                        self.last_timestamp = self.parse_iso_ts(self.csvbuffer[-1][0])
                        self.csvbuffer = [ self.csvbuffer[-1] ]
                        return self.read_until_next_full()
                    else:
                        self.last_timestamp = self.parse_iso_ts(self.csvbuffer[-1][0])
                    return True
        except StopIteration:
            # No more data
            return False

    def parse_iso_ts(self, ts_string):
        return datetime.strptime(ts_string, "%Y-%m-%d %H:%M:%S")

    def parse_csvbuffer(self):
        set_start = self.parse_iso_ts(self.csvbuffer[0][0])
        set_end = self.parse_iso_ts(self.csvbuffer[-1][0])
        set_delta = (set_end - set_start) / (len(self.csvbuffer)-1)
        set_cursor = set_start
        
        # The first row
        self.retbuffer.append(self.parse_csvrow(self.csvbuffer.pop(0), set_start))
        # In-between rows
        while (len(self.csvbuffer) > 1):
            set_cursor = set_cursor + set_delta
            self.retbuffer.append(self.parse_csvrow(self.csvbuffer.pop(0), set_cursor))
        # Last row we need for future reference

    def parse_csvrow(self, row, timestamp):
        if len(row) > 2:
            ret = eeg_data_extended()
        else:
            ret = eeg_data()
        ret.timestamp = timestamp
        ret.raw = int(row[1])
        if len(row) > 2:
            ret.quality    = int(row[2])
            ret.meditation = int(row[3])
            ret.attention  = int(row[4])
            ret.delta      = int(row[5])
            ret.theta      = int(row[6])
            ret.lowalpha   = int(row[7])
            ret.highalpha  = int(row[8])
            ret.lowbeta    = int(row[9])
            ret.highbeta   = int(row[10])
            ret.lowgamma   = int(row[11])
            ret.midgamma   = int(row[12])
        return ret

    def next(self):
        if (len(self.retbuffer) == 0):
            if (not self.read_until_next_full()):
                raise StopIteration
            self.parse_csvbuffer()
        return self.retbuffer.pop(0)

    def __iter__(self):
        return self



if __name__ == '__main__':
    print sys.argv
    if (len(sys.argv) > 1):
        fp = open(sys.argv[1], 'rb')
    reader = read_normalizer(fp)
    
    i = 0
    for row in reader:
        i = i+1
        print "#%d: %s" % (i, row)

