Создание файла adminclient-configs.conf

echo 'security.protocol=SASL_SSL' > /tmp/adminclient-configs.conf
echo 'sasl.mechanism=PLAIN' >> /tmp/adminclient-configs.conf
echo 'sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="controller_user" password="bitnami";' >> /tmp/adminclient-configs.conf
echo '# Path to the keystore (if client authentication is required)' >> /tmp/adminclient-configs.conf
echo 'ssl.keystore.location=/opt/bitnami/kafka/config/certs/kafka.keystore.jks' >> /tmp/adminclient-configs.conf
echo 'ssl.keystore.password=111111' >> /tmp/adminclient-configs.conf
echo 'ssl.key.password=111111' >> /tmp/adminclient-configs.conf
echo '# Path to the truststore' >> /tmp/adminclient-configs.conf
echo 'ssl.truststore.location=/opt/bitnami/kafka/config/certs/kafka.truststore.jks' >> /tmp/adminclient-configs.conf
echo 'ssl.truststore.password=111111' >> /tmp/adminclient-configs.conf
echo 'ssl.endpoint.identification.algorithm=' >> /tmp/adminclient-configs.conf
