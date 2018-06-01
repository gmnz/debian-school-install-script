#!/bin/bash
		while true
		do
#pidof conky >/dev/null
#if [[ $? -ne 0 ]] ; then
		        conky &
		#fi
		sleep 15
			killall conky
				done
