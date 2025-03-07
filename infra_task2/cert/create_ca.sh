#!/usr/bin/env bash

set -e

KEYSTORE_FILENAME="kafka.keystore.jks"
VALIDITY_IN_DAYS=3650
DEFAULT_TRUSTSTORE_FILENAME="kafka.truststore.jks"
TRUSTSTORE_WORKING_DIRECTORY="truststore"
KEYSTORE_WORKING_DIRECTORY="keystore"
CA_CERT_FILE="ca-cert"
KEYSTORE_SIGN_REQUEST="cert-file"
KEYSTORE_SIGN_REQUEST_SRL="ca-cert.srl"
KEYSTORE_SIGNED_CERT="cert-signed"

function file_exists_and_exit() {
  echo "'$1' cannot exist. Move or delete it before"
  echo "re-running this script."
  exit 1
}

if [ -e "$KEYSTORE_WORKING_DIRECTORY" ]; then
  file_exists_and_exit $KEYSTORE_WORKING_DIRECTORY
fi

if [ -e "$CA_CERT_FILE" ]; then
  file_exists_and_exit $CA_CERT_FILE
fi

if [ -e "$KEYSTORE_SIGN_REQUEST" ]; then
  file_exists_and_exit $KEYSTORE_SIGN_REQUEST
fi

if [ -e "$KEYSTORE_SIGN_REQUEST_SRL" ]; then
  file_exists_and_exit $KEYSTORE_SIGN_REQUEST_SRL
fi

if [ -e "$KEYSTORE_SIGNED_CERT" ]; then
  file_exists_and_exit $KEYSTORE_SIGNED_CERT
fi

echo
echo "Добро пожаловать в скрипт генерации хранилища ключей и доверительного хранилища для Kafka."

echo
echo "Сначала, вам нужно сгенерировать доверительное хранилище и связанный с ним приватный ключ"
echo


trust_store_file=""
trust_store_private_key_file=""


mkdir $TRUSTSTORE_WORKING_DIRECTORY
echo
echo "Сначала создадим приватный ключ."
echo
echo "Вам будет предложено ввести:"
echo " - Пароль для приватного ключа. Запомните его."
echo " - Информацию о вас и вашей компании."
echo " - ОБРАТИТЕ ВНИМАНИЕ, что общее имя (CN) в данный момент не имеет значения."


openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
  -out $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE -days $VALIDITY_IN_DAYS

trust_store_private_key_file="$TRUSTSTORE_WORKING_DIRECTORY/ca-key"

echo
echo "Созданы два файла:"
echo " - $TRUSTSTORE_WORKING_DIRECTORY/ca-key -- приватный ключ, который будет использован позже для"
echo "   подписи сертификатов."
echo " - $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE -- сертификат, который будет"
echo "   сохранен в доверительном хранилище и будет служить сертификатом"
echo "   центра сертификации (CA). После того как этот сертификат будет сохранен в доверительном"
echo "   хранилище, он будет удален. Его можно будет извлечь из доверительного хранилища с помощью:"
echo "   $ keytool -keystore <trust-store-file> -export -alias CARoot -rfc"

echo
echo "Теперь доверительное хранилище будет сгенерировано на основе сертификата."
echo
echo "Вам будет предложено ввести:"
echo " - пароль для доверительного хранилища (обозначенный как 'truststore'). Запомните его."
echo " - подтверждение того, что вы хотите импортировать сертификат."


keytool -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME \
  -alias CARoot -import -file $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE

trust_store_file="$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME"

echo
echo "$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME было создано."

# сертификат не нужен, так как он уже находится в доверительном хранилище.
rm $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE

echo
echo "Готово:"
echo " - файл доверительного хранилища:        $trust_store_file"
echo " - приватный ключ доверительного хранилища: $trust_store_private_key_file"

