#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset
set -ex

bold=$(tput bold)
bluebg=$(tput setaf 4)
normal=$(tput sgr0)


cmd=${1:-}

if test -z "$cmd" || test -z "$3" ; then
	echo "Usage: $0 {exec|runclone} <name> <command>"
	exit 1
fi

if ! test -f ~/.docker/config.json ; then
	mkdir -p ~/.docker
	# I REALLY want to use ctrl+p in bash.
	# (my best idea was ctrl-i -- YMMV)
	cat >>EOF>~/.docker/config.json
{
	"detachKeys": "ctrl-i,i"
}
EOF
fi

function find_container() {
	filter_=("$@")
	filter=""
	echo "filter: $filter_ -- $1" >&2
	for word in "${filter_[@]}" ; do
		filter="$filter.*$word"
	done
	filter="--filter name=$filter"
	echo "filter: $filter" >&2
	id=`docker ps ${filter} --format '{{.ID}}'`
	if test `echo "$id" | wc -l` -gt 1 ; then
		echo "Did not match uniquely. Which one?" >&2
		docker ps $filter --format '{{.ID}}\t{{.Names}}' >&2
		exit 1
	elif test -z "$id" ; then
		echo "Did not match any container." >&2
		exit 1
	fi
	echo $id
	exit 0
}

filter=$2
command=$3
if ! test -z "${4:-}" ; then
	echo "Unsupported 4th parameter $4"
	exit 1
fi

if test "$cmd" = "exec" ; then
	id=$(find_container $filter)
	echo "Okay, running..."
	docker exec -it $id $command
elif test "$cmd" = "runclone" ; then
	id=$(find_container $filter)
	# find out base image
	image=$(docker ps --filter "id=$id" --format "{{.Image}}")
	echo "${bold}${bluebg}Okay, running $image in network of $id"
	echo "Mounting `pwd` into /pwd${normal}"
	docker run --rm -it -v "`pwd`:/pwd" --network="container:$id" $image $command
fi

