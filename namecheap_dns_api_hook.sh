#!/bin/bash
case "$1" in
	*_challenge)
		apiusr=
		apikey=
		cliip=
		num=0
		sld=`sed -E 's/(.*\.)*([^.]+)\..*/\2/' <<< "$2"`
		tld=`sed -E 's/.*\.([^.]+)/\1/' <<< "$2"`
		sub=`sed -E "s/$sld.$tld//" <<< "$2"`
		echo $sub
		records_list=`/usr/bin/curl -s "https://api.namecheap.com/xml.response?apiuser=$apiusr&apikey=$apikey&username=$apiusr&Command=namecheap.domains.dns.getHosts&ClientIp=$cliip&SLD=$sld&TLD=$tld" | sed -En 's/<host (.*)/\1/p'`
		sethosts_uri="https://api.namecheap.com/xml.response?apiuser=$apiusr&apikey=$apikey&username=$apiusr&Command=namecheap.domains.dns.setHosts&ClientIp=$cliip&SLD=$sld&TLD=$tld"
		if [[ "$1" = "clean_challenge" ]]
			then
				records_list=`sed '/acme-challenge/d' <<< "$records_list"`
		fi
		while read -r current_record
			do
			num=$(( $num+1 ))
			#
			# It is necessary to keep the information about records, because in the case of wrong request, syntax mistakes, etc ALL records at this domain may be lost. And probably you will try restore it.
			#
			record_params=`sed -E 's/^[^"]*"|"[^"]*$//g; s/"[^"]+"/ /g; s/ +/ /g' <<< "$current_record" | tee records_backup/$2\_$num\_record.txt`
			while read -r hostid hostname recordtype address mxpref ttl associatedapptitle friendlyname isactive isddnsenabled
			do
			if [[ "$recordtype" = "MX" ]]
				then
					sethosts_uri=$sethosts_uri"&hostname$num=$hostname&recordtype$num=$recordtype&address$num=$address&mxpref$num=$mxpref&ttl$num=$ttl"
				else
					sethosts_uri=$sethosts_uri"&hostname$num=$hostname&recordtype$num=$recordtype&address$num=$address&ttl$num=$ttl"
			fi
			done <<< "$record_params"
		done <<< "$records_list"
		num=$(( $num+1 ))
		if [[ "$1" = "deploy_challenge" ]]
		then
			cheking_counter=0
			sethosts_uri_acme=$sethosts_uri"&hostname$num=_acme-challenge.$sub&recordtype$num=TXT&address$num=$4&ttl$num=60"
			/usr/bin/curl -sv $sethosts_uri_acme 2>&1 > /dev/null
			until dig txt _acme-challenge.$2 | grep $4 2>&1 > /dev/null
				do
				if [[ "$cheking_counter" -ge 1800 ]]
					then						
						break
					else
						cheking_counter=$(( $cheking_counter+1 ))
						sleep 1
				fi
			done
		else
			/usr/bin/curl -sv $sethosts_uri 2>&1 > /dev/null
		fi
	;;
	*)
		echo Unkown hook "${1}"
		exit 1
	;;
esac
exit 0
