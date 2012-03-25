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


usage() {
cat <<- USAGE
	Usage: $self [options]
USAGE
if [[ "$1" ]] ; then
	cat <<- USAGE
		Try '$self --help' for more information.
	USAGE
	exit 1
fi
cat <<-USAGE

	Calculates the size of Debian repositories, including derivatives as Ubuntu

	General Options:
	-h|--help     - show this page.
	-v|--verbose  - print more details about what is being done.

	Filter Options:
	--distro    DISTRO,[...]    Distribuitions (debian,ubuntu,mint)
	--release   RELEASE,[...]   Releases (stable,oneiric,lisa)
	--component COMPONENT,[...] Components (main,contrib,universe,multiverse)
	--arch      ARCH,[...]      Architectures (i386,amd64)

	For each filter option, if blank or ommited, all values are shown. For
	releases, it will match the begin of the repository name, so --release lucid
	will also show lucid-backports, lucid-proposed, lucid-security and
	lucid-updates. For arch, "binary-" will be appended

	Result Options:
	--installed        show Installed Size instead. Default is package size
	--collapse  GROUP  collapse the given group (distro,release,component,arch),
	                   and all its "subgroups", in a single result line.

	Examples:
	$ $self --distro mint
	$ $self --arch=i386
	$ $self --arch=amd64 --release=lucid,maverick --component main

	Copyright (C) 2012 Rodrigo Silva (MestreLion) <linux@rodrigosilva.com>
	License: GPLv3 or later. See <http://www.gnu.org/licenses/gpl.html>
USAGE
exit 0
}
invalid() { echo "$self: invalid option $1" ; usage 1 ; }
missing() { echo "missing ${1:+$1 }operand" ; usage 1 ; }

fatal() { [[ "$1" ]] && printf "%s\n" "$self: $1" >&2 ; exit "${2:-1}" ; }

_set_group() {
	case "$1" in
	distro ) group=4 ;;
	release) group=3 ;;
	comp   ) group=2 ;;
	arch   ) group=1 ;;
	?*     ) invalid "for --collapse: $1" ;;
	*      ) missing "collapse"
	esac
}

_printrepo() {
	printf "%'9d MB - %s %s %s\n" $(($1/(1024*1024))) "$2" "$3" "$4"
}

_size_for_repo() {
	[[ -f "$1" ]] || { echo 0 ; return 1 ; }
	if (( installed )) ; then
		zcat "$1" | awk -v size=0 '$1=="Installed-Size:"{size+=1024*$2} END{print size}'
	else
		zcat "$1" | awk -v size=0 '$1=="Size:"{size+=$2} END{print size}'
	fi
}

_size_for_distro() {
	local distro_total=0
	local reposize=0
	local subtotal=0
	for dist in $dists ; do
		for component in $components ; do
			for arch in $archs ; do
				url="${base_url}/${dist}/${component}/${arch}"
				cachefile="${cachedir}/${distro_name/\//_}_${dist/\//_}_${component/\//_}_${arch}.gz"
				if [[ -f "$cachefile" ]] ; then
					: #curl -o "$cachefile" --time-cond "$cachefile" "$url/Packages.gz"
				else
					curl -L -f -s -S -o "$cachefile" "$url/Packages.gz"
				fi
			done
		done
	done

	echo -e "\n${distro_name} DISTRO${instlabel} SIZE SUMMARY"
	echo "===================================="
	for dist in $dists ; do
		for component in $components ; do
			for arch in $archs ; do
				cachefile="${cachedir}/${distro_name/\//_}_${dist/\//_}_${component/\//_}_${arch}.gz"
				sizefile="$cachefile.size.txt"
				(( reposize = $(_size_for_repo "$cachefile" "$sizefile") ))
				(( subtotal += reposize ))
				(( distro_total += reposize ))
				(( group == 0 )) && { _printrepo "$subtotal" "$dist" "$component" "$arch" ; subtotal=0 ; }
			done
			(( group == 1 )) && { _printrepo "$subtotal" "$dist" "$component" ; subtotal=0 ; }
		done
		(( group == 2 )) && { _printrepo "$subtotal" "$dist" ; subtotal=0 ; }
	done
	(( total += distro_total ))
	printf "%'9d MB [%'6d GB] - TOTAL DISTRO${instlabel} SIZE\n" $((distro_total/(1024*1024))) $((distro_total/(1024*1024*1024)))
}

self="${0##*/}"
cachedir=${XDG_CACHE_HOME:-~/.cache}/reposize
today=$(date +'%Y%m%d')
verbose=0
group=0
installed=0
instlabel=
uarch=

# Loop options
while (( $# )); do
	case "$1" in
	-h|--help     ) usage                   ;;
	-v|--verbose  ) verbose=1               ;;
	--distro      ) distro_name=            ;;
	--release     ) dists=                  ;;
	--component   ) components=             ;;
	--arch        ) shift ; uarch="binary-$1" ;;
	--installed   ) installed=1             ;;
	--collapse    ) shift ; _set_group "$1" ;;
	--            ) shift        ; break    ;;
	-*            ) invalid "$1" ; break    ;;
	*             )                break    ;;
	esac
	shift
done

(( installed )) && instlabel=" INSTALLED"

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
archs=${uarch:-"binary-i386 binary-amd64"}
_size_for_distro

distro_name=debian
base_url=http://ftp.debian.org/debian/dists
dists=""
dists="${dists} oldstable-proposed-updates oldstable"
dists="${dists} stable-proposed-updates stable-updates stable"
dists="${dists} testing-proposed-updates testing"
dists="${dists} unstable"
components="main contrib non-free"
archs=${uarch:-"binary-i386 binary-amd64"}
_size_for_distro

distro_name=debian-security
base_url=http://security.debian.org/debian-security/dists
dists=""
dists="${dists} oldstable/updates"
dists="${dists} stable/updates"
dists="${dists} testing/updates"
components="main contrib non-free"
archs=${uarch:-"binary-i386 binary-amd64"}
_size_for_distro

distro_name=linuxmint
base_url=http://packages.linuxmint.com/dists
dists=""
dists="${dists} debian"
dists="${dists} julia"
dists="${dists} katya"
dists="${dists} lisa"
components="backport import main romeo upstream"
archs=${uarch:-"binary-i386 binary-amd64"}
_size_for_distro

printf "\n%'9d MB [%'6d GB] - GRAND TOTAL${instlabel} SIZE\n" $((total/(1024*1024))) $((total/(1024*1024*1024)))
