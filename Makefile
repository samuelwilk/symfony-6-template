# Executables (local)
DOCKER = docker
DOCKER_COMP = docker compose

# Docker containers
PHP_CONT = $(DOCKER_COMP) exec php

# Executables
PHP      = $(PHP_CONT) php
COMPOSER = $(PHP_CONT) composer
SYMFONY  = $(PHP) bin/console

# Misc
.DEFAULT_GOAL = help
.PHONY        : help build up start down logs sh composer vendor sf cc test trust-tls cs-fix

## See https://www.strangebuzz.com/en/snippets/the-perfect-makefile-for-symfony for more commands

## —— 🎵 🐳 The Symfony Docker Makefile 🐳 🎵 ——————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9\./_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## —— Docker 🐳 ————————————————————————————————————————————————————————————————
build: ## Builds the Docker images
	@$(DOCKER_COMP) build --pull --no-cache

up: ## Start the docker hub in detached mode (no logs)
	@$(DOCKER_COMP) up --detach

start: build up ## Build and start the containers

down: ## Stop the docker hub
	@$(DOCKER_COMP) down --remove-orphans

rebuild:  ## Rebuild the Docker images
	@$(DOCKER_COMP) down --remove-orphans && $(DOCKER_COMP) build --pull --no-cache && $(DOCKER_COMP) up --detach

logs: ## Show live logs
	@$(DOCKER_COMP) logs --tail=0 --follow

sh: ## Connect to the FrankenPHP container
	@$(PHP_CONT) sh

bash: ## Connect to the FrankenPHP container via bash so up and down arrows go to previous commands
	@$(PHP_CONT) bash

test: ## Start tests with phpunit, pass the parameter "c=" to add options to phpunit, example: make test c="--group e2e --stop-on-failure"
	@$(eval c ?=)
	@$(DOCKER_COMP) exec --env=test php bin/phpunit $(c)


## —— Composer 🧙 ——————————————————————————————————————————————————————————————
composer: ## Run composer, pass the parameter "c=" to run a given command, example: make composer c='req symfony/orm-pack'
	@$(eval c ?=)
	@$(COMPOSER) $(c)

vendor: ## Install vendors according to the current composer.lock file
vendor: c=install --prefer-dist --no-dev --no-progress --no-scripts --no-interaction
vendor: composer

## —— Symfony 🎵 ———————————————————————————————————————————————————————————————
sf: ## List all Symfony commands or pass the parameter "c=" to run a given command, example: make sf c=about
	@$(eval c ?=)
	@$(SYMFONY) $(c)

cc: c=c:c ## Clear the cache
cc: sf

entity: ## Create a new entity
	@$(SYMFONY) make:entity

## —— Database 🗂️️ —————————————————————————————————————————————————————————————
database: ## Create the local dev database
		@make database-create
		## @make migrations-execute
		## @make fixtures-load

database-test: ## Create the test database
		@make database-create-test
		#@make database-migrations-execute-test
		#@make database-fixtures-test

database-create: ## Create the local dev database
		$(SYMFONY) doctrine:database:drop --if-exists --force
		$(SYMFONY) doctrine:database:create

database-create-test: ## Creates the test database
		$(SYMFONY) --env=test doctrine:database:drop --if-exists --force
		$(SYMFONY) --env=test doctrine:database:create

fixtures-load: ## Load fixtures
		$(SYMFONY) doctrine:fixtures:load -n --group=dev

migrations-generate: ## Generate doctrine migrations
		$(SYMFONY) doctrine:migrations:generate

migrations-execute: ## Execute doctrine migrations
		$(SYMFONY) doctrine:migrations:migrate --no-interaction

migrations-status: ## View migration status
		$(SYMFONY) doctrine:migrations:status

database-fixtures-test: ## Runs the test fixtures
	@docker-compose exec --env=test  php bin/console doctrine:fixtures:load -n --group=test

database-migrations-execute-test: ## Runs the current set of migrations against the DB
	@docker-compose exec --env=test  php bin/console doctrine:migrations:migrate --no-interaction


## —— Utils 🔌 ————————————————————————————————————————————————————————————————————————
trust-tls: ## Trust the TLS certificates
	@$(DOCKER) cp $(shell $(DOCKER_COMP) ps -q php):/data/caddy/pki/authorities/local/root.crt /tmp/root.crt && sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/root.crt

## —— Tools 🔧 ————————————————————————————————————————————————————————————————————————
cs-fix: ## Run php-cs-fixer, pass the parameter "c=" to run a given command, example: make cs-fix c='fix /path/to/project --rules=@PSR12', default is "fix src"
	@$(eval c ?= fix src/)
	@$(DOCKER_COMP) exec php vendor/bin/php-cs-fixer $(c)

grump-run: ## Run GrumPHP
	@$(PHP_CONT) ./vendor/bin/grumphp run

grump-init: ## Initialize GrumPHP
	@$(PHP_CONT) ./vendor/bin/grumphp git:init

