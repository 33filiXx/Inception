
FROM debian:bookworm

RUN apt update -y && apt upgrade -y && \
    apt install -y curl php php-fpm php-mysql mariadb-client && \
    apt clean && rm -rf /var/lib/apt/lists/*

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tls/wordpress.sh /usr/local/bin/wordpress.sh
RUN chmod +x /usr/local/bin/wordpress.sh

CMD ["/usr/local/bin/wordpress.sh"]