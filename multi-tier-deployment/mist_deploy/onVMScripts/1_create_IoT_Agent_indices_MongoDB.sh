#!/bin/bash

# Script description

# IoT Agent indices in MongoDB.
# Before creating the entities of ParkingSensor related to the IoT Agent, you must create in MongoDB the
# indices, this is applicable if you are starting from scratch and they were not created before. This is
# done just once.
printf "Adding appropriate \033[1mMongoDB\033[0m indexes for \033[1;36mIoT-Agent\033[0m  ..."
docker exec db-mongo mongosh --eval '
conn = new Mongo();
db = conn.getDB("iotagentjson");
db.getCollectionNames().forEach(c=>db[c].drop());
db.createCollection("devices");
db.devices.createIndex({"_id.service": 1, "_id.id": 1, "_id.type": 1});
db.devices.createIndex({"_id.type": 1});
db.devices.createIndex({"_id.id": 1});
db.createCollection("groups");
db.groups.createIndex({"_id.resource": 1, "_id.apikey": 1, "_id.service": 1});
db.groups.createIndex({"_id.type": 1});' > /dev/null
echo -e " \033[1;32mdone\033[0m"

