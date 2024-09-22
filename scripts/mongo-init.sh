#!/bin/bash

###
# Инициализируем бд
###

# configSrv
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
EOF

## shards
docker compose exec -T mongodb-shard1-master mongosh --port 27017 --quiet <<EOF
rs.initiate(
    {
      _id : "rs-shard1",
      members: [
        { _id : 0, host : "mongodb-shard1-master:27017" },
        { _id : 1, host : "mongodb-shard1-replica1:27018" },
        { _id : 2, host : "mongodb-shard1-replica2:27019" },
      ]
    }
);
EOF
docker compose exec -T mongodb-shard2-master mongosh --port 27017 --quiet <<EOF
rs.initiate(
    {
      _id : "rs-shard2",
      members: [
        { _id : 0, host : "mongodb-shard2-master:27017" },
        { _id : 1, host : "mongodb-shard2-replica1:27018" },
        { _id : 2, host : "mongodb-shard2-replica2:27019" },
      ]
    }
);
EOF

# router
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("rs-shard1/mongodb-shard1-master:27017")
sh.addShard("rs-shard2/mongodb-shard2-master:27017")
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
EOF

# Наполнение данными
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

# отображение количества данных во втором шарде
docker compose exec -T mongodb-shard2-master mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# отображение количества данных в второй реплике первого шарда
docker compose exec -T mongodb-shard1-replica2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
