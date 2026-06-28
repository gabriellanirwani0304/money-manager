package testutil

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewTestPool connects to TEST_DATABASE_URL or skips the test.
func NewTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dbURL := os.Getenv("TEST_DATABASE_URL")
	if dbURL == "" {
		t.Skip("TEST_DATABASE_URL not set — skipping integration test")
	}
	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		t.Fatalf("testutil: open pool: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

// CleanUser deletes a test user by ID (cascades to all owned rows).
func CleanUser(t *testing.T, pool *pgxpool.Pool, userID string) {
	t.Helper()
	pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID)
}
