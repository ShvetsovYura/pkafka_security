#!/usr/bin/env bash

set -e

KEYSTORE_FILENAME="kafka.keystore.jks"
KEYSTORE_DIR="keystore"

TRUSTSTORE_FILENAME="kafka.truststore.jks"
TRUSTSTORE_DIR="truststore"

VALIDITY_IN_DAYS=365

CA_CERT_FILE="ca-cert"
CA_KEY_FILE="ca-key"
SIGN_REQUEST="cert-request"
SIGN_REQUEST_SRL="ca-cert.srl"
CERT_SIGNED="cert-signed"


base_path=$1
ts_file="$TRUSTSTORE_DIR/$TRUSTSTORE_FILENAME"
ts_pkey_file="$TRUSTSTORE_DIR/$CA_KEY_FILE"

ks_file="$base_path/$KEYSTORE_DIR/$KEYSTORE_FILENAME"
ks_dir="$base_path/$KEYSTORE_DIR"

ca_cert="$base_path/$CA_CERT_FILE"
sign_req="$base_path/$SIGN_REQUEST"
sign_req_srl="$base_path/$SIGN_REQUEST_SRL"
cert_sig="$base_path/$CERT_SIGNED"

mkdir $base_path

function file_exists_and_exit() {
  echo "'$1' already exist. Move or delete it before"
  echo "re-running this script."
  exit 1
}

if [ -e "$ks_dir" ]; then
  file_exists_and_exit $KEYSTORE_DIR
fi



if [ -e "$SIGN_REQUEST" ]; then
  file_exists_and_exit $SIGN_REQUEST
fi

if [ -e "$SIGN_REQUEST_SRL" ]; then
  file_exists_and_exit $SIGN_REQUEST_SRL
fi

if [ -e "$CERT_SIGNED" ]; then
  file_exists_and_exit $CERT_SIGNED
fi




mkdir $ks_dir

echo
echo "Будет сгенерировано хранилище ключей. Каждому брокеру и логическому клиенту необходимо свое"
echo "хранилище ключей. Этот скрипт создаст только одно хранилище ключей. Запустите этот скрипт несколько"
echo "раз для создания нескольких хранилищ ключей."
echo
echo "Вам будет предложено ввести следующее:"
echo " - Пароль для хранилища ключей. Запомните его."
echo " - Личную информацию, такую как ваше имя."
echo "     ПРИМЕЧАНИЕ: в данный момент в Kafka общее имя (CN) не обязательно должно быть полным доменным именем"
echo "           этого хоста. Однако в будущем это может измениться. Поэтому сделайте CN"
echo "           полным доменным именем. Некоторые операционные системы называют запрос на CN 'имя / фамилия'"
echo " - Пароль для ключа, который будет сгенерирован в хранилище ключей. Запомните его."

# Чтобы узнать больше о CN и FQDN, прочитайте:
# https://docs.oracle.com/javase/7/docs/api/javax/net/ssl/X509ExtendedTrustManager.html

echo
echo "пароль keystore (NEW):"
keytool -keystore $ks_file -alias localhost -validity $VALIDITY_IN_DAYS -genkey -keyalg RSA

echo "'$ks_file' теперь содержит пару ключей и"
echo "самоподписанный сертификат. Это хранилище ключей может быть использовано только для одного брокера или"
echo "одного логического клиента. Другим брокерам или клиентам необходимо создать свои собственные хранилища ключей."

echo
echo "Извлечение сертификата из доверительного хранилища и сохранение в $ca_cert."
echo "пароль для доверительного хранилища (truststore)."

keytool -keystore $ts_file -export -alias CARoot -rfc -file $ca_cert

echo
echo "Теперь будет создан запрос на подпись сертификата для хранилища ключей."
echo "пароль для хранилища ключей (keystore заполненного раньше)."
keytool -keystore $ks_file -alias localhost -certreq -file $sign_req

echo
echo "Теперь приватный ключ доверительного хранилища (CA) подпишет сертификат хранилища ключей."
echo "пароль для приватного ключа truststore."
openssl x509 -req -CA $ca_cert -CAkey $ts_pkey_file -in $sign_req -out $cert_sig -days $VALIDITY_IN_DAYS -CAcreateserial

echo
echo "Теперь сертификат центра сертификации (CA) будет импортирован в хранилище ключей."
echo "пароль для хранилища ключей (keystore) и подтвердить, что вы хотите"
echo "импортировать сертификат."

keytool -keystore $ks_file -alias CARoot -import -file $ca_cert
rm $ca_cert # delete the trust store cert because it's stored in the trust store.

echo
echo "Теперь подписанный сертификат хранилища ключей будет импортирован обратно в хранилище ключей."
echo "пароль для хранилища ключей (keystore)."

keytool -keystore $ks_file -alias localhost -import -file $cert_sig

echo
echo "Все готово!"
echo
echo "Удалить промежуточные файлы? Они следующие:"
echo " - '$sign_req_srl': серийный номер CA"
echo " - '$sign_req': запрос на подпись сертификата хранилища ключей"
echo "   (который был выполнен)"
# echo " - '$CERT_SIGNED': сертификат хранилища ключей, подписанный CA, и сохраненный обратно"
# echo "    в хранилище ключей"
echo -n "Удалить? [yn] "
read delete_intermediate_files

if [ "$delete_intermediate_files" == "y" ]; then
  rm $sign_req_srl
  rm $sign_req
  # rm $CERT_SIGNED
fi