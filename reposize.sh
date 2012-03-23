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

fatal() { [[ "$1" ]] && printf "%s\n" "$self: $1" >&2 ; exit "${2:-1}" ; }

_size_for_repo() {
	zcat "$1" | awk '$1=="Size:"{size+=$2} END{print size}' | tee "$2"
}

_size_for_distro() {
	local distro_total=0
	for dist in $dists ; do
		for component in $components ; do
			for arch in $archs ; do
				url=${base_url}/${dist}/${component}/${arch}
				cachefile=${cachedir}/${dist/\//_}_${component/\//_}_${arch}.gz
				if [[ -e "$cachefile" ]] ; then
					: #curl -o "$cachefile" --time-cond "$cachefile" "$url/Packages.gz"
				else
					curl -o "$cachefile" "$url/Packages.gz"
				fi
			done
		done 
	done

	echo -e "\n${distro_name} DISTRO SIZE SUMMARY"
	echo "=================================="
	for dist in $dists ; do
		for component in $components ; do
			for arch in $archs ; do
				cachefile="${cachedir}/${dist/\//_}_${component/\//_}_${arch}.gz"
				sizefile="$cachefile.size.txt"
				reposize=$(_size_for_repo "$cachefile" "$sizefile")
				(( distro_total += reposize ))
				printf "%'8d MB - %s %s %s\n" $((reposize/(1024*1024))) "$dist" "$component" "$arch"
			done
		done 
	done
	(( total += distro_total ))
	printf "%'8d MB [%'3d GB] - TOTAL DISTRO SIZE\n" $((distro_total/(1024*1024))) $((distro_total/(1024*1024*1024)))
}

self="${0##*/}"
cachedir=${XDG_CACHE_HOME:-~/.cache}/reposize
today=$(date +'%Y%m%d')

mkdir -p "$cachedir" || fatal "could not create cache directory $cachedir"

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
_size_for_distro

distro_name=debian
base_url=http://ftp.debian.org/debian/dists
dists=""
dists="${dists} oldstable-proposed-updates oldstable"
dists="${dists} stable-proposed-updates stable-updates stable"
dists="${dists} testing-proposed-updates testing"
dists="${dists} unstable"
components="main contrib non-free"
archs="binary-i386 binary-amd64"
_size_for_distro

distro_name=debian-security
base_url=http://security.debian.org/debian-security/dists
dists=""
dists="${dists} oldstable/updates"
dists="${dists} stable/updates"
dists="${dists} testing/updates"
components="main contrib non-free"
archs="binary-i386 binary-amd64"
_size_for_distro

printf "%'8d MB [%'3d GB] - GRAND TOTAL SIZE\n" $((total/(1024*1024))) $((total/(1024*1024*1024)))
