#!/usr/bin/env sh

# scripts is trying to renew certificate only if close (30 days) to expiration
# returns 0 only if certbot called.

target_cert=/etc/nginx/ssl/le-crt.pem
# 30 days
renew_before=2592000

if [ "$LETSENCRYPT" != "true" ]; then
    echo "[-] Letsencrypt disabled. To enable, set env LETSENCRYPT=true"
    return 1
fi

# redirection to /dev/null to remove "Certificate will not expire" output
if [ -f ${target_cert} ] && openssl x509 -checkend ${renew_before} -noout -in ${target_cert} > /dev/null ; then
    # egrep to remove leading whitespaces
    CERT_FQDNS=$(openssl x509 -in ${target_cert} -text -noout | egrep -o 'DNS.*')
    # run and catch exit code separately because couldn't embed $@ into `if` line properly
    set -- $(echo ${LE_FQDN} | tr ',' '\n'); for element in "$@"; do echo ${CERT_FQDNS} | grep -q $element ; done
    CHECK_RESULT=$?
    if [ ${CHECK_RESULT} -eq 0 ] ; then
        echo "[*] Letsencrypt certificate ${target_cert} still valid"
        return 1
    else
        echo "[*] Letsencrypt certificate ${target_cert} is present, but doesn't contain expected domains"
        echo "[*] Expected: ${LE_FQDN}"
        echo "[*] Found:    ${CERT_FQDNS}"
    fi
fi

echo "[*] Letsencrypt certificate will expire soon or missing, renewing..."
certbot certonly --agree-tos --non-interactive --force-renewal --email "${LE_EMAIL}" --webroot -w /usr/share/nginx/html -d ${LE_FQDN}
le_result=$?
if [ ${le_result} -ne 0 ]; then
    echo "[-] Failed to run certbot"
    return 1
fi

FIRST_FQDN=$(echo "$LE_FQDN" | cut -d"," -f1)
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/privkey.pem /etc/nginx/ssl/le-key.pem
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/fullchain.pem ${target_cert}
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/chain.pem /etc/nginx/ssl/le-chain-crt.pem
return 0