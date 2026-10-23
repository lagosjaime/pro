COMPOSE := docker compose

.DEFAULT_GOAL := help

.PHONY: help up down restart build rebuild logs logs-mysql ps shell shell-root composer install update test db db-root redis sql sql-app sql-procedures assets pma clean

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

up: ## Levanta todos los contenedores
	$(COMPOSE) up -d --build

down: ## Detiene y elimina los contenedores
	$(COMPOSE) down

restart: ## Reinicia los contenedores
	$(COMPOSE) restart

build: ## Reconstruye la imagen de PHP
	$(COMPOSE) build app

rebuild: ## Reconstruye la imagen sin cache y levanta todo
	$(COMPOSE) build --no-cache app && $(COMPOSE) up -d

logs: ## Sigue los logs de todos los servicios
	$(COMPOSE) logs -f

logs-mysql: ## Sigue los logs de MySQL
	$(COMPOSE) logs -f mysql

ps: ## Estado de los contenedores
	$(COMPOSE) ps

shell: ## Shell en el contenedor de PHP (como tu usuario)
	$(COMPOSE) exec app sh

shell-root: ## Shell en el contenedor de PHP (como root)
	$(COMPOSE) exec -u root app sh

composer: ## Ejecuta composer en el contenedor: make composer install
	$(COMPOSE) exec app composer $(ARGS)

install: ## Instala dependencias de composer
	$(COMPOSE) exec app composer install $(ARGS)

update: ## Actualiza dependencias de composer
	$(COMPOSE) exec app composer update $(ARGS)

test: ## Ejecuta los tests
	$(COMPOSE) exec app composer test

db: ## Consola MySQL con el usuario de la app
	$(COMPOSE) exec mysql mysql -u pr -ppr pr_db

db-root: ## Consola MySQL como root
	$(COMPOSE) exec mysql mysql -uroot -proot

redis: ## Consola de Redis
	$(COMPOSE) exec redis sh -c 'redis-cli -a "$$REDIS_PASSWORD"'

sql: ## Aplica los esquemas heredados (excepto app_db*) en la base pr_db
	@for f in dev/sql/schemas/*.sql; do \
		case "$$f" in dev/sql/schemas/app_db*.sql) continue;; esac; \
		echo "-> $$f"; \
		$(COMPOSE) exec -T mysql mysql -upr -ppr pr_db < "$$f"; \
	done

sql-app: ## Aplica los esquemas de dev/sql/schemas en la base app_db
	@for f in dev/sql/schemas/app_db*.sql; do \
		echo "-> $$f"; \
		$(COMPOSE) exec -T mysql mysql -uroot -proot < "$$f"; \
	done

sql-procedures: ## Aplica los procedimientos de dev/sql/procedures/app_db en app_db
	@for d in dev/sql/procedures/app_db/*.sql; do \
		[ -e "$$d" ] || continue; \
		echo "-> $$d"; \
		$(COMPOSE) exec -T mysql mysql -uroot -proot app_db < "$$d"; \
	done

assets: ## Descarga/actualiza los assets de terceros (jquery, bootstrap, datatables)
	@bash dev/scripts/assets.sh

pma: ## Muestra las URLs del proyecto
	@echo "App:       http://localhost:$$(grep HTTP_PORT .env | cut -d= -f2)"
	@echo "phpMyAdmin: http://localhost:$$(grep PHPMYADMIN_PORT .env | cut -d= -f2)"

clean: ## Detiene todo y borra los datos de MySQL
	$(COMPOSE) down -v
	rm -rf docker/mysql-data/*
