#!/bin/sh

if [ ! -d './out' ]; then
  mkdir out
fi

options='src/ -out:out/main -debug -sanitize:address'

if [ -z "$1" ]; then
  odin build ${options}
elif [ $1 = "run" ]; then
  odin run ${options}
else
  echo 'invalid argument'
  exit 1
fi
