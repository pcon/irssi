#!/usr/bin/env python

"""beanstalk-notify.py: A beanstalk consumer for system notifications"""

import beanstalkc
import json
import sys
import signal
from gi.repository import Notify

__author__ = "Patrick Connelly"
__copyright__ = "Copyright 2013, Patrick Connelly"
__credits__ = ["Patrick Connelly"]
__license__ = "GPL"
__version__ = "1.0.0"
__maintainer__ = "Patrick Connelly"
__email__ = "patrick@deadlypenguin.com"
__status__ = "Production"

#######################
#### CONFIGURATION ####
#######################

BEANSTALK_SERVER = 'beanstalk.example.com'
BEANSTALK_PORT = 11300

################################################################
#### DON'T EDIT PAST HERE UNLESS YOU KNOW WHAT YOU'RE DOING ####
################################################################

beanstalk = beanstalkc.Connection(host=BEANSTALK_SERVER, port=BEANSTALK_PORT)

def signal_handler(signal, frame):
    beanstalk.close()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

#Let's clear out the queue first.  So we don't explode when we start

while True:
    job = beanstalk.peek_ready()

    if job == None:
        break

    job.delete()

#now we wait for messages
while True:
    job = beanstalk.reserve()

    Notify.init('irssi')

    try:
        data = json.loads(job.body);

        title = ''
        if 'title' in data:
            title = data['title']

        body = ''
        if 'body' in data:
            body = data['body']

        msgtype = ''
        if 'msgtype' in data:
            msgtype = data['msgtype']

        notification = Notify.Notification.new(title, body, msgtype)
        notification.show()
    except ValueError:
        print 'Decoding json failed'

    job.delete()