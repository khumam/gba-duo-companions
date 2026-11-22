#!/bin/bash
# usage: w.sh OFF=VAL[:W] ... -- steps   (OFF relative to save base 0x02004DE0, hex)
args=(); 
while [ "$1" != "--" ]; do o=${1%%=*}; v=${1#*=}; args+=("wr:$(printf '%08X' $((0x02004DE0+0x$o)))=$v"); shift; done; shift
/tmp/hm/p.sh w60 "${args[@]}" "$@"
