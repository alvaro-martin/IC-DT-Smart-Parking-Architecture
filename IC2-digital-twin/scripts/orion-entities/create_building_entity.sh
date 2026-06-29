#!/bin/bash
set -euo pipefail

# Create IC2 Building entity
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:Building:IC2",
    "type": "Building",
    "category": {
        "type": "Property",
        "value": ["university"]
     },
    "description": {
        "type": "Property",
	"value": "IC-2 is one of the main buildings of the Institute of Computing (IC) at the University of Campinas (Unicamp), located at Av. Albert Einstein, 1251, within the Campinas campus. Together with IC-1, it hosts offices for faculty and staff, a 60-seat auditorium, research laboratories, rooms for PhD and postdoctoral researchers, and the secretariats of undergraduate, graduate, extension, and research support activities."
    },
    "address": {
        "type": "Property",
        "value": {
	   "addressCountry": "Brazil",
	   "addressLocality": "Campinas",
	   "addressRegion": "São Paulo",
	   "district": "Barão Geraldo",
	   "postOfficeBoxNumber": "13083",
	   "postalCode": "13083-852",
	   "streetAddress": "Avenida Albert Einstein",
	   "streetNr": "1251"
         }
    },
    "location": {
       "type": "GeoProperty",
       "value": {
          "type": "Polygon",
	  "coordinates": [[
	     [-47.065108, -22.815020],
	     [-47.06452, -22.81457],
	     [-47.06436, -22.81493],
	     [-47.06505,-22.81517],
	     [-47.065108, -22.815020]
	  ]]
       }
    },
    "mapUrl": {
       "type": "Property",
       "value": "https://maps.app.goo.gl/PDJ75quJoUGZj2k36"
    },
    "name": {
       "type": "Property",
       "value": "IC-2 Building"
    }

}'

# Verify if it was created
curl -X GET 'http://localhost:1026/ngsi-ld/v1/entities/urn:ngsi-ld:Building:IC2' \
-H 'Accept: application/ld+json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"'
