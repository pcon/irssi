#!/usr/bin/env python

# beanstalk-notify is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

"""This script is ment to be used with the irssi script beanstalkNotify.pl to
send notifications to a beanstalk queue.  For more information please visit
http://github.com/pcon/irssi"""

__author__ = "Patrick Connelly (patrick@deadlypenguin.com)"
__version__ = "2.0-0"

import logging
import httplib, urllib
import beanstalkc
import json
import subprocess
import cgi
import time
import ConfigParser
import os
import sys

from daemon import runner

APP_NAME = 'beanstalk-notify'
ROOT_DIR = "%s/.%s" % (os.path.expanduser("~"), APP_NAME, )
CONFIG_FILE = "%s/%s.conf" % (ROOT_DIR, APP_NAME, )

config = ConfigParser.ConfigParser()

try:
    config.readfp(open(CONFIG_FILE))
except IOError:
    config.add_section('beanstalk')
    config.set('beanstalk', 'server', 'beanstalk.example.com')
    config.set('beanstalk', 'port', 11300)
    config.set('beanstalk', 'clear_on_start', 'true')
    config.set('beanstalk', 'away_tube', 'irc_away')
    config.set('beanstalk', 'away_ignore', 'im')
    config.set('beanstalk', 'here_tube', 'irc_here')
    config.set('beanstalk', 'here_ignore', '')

    config.add_section('pushover')
    config.set('pushover', 'app_token', 'MYAPPTOKEN')
    config.set('pushover', 'user_key', 'MYUSERKEY')

    config.add_section('notification')
    config.set('notification', 'use_native', 'true')
    config.set('notification', 'type', 'dialog-information')

    config.add_section('daemon')
    config.set('daemon', 'log_level', 'INFO')

    if not os.path.isdir(ROOT_DIR):
        os.mkdir(ROOT_DIR)

    with open(CONFIG_FILE, 'wb') as configfile:
        config.write(configfile)

    print "Config file did not exist. Default config created at '%s'" % (CONFIG_FILE, )
    sys.exit(1)


BEANSTALK_SERVER = config.get('beanstalk', 'server')
BEANSTALK_PORT = config.getint('beanstalk', 'port')
BEANSTALK_CLEAR_TUBES = config.getboolean('beanstalk', 'clear_on_start')
BEANSTALK_IGNORE_DEFAULT = True
BEANSTALK_DEFAULT = 'default'

BEANSTALK_AWAY_TUBE = config.get('beanstalk', 'away_tube')
BEANSTALK_AWAY_SERVER_IGNORE = config.get('beanstalk', 'away_ignore').split(',')

BEANSTALK_HERE_TUBE = config.get('beanstalk', 'here_tube')
BEANSTALK_HERE_SERVER_IGNORE = config.get('beanstalk', 'here_ignore').split(',')

PUSHOVER_APP_TOKEN = config.get('pushover', 'app_token')
PUSHOVER_USER_KEY = config.get('pushover', 'user_key')

NOTIFICATION_NATIVE = config.getboolean('notification', 'use_native')
NOTIFICATION_TYPE = config.get('notification', 'type')

LOG_LEVEL = config.get('daemon', 'log_level')

try:
    import gi
    from gi.repository import Notify
except:
    NOTIFICATION_NATIVE = False

class App():
    def __init__(self):
        self.stdin_path = '/dev/null'
        self.stdout_path = '/dev/tty'
        self.stderr_path = '/dev/tty'
        self.pidfile_path = "%s/%s.pid" % (ROOT_DIR, APP_NAME, )
        self.pidfile_timeout = 5

    def run(self):
        logger.debug("Starting up")

        beanstalk = None

        try:
            beanstalk = beanstalkc.Connection(host=BEANSTALK_SERVER, port=BEANSTALK_PORT)
        except beanstalkc.SocketError:
            logger.error("Unable to connect to '%s:%s'" % (BEANSTALK_SERVER, BEANSTALK_PORT,))
            sys.exit(-1)

        beanstalk.watch(BEANSTALK_HERE_TUBE)
        beanstalk.watch(BEANSTALK_AWAY_TUBE)

        if BEANSTALK_IGNORE_DEFAULT:
            beanstalk.ignore(BEANSTALK_DEFAULT)

        logger.debug("Watching %s tube(s)" % (beanstalk.watching(), ))

        if BEANSTALK_CLEAR_TUBES:
            while True:
                job = beanstalk.reserve(timeout=0)

                if job == None:
                    break

                logger.debug("Deleting old job")

                job.delete()

        while True:
            job = beanstalk.reserve(timeout=0)

            if job != None:
                try:
                    data = json.loads(job.body);

                    logger.debug('Got json message %s' % (data,))

                    channel = ''
                    if 'channel' in data:
                        channel = data['channel']

                    message = ''
                    if 'message' in data:
                        message = data['message']

                    server = ''
                    if 'server' in data:
                        server = data['server']

                    if job.stats()['tube'] == BEANSTALK_HERE_TUBE:
                        if not server in BEANSTALK_HERE_SERVER_IGNORE:
                            channel = cgi.escape(channel)
                            message = cgi.escape(message)
                            # This is how it should be done.  But it keeps dying in fluxbox.  Adding alternate
                            if NOTIFICATION_NATIVE:
                                try:
                                    logger.debug("Sending message '%s' via Native Notification" % (message, ))

                                    Notify.init('beanstalk-notify')
                                    notification = Notify.Notification.new(channel, message, NOTIFICATION_TYPE)
                                    notification.show()
                                except gi._glib.GError:
                                    logger.error("Notification failing. If this persists, set use_native to False")
                            else:
                                logger.debug("Sending message '%s' via subprocess" % (message, ))
                                subprocess.Popen(['notify-send', channel, message])
                        else:
                            logger.debug("Message ingnored for server '%s'" % (server,))
                    elif job.stats()['tube'] == BEANSTALK_AWAY_TUBE:
                        if not server in BEANSTALK_AWAY_SERVER_IGNORE:
                            logger.debug("Sending Message '%s' via Pushover" % (message, ))

                            conn = httplib.HTTPSConnection("api.pushover.net:443")
                            conn.request("POST", "/1/messages.json",
                                urllib.urlencode({
                                    "token": PUSHOVER_APP_TOKEN,
                                    "user": PUSHOVER_USER_KEY,
                                    "title": "New message from %s" % (channel, ),
                                    "message": message,
                                }), { "Content-type": "application/x-www-form-urlencoded" })
                            conn.getresponse()
                        else:
                            logger.debug("Message ingnored for server '%s'" % (server,))

                except ValueError:
                    logger.error("Decoding json failed")

                job.delete()
            time.sleep(1)

app = App()

logger = logging.getLogger(APP_NAME)
logger.setLevel(LOG_LEVEL)
formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
handler = logging.FileHandler("%s/%s.log" % (ROOT_DIR, APP_NAME, ))
handler.setFormatter(formatter)
logger.addHandler(handler)

daemon_runner = runner.DaemonRunner(app)
#This ensures that the logger file handle does not get closed during daemonization
daemon_runner.daemon_context.files_preserve=[handler.stream]
daemon_runner.do_action()