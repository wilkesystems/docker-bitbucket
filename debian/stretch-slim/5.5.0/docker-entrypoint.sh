#!/bin/bash
set -euo pipefail

function main {
    # Set Bitbucket user and group
    : ${BITBUCKET_USER:=atlbitbucket}
    : ${BITBUCKET_GROUP:=atlbitbucket}

    # Set Bitbucket uid and gid
    : ${BITBUCKET_UID:=999}
    : ${BITBUCKET_GID:=999}

    # Set Bitbucket http port
    : ${BITBUCKET_HTTP_PORT:=7790}

    # Set Bitbucket language
    : ${BITBUCKET_LANGUAGE:=en}

    # Set Bitbucket context path
    : ${BITBUCKET_CONTEXT_PATH:=}

    # Setup Bitbucket SSL Opts
    : ${BITBUCKET_SSL_CACERTIFICATE:=}
    : ${BITBUCKET_SSL_CERTIFICATE:=}
    : ${BITBUCKET_SSL_CERTIFICATE_KEY:=}

    # Installed Bitbucket if it is not installed
    if [ ! -d ${BITBUCKET_INSTALL_DIR}/.install4j ] || [ ! -f ${BITBUCKET_HOME}/.version ]; then
        if [ -f ${BITBUCKET_HOME}/.version ]; then
            if [ "$BITBUCKET_VERSION" != "$(sed -n -e '0,/stash.home.build.version/{s/.*= *//p}' ${BITBUCKET_HOME}/.version)" ]; then
                : ${BITBUCKET_INSTALL_TYPE:=UPGRADE}
                adduser --disabled-login --disabled-password --home ${BITBUCKET_HOME} --gecos 'Atlassian Bitbucket' --no-create-home --quiet ${BITBUCKET_USER}
            fi
        fi
        # Set Bitbucket installation type
        : ${BITBUCKET_INSTALL_TYPE:=INSTALL}

        # Create the response file for Bitbucket
        echo "# install4j response file for Bitbucket ${BITBUCKET_VERSION}" > /usr/share/atlassian/bitbucket/install/response.varfile
        echo "app.bitbucketHome=${BITBUCKET_HOME}" >> /usr/share/atlassian/bitbucket/install/response.varfile
        echo "app.defaultInstallDir=${BITBUCKET_INSTALL_DIR}" >> /usr/share/atlassian/bitbucket/install/response.varfile

        if [ "BITBUCKET_INSTALL_TYPE" = "INSTALL" ]; then
            echo "app.install.service\$Boolean=false" >> /usr/share/atlassian/bitbucket/install/response.varfile
            echo "httpPort=${BITBUCKET_HTTP_PORT}" >> /usr/share/atlassian/bitbucket/install/response.varfile
        else
            echo "confirm.disable.plugins\$Boolean=true" >> /usr/share/atlassian/bitbucket/install/response.varfile
        fi

        echo "installation.type=${BITBUCKET_INSTALL_TYPE}" >> /usr/share/atlassian/bitbucket/install/response.varfile
        echo "launch.application\$Boolean=false" >> /usr/share/atlassian/bitbucket/install/response.varfile
        echo "sys.adminRights\$Boolean=true" >> /usr/share/atlassian/bitbucket/install/response.varfile
        echo "sys.languageId=${BITBUCKET_LANGUAGE}" >> /usr/share/atlassian/bitbucket/install/response.varfile

        # Start Bitbucket installer
        /usr/share/atlassian/bitbucket/install/atlassian-bitbucket-${BITBUCKET_VERSION}-x64.bin -q -varfile /usr/share/atlassian/bitbucket/install/response.varfile

        # Copy the Java Mysql connector
        cp -pr /usr/share/atlassian/bitbucket/driver/mysql-connector-java-5.1.44-bin.jar ${BITBUCKET_INSTALL_DIR}/app/WEB-INF/lib

        # Change ownership of the Java Mysql connector
        chown ${BITBUCKET_USER}:${BITBUCKET_GROUP} ${BITBUCKET_INSTALL_DIR}/app/WEB-INF/lib/mysql-connector-java-5.1.44-bin.jar

        # Change usermod
        usermod -d ${BITBUCKET_HOME} -u ${BITBUCKET_UID} ${BITBUCKET_USER}

        # Change groupmod
        groupmod -g ${BITBUCKET_GID} ${BITBUCKET_GROUP}

        # Change ownership of Bitbucket files 
        chown -R ${BITBUCKET_USER}:${BITBUCKET_GROUP} ${BITBUCKET_HOME} ${BITBUCKET_INSTALL_DIR}

        # SSL configuration
        if [ -f ${BITBUCKET_INSTALL_DIR}/jre/bin/keytool -a -n "${BITBUCKET_SSL_CERTIFICATE}" -a -n "${BITBUCKET_SSL_CERTIFICATE_KEY}" ]; then
            # Add cacerts
            if [ -n "${BITBUCKET_SSL_CACERTIFICATE}" ]; then
                if [ -f ${BITBUCKET_SSL_CACERTIFICATE} ]; then
                    ${BITBUCKET_INSTALL_DIR}/jre/bin/keytool \
                        -importcert \
                        -noprompt \
                        -alias tomcat \
                        -file ${BITBUCKET_SSL_CACERTIFICATE} \
                        -keystore ${BITBUCKET_INSTALL_DIR}/jre/lib/security/cacerts \
                        -storepass changeit \
                        -keypass changeit
                fi
            fi
        fi

        # Set context path
        if [ -z "$(sed -n -e 's/server.context-path= *//p' ${BITBUCKET_HOME}/shared/bitbucket.properties)" ]; then
            echo "server.context-path=${BITBUCKET_CONTEXT_PATH////\\/}" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
        fi
    fi

    # Keystore configuration
    if [ -f ${BITBUCKET_INSTALL_DIR}/jre/bin/keytool -a -n "${BITBUCKET_SSL_CERTIFICATE}" -a -n "${BITBUCKET_SSL_CERTIFICATE_KEY}" ]; then
        if [ -f ${BITBUCKET_HOME}/.keystore ]; then
            rm -f ${BITBUCKET_HOME}/.keystore
        fi

        # Create Keystore
        ${BITBUCKET_INSTALL_DIR}/jre/bin/keytool \
            -genkey \
            -noprompt \
            -alias tomcat \
            -dname "CN=localhost, OU=Bitbucket, O=Atlassian, L=Sydney, C=AU" \
            -keystore ${BITBUCKET_HOME}/.keystore \
            -storepass changeit \
            -keypass changeit

        # Remove alias
        ${BITBUCKET_INSTALL_DIR}/jre/bin/keytool \
            -delete \
            -noprompt \
            -alias tomcat \
            -keystore ${BITBUCKET_HOME}/.keystore \
            -storepass changeit \
            -keypass changeit

        if [ -f ${BITBUCKET_SSL_CERTIFICATE} -a -f ${BITBUCKET_SSL_CERTIFICATE_KEY} ]; then
            # Set Bitbucket https port
            : ${BITBUCKET_HTTPS_PORT:=8443}

            # Change server configuration
            if [ -f ${BITBUCKET_HOME}/shared/bitbucket.properties ]; then
                if [ -z "$(sed -n -e 's/server.port= *//p' ${BITBUCKET_HOME}/shared/bitbucket.properties)" ]; then
                    echo "server.port=${BITBUCKET_HTTPS_PORT}" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
                fi
                if [ -z "$(sed -n -e 's/server.ssl.enabled= *//p' ${BITBUCKET_HOME}/shared/bitbucket.properties)" ]; then
                    echo "server.ssl.enabled=true" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
                fi
                if [ -z "$(sed -n -e 's/server.ssl.key-store= *//p' ${BITBUCKET_HOME}/shared/bitbucket.properties)" ]; then
                    echo "server.ssl.key-store=${BITBUCKET_HOME}/.keystore" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
                fi
                if [ -z "$(sed -n -e 's/server.ssl.key-store-password= *//p' ${BITBUCKET_HOME}/shared/bitbucket.properties)" ]; then
                    echo "server.ssl.key-store-password=changeit" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
                fi
                if [ -z "$(sed -n -e 's/server.ssl.key-password= *//p' ${BITBUCKET_HOME}/shared/bitbucket.properties)" ]; then
                    echo "server.ssl.key-password=changeit" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
                fi
            else
                echo "server.port=${BITBUCKET_HTTPS_PORT}" > ${BITBUCKET_HOME}/shared/bitbucket.properties
                echo "server.ssl.enabled=true" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
                echo "server.ssl.key-store=${BITBUCKET_HOME}/.keystore" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
                echo "server.ssl.key-store-password=changeit" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
                echo "server.ssl.key-password=changeit" >> ${BITBUCKET_HOME}/shared/bitbucket.properties
            fi

            # Create PKCS12 Keystore
            openssl pkcs12 \
                -export \
                -in ${BITBUCKET_SSL_CERTIFICATE} \
                -inkey ${BITBUCKET_SSL_CERTIFICATE_KEY} \
                -out ${BITBUCKET_HOME}/.keystore.p12 \
                -name tomcat \
                -passout pass:changeit

            # Import PKCS12 keystore
            ${BITBUCKET_INSTALL_DIR}/jre/bin/keytool \
                -importkeystore \
                -deststorepass changeit \
                -destkeypass changeit \
                -destkeystore ${BITBUCKET_HOME}/.keystore \
                -srckeystore ${BITBUCKET_HOME}/.keystore.p12 \
                -srcstoretype PKCS12 \
                -srcstorepass changeit

            # Remove PKCS12 Keystore
            rm -f ${BITBUCKET_HOME}/.keystore.p12
        fi

        # Set keystore file permissions
        chown ${BITBUCKET_USER}:${BITBUCKET_GROUP} ${BITBUCKET_HOME}/.keystore
        chmod 640 ${BITBUCKET_HOME}/.keystore
    fi

    # Set recommended umask of "u=,g=w,o=rwx" (0027)
    umask 0027

    # Setup Catalina Opts
    : ${CATALINA_CONNECTOR_PROXYNAME:=}
    : ${CATALINA_CONNECTOR_PROXYPORT:=}
    : ${CATALINA_CONNECTOR_SCHEME:=http}
    : ${CATALINA_CONNECTOR_SECURE:=false}

    : ${CATALINA_OPTS:=}

    : ${JAVA_OPTS:=}

    : ${ELASTICSEARCH_ENABLED:=true}
    : ${APPLICATION_MODE:=}

    CATALINA_OPTS="${CATALINA_OPTS} -DcatalinaConnectorProxyName=${CATALINA_CONNECTOR_PROXYNAME}"
    CATALINA_OPTS="${CATALINA_OPTS} -DcatalinaConnectorProxyPort=${CATALINA_CONNECTOR_PROXYPORT}"
    CATALINA_OPTS="${CATALINA_OPTS} -DcatalinaConnectorScheme=${CATALINA_CONNECTOR_SCHEME}"
    CATALINA_OPTS="${CATALINA_OPTS} -DcatalinaConnectorSecure=${CATALINA_CONNECTOR_SECURE}"

    JAVA_OPTS="${JAVA_OPTS} ${CATALINA_OPTS}"

    ARGS="-fg"

    # Start Bitbucket without Elasticsearch
    if [ "${ELASTICSEARCH_ENABLED}" == "false" ] || [ "${APPLICATION_MODE}" == "mirror" ]; then
        ARGS="--no-search ${ARGS}"
    fi

    # Start Bitbucket as the correct user.
    if [ "${UID}" -eq 0 ]; then
        echo "User is currently root. Will change directory ownership to ${BITBUCKET_USER}:${BITBUCKET_GROUP}, then downgrade permission to ${BITBUCKET_USER}"
        PERMISSIONS_SIGNATURE=$(stat -c "%u:%U:%a" "${BITBUCKET_HOME}")
        EXPECTED_PERMISSIONS=$(id -u ${BITBUCKET_USER}):${BITBUCKET_USER}:700
        if [ "${PERMISSIONS_SIGNATURE}" != "${EXPECTED_PERMISSIONS}" ]; then
            echo "Updating permissions for BITBUCKET_HOME"
            mkdir -p "${BITBUCKET_HOME}/lib" &&
            chmod -R 700 "${BITBUCKET_HOME}" &&
            chown -R "${BITBUCKET_USER}:${BITBUCKET_GROUP}" "${BITBUCKET_HOME}"
        fi
        # Now drop privileges
        exec su -s /bin/bash ${BITBUCKET_USER} -c "${BITBUCKET_INSTALL_DIR}/bin/start-bitbucket.sh ${ARGS}"
    else
        exec "${BITBUCKET_INSTALL_DIR}/bin/start-bitbucket.sh ${ARGS}"
    fi
}

main "$@"

exit