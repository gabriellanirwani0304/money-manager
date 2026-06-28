// Seed creates the demo login account for development.
// Usage: DATABASE_URL=... go run ./cmd/seed
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

const (
	demoEmail    = "demo@moneymate.dev"
	demoPassword = "password123"
	demoName     = "Demo User"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL is required")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		log.Fatalf("connect: %v", err)
	}
	defer pool.Close()

	if _, err := pool.Exec(ctx, `DELETE FROM users WHERE email = $1`, demoEmail); err != nil {
		log.Fatalf("clean existing user: %v", err)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(demoPassword), 12)
	if err != nil {
		log.Fatalf("hash password: %v", err)
	}

	var userID string
	err = pool.QueryRow(ctx,
		`INSERT INTO users (name, email, password_hash, currency)
		 VALUES ($1, $2, $3, 'IDR') RETURNING id`,
		demoName, demoEmail, string(hash),
	).Scan(&userID)
	if err != nil {
		log.Fatalf("create user: %v", err)
	}

	fmt.Println("✓ Seed complete")
	fmt.Printf("  Email    : %s\n", demoEmail)
	fmt.Printf("  Password : %s\n", demoPassword)
	fmt.Printf("  User ID  : %s\n", userID)
}
