#!/bin/bash
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

_wget_size() {
	wget $1 -O - | zcat | sed 's/Installed-Size://' | grep Size | 
	awk '/Size:/ {pkgsize+=$2} END {print "package size = "pkgsize" Bytes"}'
}

_store() {
	local size=$(sed -e 's/package size = \(.*\) Bytes/\1/')
	size=${size:-0}
	cat > $1 <<-EOT
		${size}
	EOT
}

_size_for_distro() {
	local distro_total=0
	for dist in $dists ; do
		for component in $components ; do
			for arch in $archs ; do
				[ -e /tmp/${dist/\//_}_${component/\//_}_${arch} ] || ( _wget_size ${base_url}/${dist}/${component}/${arch}/Packages.gz | _store /tmp/${dist/\//_}_${component/\//_}_${arch} )
				distro_total=$(( distro_total + $(cat /tmp/${dist/\//_}_${component/\//_}_${arch}) ))
			done
		done 
	done
	total=$(( total + distro_total ))

	echo -e "\n${distro_name} DISTRO SIZE SUMMARY"
	echo "=================================="
	for dist in $dists ; do
		for component in $components ; do
			for arch in $archs ; do
				echo "${dist} ${component} ${arch}: "$(( $(cat /tmp/${dist/\//_}_${component/\//_}_${arch}) / 1024 / 1024 ))" MB"
			done
		done 
	done
	echo "TOTAL DISTRO SIZE = "$(( $distro_total / 1024 / 1024 ))" MB ["$(( $distro_total / 1024 / 1024 / 1024 ))" GB]"
}


total=0

distro_name=ubuntu
base_url=http://archive.ubuntu.com/ubuntu/dists
dists=""
dists="${dists} lucid-backports lucid-proposed lucid-security lucid-updates lucid"
dists="${dists} maverick-backports maverick-proposed maverick-security maverick-updates maverick"
dists="${dists} natty-backports natty-proposed natty-security natty-updates natty"
dists="${dists} oneiric-backports oneiric-proposed oneiric-security oneiric-updates oneiric"
dists="${dists} precise-backports precise-proposed precise-security precise-updates precise"
components="main multiverse restricted universe"
archs="binary-i386 binary-amd64"
archs="binary-amd64"
_size_for_distro

distro_name=debian
base_url=http://ftp.debian.org/debian/dists
dists=""
dists="${dists} lenny" 	
dists="${dists} squeeze-proposed-updates squeeze-updates squeeze"
components="main contrib non-free"
archs="binary-i386 binary-amd64 binary-armel binary-arm"
_size_for_distro

distro_name=debian-security
base_url=http://security.debian.org/debian-security/dists
dists=""
dists="${dists} lenny/updates"
dists="${dists} squeeze/updates"
components="main contrib non-free"
archs="binary-i386 binary-amd64 binary-armel binary-arm"
_size_for_distro

distro_name=debian-volatile
base_url=http://volatile.debian.org/debian-volatile/dists
dists=""
dists="${dists} lenny/volatile lenny-proposed-updates/volatile"
components="main contrib non-free"
archs="binary-i386 binary-amd64 binary-armel binary-arm"
_size_for_distro

echo -e "\nTOTAL SIZE: "$(( $total / 1024 / 1024 / 1024 ))" GB"
