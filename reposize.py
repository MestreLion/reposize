#!/usr/bin/env python
#
# reposize - Calculates the size of an Ubuntu or Debian repository
#
#    Based on reposize.sh <https://pzt.me/6xbd> written by Eduardo Lago Aguilar
#    <eduardo.lago.aguilar@gmail.com>. Original code retrieved in 2012-03-21
#
#    Copyright (C) 2012 Rodrigo Silva (MestreLion) <linux@rodrigosilva.com>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program. If not, see <http://www.gnu.org/licenses/gpl.html>
#
# This script computes the total size of various Debian-based repositories by
# means of downloading the Packages.gz and making a sum of the size of every
# package. Of course, there are many shared/common packages between different
# versions of the same Linux distro. So this script will compute the max
# possible size.
#
# Additionally the script saves the size for every collection of packages
# (Packages.gz) on a temporal archive, so if you run the script twice it won't
# download the Packages.gz again. If you want to disable this, and download the
# Packages.gz always then remove the file existence condition before the call to
# _wget_size: "[ -e /tmp/${dist/\//_}_${component/\//_}_${arch} ] ||"

#===============================================================================
# Calculates the size of Debian repositories, including derivatives as Ubuntu
#
# General Options:
# -h|--help     - show this page.
# -v|--verbose  - print more details about what is being done.
#
# Filter Options:
# --distro    DISTRO,...    Distribuitions (debian,ubuntu,mint)
# --release   RELEASE,...   Releases (stable,oneiric,lisa)
# --component COMPONENT,... Components (main,contrib,universe,multiverse)
# --arch      ARCH,...      Architectures (i386,amd64)
#
# For each filter option, if blank or ommited, all values are shown. Both
# --fiter value and --fiter=value formats are accepted. For releases, it will
# match the begin of the repository name, so --release lucid will also show
# lucid-backports, lucid-proposed, lucid-security and lucid-updates. For arch,
# "binary-" will be appended
#
# Examples:
# $ $self --distro mint
# $ $self --arch=i386
# $ $self --arch=amd64 --release=lucid,maverick --component main
#
# Copyright (C) 2012 Rodrigo Silva (MestreLion) <linux@rodrigosilva.com>
# License: GPLv3 or later. See <http://www.gnu.org/licenses/gpl.html>
#===============================================================================
'''
Created on Mar 21, 2012

@author: rodrigo
'''
import os.path
import xdg.BaseDirectory as xdg
import argparse
import urllib2

#===============================================================================
# invalid() { echo "$self: invalid option $1" ; usage 1 ; }
# missing() { echo "missing ${1:+$1 }operand" ; usage 1 ; }
#
# fatal() { [[ "$1" ]] && printf "%s\n" "$self: $1" >&2 ; exit "${2:-1}" ; }
#
# _size_for_repo() {
#    zcat "$1" | awk '$1=="Size:"{size+=$2} END{print size}' | tee "$2"
# }
#
# _size_for_distro() {
#    local distro_total=0
#    for dist in $dists ; do
#        for component in $components ; do
#            for arch in $archs ; do
#                url=${base_url}/${dist}/${component}/${arch}
#                cachefile=${cachedir}/${dist/\//_}_${component/\//_}_${arch}.gz
#                if [[ -e "$cachefile" ]] ; then
#                    : #curl -o "$cachefile" --time-cond "$cachefile" "$url/Packages.gz"
#                else
#                    curl -o "$cachefile" "$url/Packages.gz"
#                fi
#            done
#        done
#    done
#
#    echo -e "\n${distro_name} DISTRO SIZE SUMMARY"
#    echo "=================================="
#    for dist in $dists ; do
#        for component in $components ; do
#            for arch in $archs ; do
#                cachefile="${cachedir}/${dist/\//_}_${component/\//_}_${arch}.gz"
#                sizefile="$cachefile.size.txt"
#                reposize=$(_size_for_repo "$cachefile" "$sizefile")
#                (( distro_total += reposize ))
#                printf "%'8d MB - %s %s %s\n" $((reposize/(1024*1024))) "$dist" "$component" "$arch"
#            done
#        done
#    done
#    (( total += distro_total ))
#    printf "%'8d MB [%'3d GB] - TOTAL DISTRO SIZE\n" $((distro_total/(1024*1024))) $((distro_total/(1024*1024*1024)))
# }
#===============================================================================

cachedir = os.path.join( xdg.xdg_cache_home , "reposize" )

verbose = 0



#mkdir - p "$cachedir" || fatal "could not create cache directory $cachedir"

total = 0

distros = ( "ubuntu", "debian", "linuxmint" )
urls = dict(
    ubuntu = ["http://archive.ubuntu.com/ubuntu"],
    debian = ["http://ftp.debian.org/debian",
              "http://security.debian.org/debian-security"],
    linuxmint = [  "http://packages.linuxmint.com"],
 )
releases = dict(
    ubuntu = ["lucid-backports"   , "lucid-proposed"   , "lucid-security"   , "lucid-updates"   , "lucid",
            "maverick-backports", "maverick-proposed", "maverick-security", "maverick-updates", "maverick",
            "natty-backports"   , "natty-proposed"   , "natty-security"   , "natty-updates"   , "natty",
            "oneiric-backports" , "oneiric-proposed" , "oneiric-security" , "oneiric-updates" , "oneiric",
            "precise-backports" , "precise-proposed" , "precise-security" , "precise-updates" , "precise",
             ],
    debian = ["oldstable", "oldstable-proposed-updates", "oldstable/updates",
             "stable"  , "stable-proposed-updates"   , "stable/updates"   , "stable-updates",
             "testing" , "testing-proposed-updates"  , "testing/updates"  ,
             "unstable",
             ],
    linuxmint = [  "debian",
            "julia",
            "katya",
            "lisa",
           ],
 )
components = dict(
    ubuntu = ["main", "multiverse", "restricted", "universe" ],
    debian = ["main", "contrib"   , "non-free" ],
    linuxmint = [  "main", "backport", "import", "romeo", "upstream"],
 )
archs = [ "binary-i386", "binary-amd64" ]

packages=[]

for distro in distros:
    for rel in releases[distro]:
        for comp in components[distro]:
            for arch in archs:

                filename=rel.replace("/","_") + "_" + comp.replace("/","_") + "_" + arch + ".gz"
                file = os.path.join(cachedir,filename)

                if os.path.exists(file):
                    mtime = os.path.getmtime(file)
                    os.rename(file, os.path.join(cachedir,distro+"_"+filename))
                else:
                    mtime = 0

                for base in urls[distro]:
                    url = os.path.join( base, "dists" , rel, comp, arch , "Packages.gz" )
                    print url
                    #req = urllib2.Request(url)
                    #req.add_header('If-Modified-Since', mtime)
                    #r = urllib2.urlopen(req)
                    # = "If-Modified-Since" ":" HTTP-date

#printf "%'8d MB [%'3d GB] - GRAND TOTAL SIZE\n" $( ( total / ( 1024 * 1024 ) ) ) $( ( total / ( 1024 * 1024 * 1024 ) ) )

#http://ftp.us.debian.org/debian/
#http://security.debian.org/

if __name__ == '__main__':
    pass