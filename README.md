# boomi-utils
A collection of utility scripts for [Dell Boomi](https://boomi.com/) using the Atomsphere API.

Requirements:
* libxml2-utils
* fluentd (log-* scripts)
* fluent-cat plugin
* fluentd elasticsearch plugin
*** I reccomend using the ruby gem method to install fluentd and the plugins. I had issues getting fluent-cat to work right using TD-agent and other install methods.

## download-atom-log
Download a given atom's container logs when provided a valid account and login.

## download-process-log
Downloads process logs for every execution on an atom in the past minute (or given interval).

## read-exe-feed
Read executions from RSS feed for a given account.

## get-scheduled-process-count
Get a count of scheduled process executions by id within the past interval.

## log-exe
Logs a given execution using fluent-cat.

## fluent.conf
The configuration to accept logs from the Boomi scripts, and send them to Elasticsearch.
