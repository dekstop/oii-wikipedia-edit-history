import argparse
import codecs
import csv
import errno
import gzip
import os
import xml.etree.ElementTree as etree
#import lxml.etree as etree

import geoip2.database, geoip2.errors

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
  
    args = parser.parse_args()
    outfile = os.path.abspath(args.outfile)
    mkdir_p(os.path.dirname(outfile))

    geoip = geoip2.database.Reader(args.geoipfile)
    geoip_iso2_cache = dict()
 
    with gzip.open(outfile, 'wb') as o:
        writer = csv.writer(o, delimiter=',')
        writer.writerow(['ns', 'pageid', 'revisionid', 'ip', 'iso2', 'timestamp'])
        idx = 0
        inrevision = False
        for event, elem in etree.iterparse(gzip.open(args.infile, 'r'), events=('start', 'end')):
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
                            print "%d... (cache size: %d)" % (idx, len(geoip_iso2_cache))
    #                         break
                else:
                    if tag == 'id':
                        pageid = int(elem.text)
                    elif tag == 'ns':
                        ns = int(elem.text)
                elem.clear()
