#!usr/bin/env sh

echo "-----:[   NGINX $(nginx -v 2>&1 | cut -d "/" -f2)   ]:-----"

mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/ssl

# set TZ
if [[ ! -z "${NGINX_LE_TZ}" ]]; then
    cp /usr/share/zoneinfo/${NGINX_LE_TZ} /etc/localtime
    echo ${NGINX_LE_TZ} >/etc/timezone
fi

if [ "$NGINX_LE_LETSENCRYPT" != "true" ]; then
    echo "[-] Letsencrypt disabled"
    # collect no-ssl services
    NO_SSL_SERVICES=$(find "/etc/nginx/" -type f -maxdepth 1 -name "no-ssl.service*.conf")

    # copy /etc/nginx/no-ssl.service*.conf if any of no-ssl.service*.conf mounted
    if [ ${#NO_SSL_SERVICES} -ne 0 ]; then
        cp -fv /etc/nginx/no-ssl.service*.conf /etc/nginx/conf.d/
    fi

    # replace the PLACEHOLDER_# in the *.conf file
    for i in $(seq 9); do
        placeholder="NGINX_LE_PLACEHOLDER_$i"
        eval "value=\$NGINX_LE_PLACEHOLDER_$i"
        sed -i "s|${placeholder}|${value}|g" /etc/nginx/conf.d/*.conf 2>/dev/null
    done

    # replace the redirect location in the default config file
    sed -i "s|https\:\/\/\$host\$request_uri|http\:\/\/\$host\$request_uri|g" /etc/nginx/nginx.conf 2>/dev/null

    echo "[*] Start nginx without ssl"

else
    echo "[*] Letsencrypt enabled"

    # setup ssl keys, export to pass them to le.sh
    echo "ssl_key=${NGINX_LE_SSL_KEY:=le-key.pem}, ssl_cert=${NGINX_LE_SSL_CERT:=le-crt.pem}, ssl_chain_cert=${NGINX_LE_SSL_CHAIN_CERT:=le-chain-crt.pem}"
    export LE_SSL_KEY=/etc/nginx/ssl/${NGINX_LE_SSL_KEY}
    export LE_SSL_CERT=/etc/nginx/ssl/${NGINX_LE_SSL_CERT}
    export LE_SSL_CHAIN_CERT=/etc/nginx/ssl/${NGINX_LE_SSL_CHAIN_CERT}

    # collect services
    SERVICE_FILES=$(find "/etc/nginx/" -type f -maxdepth 1 -name "service*.conf")

    # copy /etc/nginx/service*.conf if they are mounted
    if [ ${#SERVICE_FILES} -ne 0 ]; then
        cp -fv /etc/nginx/service*.conf /etc/nginx/conf.d/
    fi

    # replace NGINX_LE_SSL_KEY, NGINX_LE_SSL_CERT and NGINX_LE_SSL_CHAIN_CERT by actual keys
    sed -i "s|NGINX_LE_SSL_KEY|${LE_SSL_KEY}|g" /etc/nginx/conf.d/*.conf 2>/dev/null
    sed -i "s|NGINX_LE_SSL_CERT|${LE_SSL_CERT}|g" /etc/nginx/conf.d/*.conf 2>/dev/null
    sed -i "s|NGINX_LE_SSL_CHAIN_CERT|${LE_SSL_CHAIN_CERT}|g" /etc/nginx/conf.d/*.conf 2>/dev/null

    sed -i "s|NGINX_LE_SSL_KEY|${LE_SSL_KEY}|g" /etc/nginx/h5bp/ssl/*.conf 2>/dev/null
    sed -i "s|NGINX_LE_SSL_CERT|${LE_SSL_CERT}|g" /etc/nginx/h5bp/ssl/*.conf 2>/dev/null
    sed -i "s|NGINX_LE_SSL_CHAIN_CERT|${LE_SSL_CHAIN_CERT}|g" /etc/nginx/h5bp/ssl/*.conf 2>/dev/null

    # replace the NGINX_LE_PLACEHOLDER_# in the *.conf file
    for i in $(seq 9); do
        placeholder="NGINX_LE_PLACEHOLDER_$i"
        eval "value=\$NGINX_LE_PLACEHOLDER_$i"
        sed -i "s|${placeholder}|${value}|g" /etc/nginx/conf.d/*.conf 2>/dev/null
    done

    # replace NGINX_LE_FQDN
    domain_list=$(echo "${NGINX_LE_FQDN}" | tr "," " ")
    sed -i "s|NGINX_LE_FQDN|${domain_list}|g" /etc/nginx/conf.d/*.conf 2>/dev/null

    # CN Domain is the first domain in the domain list
    export LE_CN_DOMAIN=$(echo "${NGINX_LE_FQDN}" | cut -d "," -f 1)
    sed -i "s|NGINX_LE_CN_DOMAIN|${LE_CN_DOMAIN}|g" /etc/nginx/conf.d/*.conf 2>/dev/null

    # generate dhparams.pem
    if [ ! -f /etc/nginx/ssl/dhparams.pem ]; then
        echo "[*] Generate dhparams..."
        cd /etc/nginx/ssl
        openssl dhparam -out dhparams.pem 2048
        chmod 600 dhparams.pem
    fi

    # disable ssl configuration and let it run without SSL
    mv -v /etc/nginx/conf.d /etc/nginx/conf.d.disabled

    echo "[*] Start nginx"
    (
        sleep 5 # give nginx time to start
        echo "[*] Start letsencrypt updater"
        while :; do
            echo "[*] Trying to update letsencrypt ..."
            /le.sh
            rm -f /etc/nginx/conf.d/default.conf 2>/dev/null               #on the first run remove default config, conflicting on 80
            mv -v /etc/nginx/conf.d.disabled /etc/nginx/conf.d 2>/dev/null #on the first run enable config back
            echo "[*] Reload nginx with ssl"
            nginx -s reload
            sleep 10d
        done
    ) &

fi

nginx -g "daemon off;"
