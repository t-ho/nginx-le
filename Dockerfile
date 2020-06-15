FROM nginx:stable-alpine

RUN mv /etc/nginx /etc/nginx-previous
COPY ./etc-nginx /etc/nginx/

COPY script/entrypoint.sh /entrypoint.sh
COPY script/le.sh /le.sh

RUN \
 rm /etc/nginx/conf.d/default.conf && \
 chmod +x /entrypoint.sh && \
 chmod +x /le.sh && \
 apk add --update certbot tzdata openssl && \
 rm -rf /var/cache/apk/*

CMD ["/entrypoint.sh"]
