#!/bin/bash
#
# Capture latency of a given filesystem and dump it to InfluxDB via Telegraf's script runner
#
measurement="iometrics-latency"
tag_set="" #comma separated key=values
debug=true

# This is the path to run IO Latency ping against - the path will decide the underlying filesystem, and components beneath for analysis.
TESTPATH=/opt
TESTDIR=".benchmark"

which logger >/dev/null 2>&1 || exit 22

which ioping >/dev/null 2>&1 

if [[ $? -ne 0 ]]; then
  logger -t iometrics-telegraf "ioping not installed on system - can't collect latency metrics"
  exit 33
fi

[[ -d $TESTPATH/$TESTDIR ]] || mkdir -p $TESTPATH/$TESTDIR

# Run ioping w/ a 0.1s interval, 21 times, using sync & write options, return the 6th output field,
#  which is average latency in nanoseconds
TESTCOMMAND=$(ioping -i 0.5 -p 10 -c 11 -W -Y -s 128k -q $TESTPATH/$TESTDIR | cut -f6 -d' ')

TESTMS="$(awk -v var1=$TESTCOMMAND -v var2=1000000 'BEGIN { print  ( var1 / var2 ) }')"

if $debug; then
  echo "Latency on $TESTPATH is $TESTCOMMAND nanoseconds, or $TESTMS milliseconds"
fi


printf "$measurement,$tag_set $field_set ioping_latency=$TESTMS $(date +%s%N) \n"
