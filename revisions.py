import argparse
import codecs
import collections
import csv
import errno
import gzip
import os
#import xml.etree.ElementTree as etree
import lxml.etree as etree

import geoip2.database, geoip2.errors

# Based on:
# https://www.kunxi.org/blog/2014/05/lru-cache-in-python/
class LRUCache:
    def __init__(self, capacity):
        self.capacity = capacity
        self.cache = collections.OrderedDict()
        self.num_evictions = 0

    def get(self, key):
        try:
            value = self.cache.pop(key)
            self.cache[key] = value
            return value
        except KeyError:
            return -1

    def set(self, key, value):
        try:
            self.cache.pop(key)
        except KeyError:
            if len(self.cache) >= self.capacity:
                self.cache.popitem(last=False)
                self.num_evictions += 1
        self.cache[key] = value

    def __getitem__(self, key):
        return self.get(key)

    def __setitem__(self, key, value):
        self.set(key, value)

    def __len__(self):
        return len(self.cache)

    def __contains__(self, key):
        return key in self.cache

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(path):
          pass
        else: raise


def geoip_iso2(geoip, cache, ip):
    if ip not in cache:
        try:
            response = geoip.country(ip)
            cache[ip] = response.country.iso_code
        except geoip2.errors.AddressNotFoundError, e:
            return None
    return cache[ip]

# {http://www.mediawiki.org/xml/export-0.10/}page -> page
def strip_tag_name(t):
    t = elem.tag
    idx = k = t.rfind("}")
    if idx != -1:
        t = t[idx + 1:]
    return t

if __name__ == "__main__":

    parser = argparse.ArgumentParser(
    description='Parses Wikipedia history files and extracts certain metadata fields for revisions (edits).')
    parser.add_argument('infile', help='Input .xml file.')
    parser.add_argument('geoipfile', help='Maxmind GeoIP-Country database file.')
    parser.add_argument('outfile', help='Output .csv.gz file.')
    parser.add_argument('--cachesize', dest='cachesize', default=1*1024*1024, help='Max entries in GeoIP lookup cache.')
    parser.add_argument('--errors', dest='errors', action='store_true', default=False, help='Show lxml error messages. This may get very verbose!')
    parser.add_argument('--heapdump', dest='heapdump', action='store_true', default=False, help='Show a breakdown of the heap during processing. This is very slow!')
  
    args = parser.parse_args()
    outfile = os.path.abspath(args.outfile)
    mkdir_p(os.path.dirname(outfile))

    geoip = geoip2.database.Reader(args.geoipfile)
    geoip_iso2_cache = LRUCache(args.cachesize)
    prev_cache_evictions = 0
 
    with gzip.open(outfile, 'wb') as o:
        writer = csv.writer(o, delimiter=',')
        writer.writerow(['ns', 'pageid', 'revisionid', 'ip', 'iso2', 'timestamp'])
        idx = 0
        inrevision = False
        context = etree.iterparse(gzip.open(args.infile, 'r'), events=('start', 'end'))
        event, root = context.next()
        for event, elem in context:
            tag = strip_tag_name(elem.tag)
            if event == 'start':
                if tag == 'page': 
                    inrevision = False
                    pageid = None
                    ns = None
                elif tag == 'revision':
                    inrevision = True
                    revisionid = None
                    ip = None
                    iso2 = None
                    timestamp = None
            elif event == 'end':
                if inrevision:
                    if tag == 'id':
                        revisionid = int(elem.text)
                    elif tag == 'ip':
                        ip = elem.text
                        iso2 = geoip_iso2(geoip, geoip_iso2_cache, ip)
                    elif tag == 'timestamp':
                        timestamp = elem.text
                    elif tag == 'revision':
                        if ip != None: # only record anon contributions
                            writer.writerow([ns, pageid, revisionid, ip, iso2, timestamp])
                        # progress
                        idx += 1
                        if (idx % 100000)==0:
                            print "Record #{:,} with revision id {}... (GeoIP cache size: {:,}, {:,} cache evictions)".format(idx, revisionid, len(geoip_iso2_cache), geoip_iso2_cache.num_evictions-prev_cache_evictions)
                            prev_cache_evictions = geoip_iso2_cache.num_evictions
                            if args.heapdump:
                                from guppy import hpy
                                h = hpy()
                                print h.heap()
                            if args.errors and (len(context.error_log)>0):
                                if len(context.error_log)>10:
                                    print "(Skipping {:,} errors)".format(len(context.error_log))
                                print context.error_log[:-10]
                else:
                    if tag == 'id':
                        pageid = int(elem.text)
                    elif tag == 'ns':
                        ns = int(elem.text)
                #root.clear()
                elem.clear()
