FROM debian:stretch-slim

MAINTAINER wilkesystems <maintainer@wilke.systems>

ENV BITBUCKET_VERSION=5.13.1
ENV BITBUCKET_HOME=/var/atlassian/application-data/bitbucket
ENV BITBUCKET_INSTALL_DIR=/opt/atlassian/bitbucket
ARG BITBUCKET_BINARY=https://www.atlassian.com/software/stash/downloads/binary/atlassian-bitbucket-${BITBUCKET_VERSION}-x64.bin

ENV MYSQL_CONNECTOR_JAVA_VERSION 5.1.47
ARG MYSQL_CONNECTOR_JAVA=https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_CONNECTOR_JAVA_VERSION}.tar.gz

RUN apt-get update; \
apt-get install -y ca-certificates curl git locales locales-all openssl perl procps ttf-dejavu wget; \
bash -c 'mkdir -m 755 -p /usr/share/atlassian/bitbucket/{driver,install}'; \
curl -sSL ${BITBUCKET_BINARY} -o /usr/share/atlassian/bitbucket/install/atlassian-bitbucket-${BITBUCKET_VERSION}-x64.bin; \
chmod +x /usr/share/atlassian/bitbucket/install/atlassian-bitbucket-${BITBUCKET_VERSION}-x64.bin; \
curl -sSL ${MYSQL_CONNECTOR_JAVA} | tar xz --directory "/usr/share/atlassian/bitbucket/driver/" --strip-components=1 --no-same-owner \
"mysql-connector-java-${MYSQL_CONNECTOR_JAVA_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_JAVA_VERSION}-bin.jar"; \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

COPY docker-entrypoint.sh /usr/sbin/docker-entrypoint.sh

EXPOSE 7990 7999

WORKDIR ${BITBUCKET_HOME}

CMD ["${BITBUCKET_INSTALL_DIR}/bin/start-bitbucket.sh", "-fg"]

ENTRYPOINT ["docker-entrypoint.sh"]
