COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/filixx/data
MARIADB_DIR = $(DATA_DIR)/mariadb
WORDPRESS_DIR = $(DATA_DIR)/wordpress

all: up

prepare:
	sudo mkdir -p $(MARIADB_DIR)
	sudo mkdir -p $(WORDPRESS_DIR)

up: prepare
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down -v
	sudo rm -rf $(MARIADB_DIR)
	sudo rm -rf $(WORDPRESS_DIR)

.PHONY: all prepare up down