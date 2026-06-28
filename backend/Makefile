.PHONY: run build migrate seed test test-unit test-integration test-coverage tidy

run:
	go run ./cmd/server

build:
	go build -o bin/server ./cmd/server

migrate:
	psql "$$DATABASE_URL" -f migrations/001_init.sql
	psql "$$DATABASE_URL" -f migrations/002_seed.sql
	psql "$$DATABASE_URL" -f migrations/003_accounts.sql

seed-categories:
	psql "$$DATABASE_URL" -f migrations/002_seed.sql

seed:
	go run ./cmd/seed

# Unit tests only (no DB required)
test-unit:
	go test ./... -v -count=1

# Integration tests (requires TEST_DATABASE_URL env var)
test-integration:
	go test -tags=integration ./... -v -count=1

# Run unit tests with coverage report
test-coverage:
	go test ./... -coverprofile=coverage.out -covermode=atomic
	go tool cover -func=coverage.out
	go tool cover -html=coverage.out -o coverage.html

# Alias
test: test-unit

tidy:
	go mod tidy
