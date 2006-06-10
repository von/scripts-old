#!/usr/bin/env python

import os
import sys
import mimetools
import multifile
import StringIO
import time

try:
    # If this fails then we're running with an old version of python
    # such as the one installed on lorien.mallorn.com
    sys.version_info()
except:
    False = 0
    True = 1
    file = open

# CD to our publishing directory
os.chdir(os.path.expanduser("~/www/photos/now/"))

# Make any files we create world-readable so httpd can read them
os.umask(022)

# Read message into a StringIO object
msgStr = ""
while True:
    line = sys.stdin.readline()
    if len(line) == 0:
	break
    # Cannot use += on old python
    msgStr = msgStr + line

msgBuf = StringIO.StringIO(msgStr)
    
msg = mimetools.Message(msgBuf)

if msg.getmaintype() != "multipart":
    # No image
    sys.exit(0)

foundJPEG = False

mfile = multifile.MultiFile(msgBuf)
mfile.push(msg.getparam("boundary"))
while mfile.next():
    submsg = mimetools.Message(mfile)
    if submsg.gettype() != "image/jpeg":
	continue
    now = time.localtime(time.time())
    fileNum = 1
    while True:
	format = "%%Y-%%m-%%d-%%H:%%M-%d.jpg" % fileNum
	jpegFileName = time.strftime(format,
				     # Backward compatible
				     now)
	if os.path.exists(jpegFileName) == False:
	    break
	fileNum = fileNum + 1
    jpegFile = file(jpegFileName, "w")
    mimetools.decode(mfile, jpegFile, submsg.getencoding())
    jpegFile.close()
mfile.pop()

# We have now created the file jpegFileName, time to add it to the
# index.html file
html = file("index.html", "r")
newhtml = file("index-new.html", "w")
asctime = time.asctime(now)
while True:
    line = html.readline()
    if len(line) == 0:
	break
    if line[0:13] == "<!-- MARK -->":
	newhtml.write("<!-- MARK --><img src=\"%s\"><br>\n" % jpegFileName)
	newhtml.write("<a href=\"%s\">%s</a><br>\n" % (jpegFileName, asctime))
    else:
	newhtml.write(line)
html.close()
newhtml.close()
os.rename("index-new.html", "index.html")

