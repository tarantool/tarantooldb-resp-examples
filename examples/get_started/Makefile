SHELL := /bin/bash

ifneq ($(shell command -v docker-compose version),)
    DOCKER_COMPOSE = docker-compose
endif

ifneq ($(shell docker compose version 2>/dev/null),)
    DOCKER_COMPOSE = docker compose
endif

ifndef DOCKER_COMPOSE
    $(error "Не найден docker-compose или docker compose")
endif

.PHONY: start stop

start:
	$(DOCKER_COMPOSE) up -d --build
	./wait.sh
	@echo ""
	@echo "Cluster is up. Check it:"
	@echo "  redis-cli -p 46379 ping"
	@echo "  redis-cli -p 36379 sentinel master storages001"

stop:
	$(DOCKER_COMPOSE) down -v
