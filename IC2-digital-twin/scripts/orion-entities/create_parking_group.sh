#!/bin/bash
set -euo pipefail

# Create IC2 Parking Group  entities
#######IC2 Parking Group for staff members###########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingGroup:IC2-Staff",
    "type": "ParkingGroup",
    "description": {
        "type": "Property",
	"value": "Parking group reserved exclusively for IC staff members. Located near the IC2 Building, it provides free parking with no fee required. It contains 14 parking spots."
    },
    "availableSpotNumber": {
       "type": "Property",
       "value": 14
    },
    "category": {
       "type": "Property",
       "value": ["offStreet", "onlyStaff", "free"]
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
          "type": "MultiPolygon",
	  "coordinates": [
             [
                [
                   [-47.06421, -22.81493],
                   [-47.06417, -22.81490],
                   [-47.06424, -22.81475],
                   [-47.06427, -22.81476],
		   [-47.06421, -22.81493]
                ]
             ],
             [
                [
                   [-47.06436, -22.81484],
                   [-47.06431, -22.81496],
                   [-47.06427, -22.81494],
                   [-47.06432, -22.81483],
		   [-47.06436, -22.81484]
                ]
             ]
          ]
       }
    },
    "name": {
       "type": "Property",
       "value": "IC-2 Staff Parking Group"
    },
    "occupancyDetectionType": {
       "type": "Property",
       "value": [ "singleSpaceDetection" ]
    },
    "parkingMode": {
       "type": "Property",
       "value": ["perpendicularParking"]
    },
    "refParkingSite": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:OffStreetParking:IC2-OffStreetParking"
    },
    "totalSpotNumber": {
       "type": "Property",
       "value": 14
    }

}'


# Create IC2 Parking Group for only disabled staff members
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingGroup:IC2-Staff-DisabledOnly",
    "type": "ParkingGroup",
    "description": {
        "type": "Property",
	"value": "Parking group reserved exclusively for only disabled IC staff members. Located near the IC2 Building, it provides free parking with no fee required. It contains 2 parking spots."
    },
    "availableSpotNumber": {
       "type": "Property",
       "value": 0
    },
    "category": {
       "type": "Property",
       "value": ["offStreet", "onlyDisabled", "free"]
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
	  "coordinates": [
             [
                [-47.06439, -22.81476],
                [-47.06437, -22.81480],
                [-47.06434, -22.81479],
                [-47.06435, -22.81475],
		[-47.06439, -22.81476]
             ]
          ]
       }
    },
    "name": {
       "type": "Property",
       "value": "IC-2 only disabled Staff Parking Group"
    },
    "occupancyDetectionType": {
       "type": "Property",
       "value": [ "singleSpaceDetection" ]
    },
    "parkingMode": {
       "type": "Property",
       "value": ["perpendicularParking"]
    },
    "refParkingSite": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:OffStreetParking:IC2-OffStreetParking"
    },
    "totalSpotNumber": {
       "type": "Property",
       "value": 2
    }

}'
