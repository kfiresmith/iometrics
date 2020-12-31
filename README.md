# IOMetrics
Collect and ship filesystem I/O  metrics to InfluxDB via Telegraf
Currently we only collect latency metrics for given filesystem paths, but eventually I'd like to add FIO metrics.


## Setup instructions - Latency
These instructions are also documented within the main script for easy reference on systems.

1. Create '.benchmark' directories within every path you wish to monitor for latency.
2. **Important:** Ensure that the user running the script (presumably 'telegraf') can fully traverse the path to the .benchmark folder(s), and can write into them.  This could involve adding the telegraf user to existing Unix groups and then stopping/starting the telegraf service.
3. Place the iometrics-latency-input.conf file into /etc/telegraf/telegraf.d
4. Edit the iometrics-latency-input.conf file to append all monitored paths as space-separated arguments in the exec command.
5. Place the iometrics-latency.sh file into /usr/local/bin
