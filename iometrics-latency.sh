#!/bin/bash
#
# Capture latency of a given filesystem and dump it to InfluxDB via Telegraf's script runner
#
# For SaFeTy, you must configure the '.benchmark' subfolder within the path you want to benchmark, and
#  that path must be writable by whatever is running this script, presumably Telegraf.
#
# To set this up, simply as root, 'mkdir -p /some/test/path/.benchmark && chown telegraf:telegraf the folder'
#  After the folder is created, make sure that the user can traverse the preceding path.  This might involve
#  adding the telegraf user to whichever group owns the path you want to test.

MEASUREMENT="iometrics_latency"
debug=true

# Test tunables
TEST_INTERVAL="0.5"   # interval between iopings, in seconds
TEST_SIZE="128k"      # ioping request size, in human size numbers, eg '128k' for a 128KB file, or '2m' for a 2MB file
TESTDIR=".benchmark"

# This is the path to run IO Latency ping against - the path will decide the underlying filesystem, and components beneath for analysis.
#  let's take every arg that the script is fed and iterate over them.
TESTPATH="$@"


# ==== PRE-FLIGHT CHECKS =======================
# We don't like systems that don't have logger installed.  Then again we've never seen one that doesn't.  But it's still better
#  to be safe than sorry.
which logger >/dev/null 2>&1 || exit 22

# If the ioping package isn't installed, log this issue to syslog and exit quietly.
which ioping >/dev/null 2>&1 
if [[ $? -ne 0 ]]; then
  logger -t iometrics-telegraf "ioping not installed on system - can't collect latency metrics"
  exit 33
fi

# ==== TASK FUNCTIONS ==========================
test_that_dir ()  {
  [[ -d $1/$TESTDIR ]]
  if [[ $? -ne 0 ]]; then
    logger -t iometrics-telegraf "benchmark directory $1/$TESTDIR doesn't exist"
    exit 44
  fi
}

run_benchmark () {
  # Run ioping w/ a 0.1s interval, 21 times, using sync & write options, return the 6th output field,
  #  which is average latency in nanoseconds
  export IOPING_NANOSECONDS="$(ioping -i $TEST_INTERVAL -p 10 -c 11 -W -Y -s $TEST_SIZE -q $1/$TESTDIR | cut -f6 -d' ')" 
  # Perform some basic arithmetic to return Milliseconds, divide nanoseconds by 1,000,000
  export IOPING_MILLISECONDS="$(awk -v var1=$IOPING_NANOSECONDS -v var2=1000000 'BEGIN { print  ( var1 / var2 ) }')"
  # Log some debugging information if we want it.
  if $debug; then
    logger -t $MEASUREMENT "Latency on $TESTPATH is $IOPING_NANOSECONDS nanoseconds, or $IOPING_MILLISECONDS milliseconds"
  fi
}

influx_line_protocol_output () {
  # Print the actual measurement.  When Telegraf execs this script, it'll take this output and ship it.
  tag_set="path=$1"
  printf "$MEASUREMENT,$tag_set ioping_latency=$IOPING_MILLISECONDS $(date +%s%N) \n"
}

for path in $TESTPATH; do
  test_that_dir $path
  run_benchmark $path
  influx_line_protocol_output $path
done
