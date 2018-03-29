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
        writer = csv.writer(o, delimiter=',', quoting=csv.QUOTE_NONNUMERIC)
        writer.writerow(['ns', 'pageid', 'revisionid', 'contributorid', 'iso2', 'timestamp', 'sha1_is_known'])
        idx = 0
        inrevision = False
        known_sha1s = set()
        context = etree.iterparse(gzip.open(args.infile, 'r'), events=('start', 'end'))
        event, root = context.next()
        for event, elem in context:
            tag = strip_tag_name(elem.tag)
            if event == 'start':
                if tag == 'page': 
                    inrevision = False
                    incontributor = False
                    pageid  = None
                    ns = None
                    known_sha1s.clear()
                elif tag == 'revision':
                    inrevision = True
                    incontributor = False
                    revisionid = None
                    contributorid = None
                    ip = None
                    iso2 = None
                    timestamp = None
                    sha1 = None
                    sha1_is_known = False
                    comment = None
                elif tag == 'contributor':
                    incontributor = True
            elif event == 'end':
                if inrevision:
                    if tag == 'contributor':
                        incontributor = False
                    elif tag == 'id':
                        if incontributor:
                            contributorid = int(elem.text)
                        else:
                            revisionid = int(elem.text)
                    elif tag == 'ip':
                        ip = elem.text
                        iso2 = geoip_iso2(geoip, geoip_iso2_cache, ip)
                    elif tag == 'timestamp':
                        timestamp = elem.text
                    elif tag == 'sha1':
                        sha1 = elem.text
                        if sha1 in known_sha1s:
                            sha1_is_known = True
                        known_sha1s.add(sha1)
                    elif tag == 'revision':
                        # if ip != None: # only record anon contributions
                        writer.writerow([ns, pageid, revisionid, contributorid, iso2, timestamp, sha1_is_known])
                        # progress
                        idx += 1
                        if (idx % 100000)==0:
                            print "Record #{:,} with page id {}... (GeoIP cache size: {:,}, {:,} cache evictions)".format(idx, pageid, len(geoip_iso2_cache), geoip_iso2_cache.num_evictions-prev_cache_evictions)
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
