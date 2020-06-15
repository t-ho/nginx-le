#!usr/bin/env sh

echo "-----:[   NGINX $(nginx -v 2>&1 | cut -d "/" -f2)   ]:-----"

mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/ssl

# set TZ
cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
echo ${TZ} > /etc/timezone

if [ "$LETSENCRYPT" != "true" ]; then
    echo "[-] Letsencrypt disabled"
    # collect no-ssl services
    NO_SSL_SERVICES=$(find "/etc/nginx/" -type f -maxdepth 1 -name "no-ssl.service*.conf")

    # copy /etc/nginx/no-ssl.service*.conf if any of no-ssl.service*.conf mounted
    if [ ${#NO_SSL_SERVICES} -ne 0 ]; then
        cp -fv /etc/nginx/no-ssl.service*.conf /etc/nginx/conf.d/
    fi

    # replace the PLACEHOLDER_# in the *.conf file
    for i in `seq 9`; do
        placeholder="PLACEHOLDER_$i"
        eval "value=\$PLACEHOLDER_$i"
        sed -i "s|${placeholder}|${value}|g" /etc/nginx/conf.d/*.conf
    done

    # replace the redirect location in the default config file
    sed -i "s|https\:\/\/\$host\$request_uri|http\:\/\/\$host\$request_uri|g" /etc/nginx/nginx.conf

    echo "[*] Start nginx without ssl"

else
    echo "[*] Letsencrypt enabled"

    # setup ssl keys
    echo "ssl_key=${SSL_KEY:=le-key.pem}, ssl_cert=${SSL_CERT:=le-crt.pem}, ssl_chain_cert=${SSL_CHAIN_CERT:=le-chain-crt.pem}"
    SSL_KEY=/etc/nginx/ssl/${SSL_KEY}
    SSL_CERT=/etc/nginx/ssl/${SSL_CERT}
    SSL_CHAIN_CERT=/etc/nginx/ssl/${SSL_CHAIN_CERT}

    # collect services
    SERVICES=$(find "/etc/nginx/" -type f -maxdepth 1 -name "service*.conf")

    # copy /etc/nginx/service*.conf if any of service*.conf mounted
    if [ ${#SERVICES} -ne 0 ]; then
        cp -fv /etc/nginx/service*.conf /etc/nginx/conf.d/
    fi

    # replace SSL_KEY, SSL_CERT and SSL_CHAIN_CERT by actual keys
    sed -i "s|SSL_KEY|${SSL_KEY}|g" /etc/nginx/conf.d/*.conf
    sed -i "s|SSL_CERT|${SSL_CERT}|g" /etc/nginx/conf.d/*.conf
    sed -i "s|SSL_CHAIN_CERT|${SSL_CHAIN_CERT}|g" /etc/nginx/conf.d/*.conf

    # replace the PLACEHOLDER_# in the *.conf file
    for i in `seq 9`; do
        placeholder="PLACEHOLDER_$i"
        eval "value=\$PLACEHOLDER_$i"
        sed -i "s|${placeholder}|${value}|g" /etc/nginx/conf.d/*.conf
    done

    # replace LE_FQDN
    domain_list=$(echo "${LE_FQDN}" | tr "," " ")
    sed -i "s|LE_FQDN|${domain_list}|g" /etc/nginx/conf.d/*.conf

    # CN Domain is the first domain in the domain list
    CN_DOMAIN=$(echo "${LE_FQDN}" | cut -d "," -f 1)
    sed -i "s|CN_DOMAIN|${CN_DOMAIN}|g" /etc/nginx/conf.d/*.conf

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
    while :
    do
        echo "[*] Trying to update letsencrypt ..."
        /le.sh
        rm -f /etc/nginx/conf.d/default.conf 2>/dev/null #on the first run remove default config, conflicting on 80
        mv -v /etc/nginx/conf.d.disabled /etc/nginx/conf.d 2>/dev/null #on the first run enable config back
        echo "[*] Reload nginx with ssl"
        nginx -s reload
        sleep 10d
    done
    ) &

fi

nginx -g "daemon off;"
