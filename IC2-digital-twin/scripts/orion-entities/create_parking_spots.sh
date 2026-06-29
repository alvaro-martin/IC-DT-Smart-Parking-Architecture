#!/bin/bash
set -euo pipefail

# Create IC2 Parking Spots entities
##### Parking Spot 0 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-000",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
	"value": "Parking spot 0 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
	  "coordinates": [-47.06425, -22.81477]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'


##### Parking Spot 1 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-001",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 1 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06424, -22.81479]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'


##### Parking Spot 2 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-002",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 2 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06423, -22.81480]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'

##### Parking Spot 3 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-003",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 3 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06422, -22.81482]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'



##### Parking Spot 4 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-004",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 4 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06422, -22.81484]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'


##### Parking Spot 5 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-005",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 5 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06421, -22.81486]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'


##### Parking Spot 6 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-006",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 6 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06420, -22.81488]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'



##### Parking Spot 7 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-007",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 7 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06419, -22.81490]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'


##### Parking Spot 8 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-008",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 8 located near the entrance of the IC2 Building, reserved only for vehicles of staff with disabilities."
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
          "type": "Point",
          "coordinates": [-47.06436, -22.81476]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff-DisabledOnly"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'


##### Parking Spot 9 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-009",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 9 located near the entrance of the IC2 Building, reserved only for vehicles of staff with disabilities."
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
          "type": "Point",
          "coordinates": [-47.06436, -22.81478]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff-DisabledOnly"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'



##### Parking Spot 10 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-010",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 10 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06433, -22.81484]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'



##### Parking Spot 11 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-011",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 11 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06432, -22.81485]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'



##### Parking Spot 12 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-012",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 12 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06432, -22.81487]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'



##### Parking Spot 13 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-013",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 13 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06431, -22.81489]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'



##### Parking Spot 14 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-014",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 14 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06430, -22.81491]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'



##### Parking Spot 15 ########
curl -iX POST 'http://localhost:1026/ngsi-ld/v1/entities/' \
-H 'Content-Type: application/json' \
-H 'Link: <http://context/datamodels.context-ngsi.jsonld>;  rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
-d '{
    "id": "urn:ngsi-ld:ParkingSpot:IC2-015",
    "type": "ParkingSpot",
    "category": {
        "type": "Property",
        "value": ["offStreet"]
     },
    "description": {
        "type": "Property",
        "value": "Parking spot 15 located near the entrance of the IC2 Building, reserved for staff vehicles."
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
          "type": "Point",
          "coordinates": [-47.06429, -22.81494]
       }
    },
    "refParkingGroup": {
       "type": "Relationship",
       "object": "urn:ngsi-ld:ParkingGroup:IC2-Staff"
    },
    "status": {
       "type": "Property",
       "value": "free"
    }
}'
