#!/bin/bash

ORION="http://orion:1026/version"
IOT_AGENT="http://iot-agent:4041/version"
CONTEXT="http://context/user-context.jsonld"
CORE_CONTEXT="https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context-v1.8.jsonld"

pause(){
	printf " "
	count="$1"
	[ "$count" -gt 59 ] && printf "Waiting one minute " || printf " Waiting a few seconds "
	while [ "$count" -gt 0 ]
	do
		printf "."
		sleep 3
		count=$((count - 3))
	done
	echo ""
}

getHeartbeat(){
	eval "response=$(docker run --network default --rm quay.io/curl/curl:8.4.0 -s -o /dev/null -w "%{http_code}" "$1")"
}

waitForOrion () {
	echo -e "\n⏳ Waiting for \033[1;34mOrion-LD\033[0m to be available\n"

	while ! [ "$(docker inspect --format='{{.State.Health.Status}}' fiware-orion)" == "healthy" ]
	do
		echo -e "\nContext Broker HTTP state: ${response} (waiting for 200)"
		pause 6
		getHeartbeat "${ORION}"
	done
}

waitForMongo () {
	echo -e "\n⏳ Waiting for \033[1mMongoDB\033[0m to be available\n"
	while ! [ "$(docker inspect --format='{{.State.Health.Status}}' db-mongo)" == "healthy" ]
	do
		sleep 1
	done
}

waitForCoreContext () {
	echo -e "\n⏳ Checking availability of \033[1m core @context\033[0m from ETSI\n"
	eval "response=$(docker run --rm quay.io/curl/curl:8.4.0 -s -o /dev/null -w "%{http_code}" "$CORE_CONTEXT")"
	while [ "${response}" -eq 000 ]
	do
		echo -e "\n@context HTTP state: ${response} (waiting for 200)"
		pause 3
		eval "response=$(docker run --rm quay.io/curl/curl:8.4.0 -s -o /dev/null -w "%{http_code}" "$CORE_CONTEXT")"
	done
}

waitForUserContext () {
	echo -e "\n⏳ Waiting for user \033[1m@context\033[0m to be available\n"
	getHeartbeat "${CONTEXT}"
	while [ "${response}" -eq 000 ]
	do
		echo -e "\n@context HTTP state: ${response} (waiting for 200)"
		pause 3
		getHeartbeat "${CONTEXT}"
	done
}

waitForCoreContext
waitForMongo
waitForOrion

echo " "
echo "0_healthy_waiting.sh script finished..."
