#!/usr/bin/env bash
set -euo pipefail

# IoT Agent indices in MongoDB.
# Before creating the entities of ParkingSensor related to the IoT Agent, you must create in MongoDB the
# indices, this is applicable if you are starting from scratch and they were not created before. This is 
# done just once.
printf "Adding appropriate \033[1mMongoDB\033[0m indexes for \033[1;36mIoT-Agent\033[0m  ..."
docker exec db-mongo mongosh --eval '
conn = new Mongo();
db = conn.getDB("iotagentjson");

print("➡️  Dropping existing collections...");
db.getCollectionNames().forEach(c=>db[c].drop());

print("➡️  Creating devices collection and indexes...");
db.createCollection("devices");
db.devices.createIndex({"_id.service": 1, "_id.id": 1, "_id.type": 1});
db.devices.createIndex({"_id.type": 1});
db.devices.createIndex({"_id.id": 1});

print("➡️  Creating groups collection and indexes...");
db.createCollection("groups");
db.groups.createIndex({"_id.resource": 1, "_id.apikey": 1, "_id.service": 1});
db.groups.createIndex({"_id.type": 1});

print("✅ Index creation completed successfully.");
' > /dev/null
echo -e " \033[1;32mdone\033[0m"
