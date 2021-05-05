# NGINX-LE - Nginx web and proxy with automatic let's encrypt 

[![Docker Automated build](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/0x8861/nginx-le/) 
[![Docker Image Version (latest by date)](https://img.shields.io/docker/v/0x8861/nginx-le?sort=date)](https://github.com/t-ho/nginx-le)

Simple nginx image (alpine based) with integrated [Let's Encrypt](https://letsencrypt.org) support.

Provide a collection of nginx configuration snippets from [h5bp/server-configs-nginx](https://github.com/h5bp/server-configs-nginx)

## How to use

- get [docker-compose.yml](https://github.com/t-ho/nginx-le/blob/master/docker-compose.yml) and change things:
  - set timezone to your local, for example `NGINX_LE_TZ=UTC`. For more timezone values check `/usr/share/zoneinfo` directory
  - set `NGINX_LE_LETSENCRYPT=true` if you want automatic certificate install and renewal
  - `NGINX_LE_EMAIL` should be your email and `LE_FQDN` for domain
  - for multiple FQDNs you can pass comma-separated list, like `NGINX_LE_FQDN=aaa.example.com,bbb.example.com`
  - alternatively set `NGINX_LE_LETSENCRYPT` to `false` and pass your own cert in `NGINX_LE_SSL_CERT`, key in `NGINX_LE_SSL_KEY` and `NGINX_LE_SSL_CHAIN_CERT`
  - use provided `templates/service-example.conf` and `templates/no-ssl.service-example.conf` to make your own `templates/service.conf` and `templates/no-ssl.service.conf`. Keep ssl directives as is:
    ```nginx
    ssl_certificate NGINX_LE_SSL_CERT;
    ssl_certificate_key NGINX_LE_SSL_KEY;
    ssl_trusted_certificate NGINX_LE_SSL_CHAIN_CERT;
    ```
- make sure `volumes` in docker-compose.yml changed to your service config
- you can map multiple custom config files in compose for any `service*.conf` and `no-ssl.service*.conf` (see [docker-compose.yml](https://github.com/t-ho/nginx-le/blob/master/docker-compose.yml) for `service2.conf`)
- pull image - `docker-compose pull`
- if you don't want pre-built image, make you own. `docker-compose build` will do it
- start it `docker-compose up`

## Some implementation details

**Important:** provided [nginx.conf](https://github.com/t-ho/nginx-le/blob/master/etc-nginx/nginx.conf) handles 
http->https redirect automatically, no need to add it into your custom `service.conf`. In case if you need a custom server on
http (:80) port, make sure you [handle](https://github.com/t-ho/nginx-le/blob/master/etc-nginx/nginx.conf#L62) `/.well-known/` 
path needed for LE challenge.  

- provided a collection of nginx configuration snippets that can help your server improve the website's performance and security. Thanks to [h5bp/server-configs-nginx](https://github.com/h5bp/server-configs-nginx)
- image uses alpine's `certbot` package.
- `script/entrypoint.sh` requests LE certificate and will refresh every 10 days in case if certificate is close to expiration (30day)
- `script/le.sh` gets SSL
- nginx-le on [docker-hub](https://hub.docker.com/r/0x8861/nginx-le/)
- **A+** overall rating on [ssllabs](https://www.ssllabs.com/ssltest/index.html)

![ssllabs](https://raw.githubusercontent.com/t-ho/nginx-le/master/rating.png)

## Alternatives

- [Træfik](https://traefik.io) HTTP reverse proxy and load balancer. Supports Let's Encrypt directly.
- [Caddy](https://caddyserver.com) supports Let's Encrypt directly.
- [leproxy](https://github.com/artyom/leproxy) small and nice (stand alone) https reverse proxy with automatic Letsencrypt
- [bunch of others](https://github.com/search?utf8=✓&q=nginx+lets+encrypt)

## Examples

- [Reverse proxy](https://github.com/t-ho/nginx-le/tree/master/example/webrtc) for WebRTC solutions, where you need multiple ports on one domain to reach different services behind your `nginx-le` container.
