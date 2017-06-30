# boomi-utils
A collection of utility scripts for [Dell Boomi](https://boomi.com/) using the Atomsphere API.

Requirements:
* libxml2-utils
* fluentd (log-* scripts)

## download-atom-log
Download a given atom's container logs when provided a valid account and login.

## download-process-log
Downloads process logs for every execution on an atom in the past minute (or given interval).

## read-exe-feed
Read executions from RSS feed for a given account.

## log-exe
Logs a given execution using fluent-cat.
