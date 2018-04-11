import argparse
import codecs
import collections
import csv
import errno
import gzip
import os
#import xml.etree.ElementTree as etree
import lxml.etree as etree

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(path):
          pass
        else: raise

# {http://www.mediawiki.org/xml/export-0.10/}page -> page
def strip_tag_name(t):
    t = elem.tag
    idx = k = t.rfind("}")
    if idx != -1:
        t = t[idx + 1:]
    return t

if __name__ == "__main__":

    parser = argparse.ArgumentParser(
    description='Parses Wikipedia history files and computes a controversy score for every page.')
    parser.add_argument('infile', help='Input .xml file.')
    parser.add_argument('outfile', help='Page controversy scores .csv.gz file.')
    parser.add_argument('--errors', dest='errors', action='store_true', default=False, help='Show lxml error messages. This may get very verbose!')
  
    args = parser.parse_args()
    outfile = os.path.abspath(args.outfile)
    mkdir_p(os.path.dirname(outfile))

    with gzip.open(outfile, 'wb') as o:
        writer = csv.writer(o, delimiter=',', quoting=csv.QUOTE_NONNUMERIC)
        writer.writerow(['ns', 'pageid', 'controversy'])
        idx = 0
        inrevision = False
        user_edits = collections.Counter() # user -> edit count
        original_author = dict() # sha1 -> user
        user_reverts = collections.Counter() # (user1, user2) -> revert count
        context = etree.iterparse(gzip.open(args.infile, 'r'), events=('start', 'end'))
        event, root = context.next()
        for event, elem in context:
            tag = strip_tag_name(elem.tag)
            if event == 'start':
                if tag == 'page': 
                    inrevision = False
                    incontributor = False
                    pageid = None
                    ns = None
                    user_edits.clear()
                    original_author.clear()
                    user_reverts.clear()
                elif tag == 'revision':
                    inrevision = True
                    incontributor = False
                    userid = None # ID or IP string
                    sha1 = None
                elif tag == 'contributor':
                    incontributor = True
            elif event == 'end':
                if inrevision:
                    if tag == 'contributor':
                        incontributor = False
                    elif tag == 'id':
                        if incontributor:
                            userid = elem.text
                    elif tag == 'ip':
                        userid = elem.text
                    elif tag == 'sha1':
                        sha1 = elem.text
                    elif tag == 'revision':
                        inrevision = False
                        user_edits.update(userid)
                        if sha1 not in original_author:
                            # this is a new contribution
                            original_author[sha1] = userid
                        else:
                            # this is a revert
                            user_reverts.update([(userid, original_author[sha1])])
                        # progress
                        idx += 1
                        if (idx % 100000)==0:
                            print "Record #{:,} with page id {}...".format(idx, pageid)
                            if args.errors and (len(context.error_log)>0):
                                if len(context.error_log)>10:
                                    print "(Skipping {:,} errors)".format(len(context.error_log))
                                print context.error_log[:-10]
                elif tag == 'id':
                    pageid = int(elem.text)
                elif tag == 'ns':
                    ns = int(elem.text)
                elif tag == 'page':
                    # identify mutual reverts between all u1, u2
                    mutual_reverts = collections.Counter() # (u1, u2)
                    for (u1, u2) in user_reverts.keys():
                        if user_reverts[(u2, u1)] > 0:
                            pair = tuple(sorted((u1, u2))) # consistent order
                            mutual_reverts[pair] = user_reverts[(u1, u2)] + user_reverts[(u2, u1)]
                    num_mr_users = len(set([v for pair in mutual_reverts.keys() for v in pair]))
                    # drop the most active pair
                    top_mr_pair = mutual_reverts.most_common(1)
                    if len(top_mr_pair)>0:
                        mutual_reverts[top_mr_pair[0][0]] = 0
                    # weight the remainder by min(experience)
                    score = sum([mutual_reverts[(u1, u2)] * min(user_edits[u1], user_edits[u2]) for u1, u2 in mutual_reverts.keys()])
                    # and adjust by participant count
                    score *= num_mr_users
                    writer.writerow([ns, pageid, score])
                #root.clear()
                elem.clear()
