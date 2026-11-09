#!/usr/bin/env python3
import os
import sys, re, subprocess
ALBUM = sys.argv[1] if len(sys.argv) > 1 else sys.exit("usage: gen_slideshow.py <google-photos-share-url> [out.html] [tpl]")
OUT   = sys.argv[2] if len(sys.argv) > 2 else "slideshow.html"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
html = subprocess.check_output(["curl","-sL","-A",UA,ALBUM]).decode("utf-8","ignore")
urls = sorted(set(re.findall(r'https://lh3\.googleusercontent\.com/pw/[A-Za-z0-9_\-]+', html)))
if not urls:
    sys.exit("No photos found - album private or format changed")
arr = ",\n".join('"'+u+'"' for u in urls)
tpl = open(sys.argv[3] if len(sys.argv)>3 else os.path.join(os.path.dirname(os.path.abspath(__file__)),"www","slideshow.tpl")).read()
open(OUT,"w").write(tpl.replace("__URLS__", arr))
print("wrote %s with %d photos" % (OUT, len(urls)))
