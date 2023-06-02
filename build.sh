#!/bin/sh
options='src/ -out:out/main'

if [ -z "$1" ]; then
  eval "odin build ${options}"
elif [ $1 = "run" ]; then
  eval "odin run ${options}"
else
  echo 'invalid argument'
  exit 1
fi
