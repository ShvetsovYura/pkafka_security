#!/bin/sh

KT="/opt/bitnami/kafka/bin/kafka-topics.sh"
KT1="/opt/bitnami/kafka/bin/kafka-acls.sh"

echo "--------------------------------Waiting for kafka..."-------------------------------
"$KT" --bootstrap-server kb1.loc:9092 --list --command-config /tmp/ac.conf

echo "--------------------------------Creating kafka topics-------------------------------"
"$KT" --bootstrap-server kb1.loc:9092 --create --if-not-exists --topic topic-1 --replication-factor 2 --partitions 3 --command-config /tmp/ac.conf
"$KT" --bootstrap-server kb1.loc:9092 --create --if-not-exists --topic topic-2 --replication-factor 2 --partitions 3 --command-config /tmp/ac.conf

echo "----------------------Successfully created the following topics:--------------------"
"$KT" --bootstrap-server kb1.loc:9092 --list --command-config /tmp/ac.conf

echo "-----------------------------Creating kafka topics permission-----------------------"
sleep 3 && echo "runngin ------->"
"$KT1" --bootstrap-server kb1.loc:9092 --add --allow-principal User:user --group sec_group --operation read --operation describe --topic topic-1 --command-config /tmp/ac.conf
"$KT1" --bootstrap-server kb1.loc:9092 --add --allow-principal User:user --operation write --topic topic-1 --command-config /tmp/ac.conf
"$KT1" --bootstrap-server kb1.loc:9092 --add --allow-principal User:user --operation write --topic topic-2 --command-config /tmp/ac.conf
