#!/usr/bin/env bash
#
# This thing reads all logstash indices, reindexes them and deletes the old ones
# It's not a very beautiful or sophisticated script, but it get's the job done
#

set -o pipefail
set -o nounset

# connectionstring to the elasticsearch server
readonly cstr="localhost:9200"

# don't delete indices if warnings/errors occured
readonly safemode=0

# get all indices
indices=$(curl -s -X GET "${cstr}/_cat/indices?v" | grep 'logstash' | awk '{ print $3 }')

for index in $indices ; do
	# skip indices already reindexed
	if [ `echo $index | grep 'reindexed' | wc -l` -ne 0 ] ; then
		continue
	fi
	echo "reindexing $index"
	json="
{
  \"source\": {
    \"index\": \"${index}\"
  },
  \"dest\": {
    \"index\": \"${index}.reindexed\"
  }
}
"
	out=`curl -s -X POST "${cstr}/_reindex?pretty" -H 'Content-Type: application/json' -d"${json}"`
	if [ `echo $out | grep '"failures" : \[ \]' | wc -l` -eq 1 ] ; then 
		echo "success, deleting old index"
		curl -XDELETE "localhost:9200/${index}?pretty"
	else
		if [ "$safemode" -eq 0 ] ; then 
			echo "failed, deleting nontheless" 
			echo $out
			curl -XDELETE "localhost:9200/${index}?pretty"
		else
			echo "failed"
			echo $out
		fi
	fi
	echo
done
