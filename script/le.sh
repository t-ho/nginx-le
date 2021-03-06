#!/usr/bin/env sh

# scripts is trying to renew certificate only if close (30 days) to expiration
# returns 0 only if certbot called.

# 30 days
renew_before=2592000

if [ "$NGINX_LE_LETSENCRYPT" != "true" ]; then
    echo "[-] Letsencrypt disabled. To enable, set env NGINX_LE_LETSENCRYPT=true"
    return 1
fi

# redirection to /dev/null to remove "Certificate will not expire" output
if [ -f ${LE_SSL_CERT} ] && openssl x509 -checkend ${renew_before} -noout -in ${LE_SSL_CERT} >/dev/null; then
    # egrep to remove leading whitespaces
    CERT_FQDNS=$(openssl x509 -in ${LE_SSL_CERT} -text -noout | egrep -o 'DNS.*')
    # run and catch exit code separately because couldn't embed $@ into `if` line properly
    set -- $(echo ${NGINX_LE_FQDN} | tr ',' '\n')
    for element in "$@"; do echo ${CERT_FQDNS} | grep -q $element; done
    CHECK_RESULT=$?
    if [ ${CHECK_RESULT} -eq 0 ]; then
        echo "[*] Letsencrypt certificate ${LE_SSL_CERT} still valid"
        return 1
    fi
    echo "[*] Letsencrypt certificate ${LE_SSL_CERT} is present, but doesn't contain expected domains"
    echo "[*] Expected: ${NGINX_LE_FQDN}"
    echo "[*] Found:    ${CERT_FQDNS}"
fi

echo "[*] Letsencrypt certificate will expire soon or missing, renewing..."
certbot certonly --agree-tos --non-interactive --force-renewal --email "${NGINX_LE_EMAIL}" --webroot -w /usr/share/nginx/html -d ${NGINX_LE_FQDN}
le_result=$?
if [ ${le_result} -ne 0 ]; then
    echo "[-] Failed to run certbot"
    return 1
fi

cp -fv /etc/letsencrypt/live/${LE_CN_DOMAIN}/privkey.pem ${LE_SSL_KEY}
cp -fv /etc/letsencrypt/live/${LE_CN_DOMAIN}/fullchain.pem ${LE_SSL_CERT}
cp -fv /etc/letsencrypt/live/${LE_CN_DOMAIN}/chain.pem ${LE_SSL_CHAIN_CERT}
return 0
