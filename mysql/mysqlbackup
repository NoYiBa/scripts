#!/usr/bin/env python
''' Author: Jean-Francois Theroux <failshell@gmail.com>

    Features:
        - Backup either all DBs or some of them
        - Connects to localhost
        - Uses the Debian maintainer user so no new grant 
          is required

    License: GNU General Public License version 2 '''

import datetime
import gzip
import MySQLdb
import os
import shlex
import socket
import subprocess
import sys
from optparse import OptionParser

def main():
    print '''mysqlbackup.py 0.1'''
    check_os_type()
    helpmenu()
    if not opts.destdir:
        parser.print_help()
        sys.exit(1)
    if opts.all and opts.databases:
        print 'ERROR: Conflicting options.'
        parser.print_help()
        sys.exit(1)
    print 'hostname :', socket.getfqdn()
    for each in [ 'version', 'version_comment', 'version_compile_machine', 'version_compile_os' ]:
        for row in initdb('mysql', "SHOW VARIABLES LIKE '%s'" % each):
            print row[0], ':', row[1]
    date = datetime.datetime.now().strftime('%Y-%m-%d')
    file = '%s/all-%s.sql' % (opts.destdir,date)
    if os.path.exists(file + '.gz'):
        print 'WARN: Backup file already exists. Aborting.'
        sys.exit(2)
    if opts.all:
        print 'backup of all databases to %s/all-%s.sql:' % (opts.destdir,date), 
        try:
            subprocess.Popen(shlex.split('mysqldump --defaults-file=/etc/mysql/debian.cnf -A -r %s' % file))
            print 'ok'
        except:
            print 'error'
            sys.exit(1)
        print 'compressing backup file:',
        try:
            subprocess.Popen(shlex.split('gzip -9 %s' % file))
            print 'ok'
        except:
            print 'error'
        
    if opts.databases:
        print 'ERROR: Not implemented yet.'
        sys.exit(1)

def check_os_type():
    if not os.path.exists('/etc/debian_version'):
        print 'ERROR: Invalid OS type. Debian-based only systems are supported for now.'
        sys.exit(1)

def helpmenu():
    global parser, opts, args
    parser = OptionParser()
    parser.add_option('-a', action='store_true', dest='all', help='Backup all databases')
    parser.add_option('-d', dest='destdir', help='Destination directory of dump files (required)')
    parser.add_option('--db', dest='databases', help='Specific databases to backup')
    parser.add_option('-n', dest='num', help='Number of backups to keep')
    (opts, args) = parser.parse_args()
    return parser, opts, args

def initdb(d, query):
    if not os.access('/etc/mysql/debian.cnf', os.R_OK):
        print 'ERROR: Cannot read debian.cnf.'
        sys.exit(1)
    db = MySQLdb.connect(host='localhost', db=d, read_default_file='/etc/mysql/debian.cnf')
    q = db.cursor()
    q.execute(query)
    db.close()
    return q.fetchall()

if __name__ == '__main__':
    main()
