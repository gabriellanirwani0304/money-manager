//go:build integration

package account

import (
	"context"
	"fmt"
	"testing"
	"time"

	"money-manager/internal/testutil"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupAccUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	var userID string
	require.NoError(t, pool.QueryRow(context.Background(),
		`INSERT INTO users (name, email, password_hash, currency) VALUES ($1,$2,$3,$4) RETURNING id`,
		"Acc Test", fmt.Sprintf("acc_%d@test.com", time.Now().UnixNano()), "$2a$04$ph", "IDR",
	).Scan(&userID))
	t.Cleanup(func() { testutil.CleanUser(t, pool, userID) })
	return userID
}

func TestIntegration_AccountCreateAndList(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := setupAccUser(t, pool)

	a := &Account{
		UserID:         userID,
		Name:           "BCA Savings",
		Type:           "bank",
		Icon:           "account_balance",
		Color:          "#6C5CE7",
		InitialBalance: 1000000,
	}
	require.NoError(t, repo.Create(context.Background(), a))
	assert.NotEmpty(t, a.ID)

	accounts, err := repo.List(context.Background(), userID)
	require.NoError(t, err)
	assert.Len(t, accounts, 1)
	assert.Equal(t, 1000000.0, accounts[0].Balance)
}

func TestIntegration_AccountGetByID(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := setupAccUser(t, pool)

	a := &Account{UserID: userID, Name: "GoPay", Type: "ewallet", Icon: "i", Color: "#000", InitialBalance: 500000}
	require.NoError(t, repo.Create(context.Background(), a))

	got, err := repo.GetByID(context.Background(), a.ID, userID)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, "GoPay", got.Name)
}

func TestIntegration_AccountGetByID_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	got, err := repo.GetByID(context.Background(), "00000000-0000-0000-0000-000000000000", "u")
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_AccountUpdate(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := setupAccUser(t, pool)

	a := &Account{UserID: userID, Name: "Old Name", Type: "cash", Icon: "i", Color: "#000"}
	require.NoError(t, repo.Create(context.Background(), a))

	updated, err := repo.Update(context.Background(), a.ID, userID, &UpdateRequest{Name: "New Name", Icon: "i2", Color: "#111"})
	require.NoError(t, err)
	require.NotNil(t, updated)
	assert.Equal(t, "New Name", updated.Name)
}

func TestIntegration_AccountUpdate_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	got, err := repo.Update(context.Background(), "00000000-0000-0000-0000-000000000000", "u", &UpdateRequest{Name: "X"})
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_AccountSetBalance(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := setupAccUser(t, pool)

	a := &Account{UserID: userID, Name: "Cash", Type: "cash", Icon: "i", Color: "#000"}
	require.NoError(t, repo.Create(context.Background(), a))

	require.NoError(t, repo.SetBalance(context.Background(), a.ID, userID, 250000))

	got, err := repo.GetByID(context.Background(), a.ID, userID)
	require.NoError(t, err)
	assert.Equal(t, 250000.0, got.Balance)
}

func TestIntegration_AccountDelete(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := setupAccUser(t, pool)

	a := &Account{UserID: userID, Name: "To Delete", Type: "other", Icon: "i", Color: "#000"}
	require.NoError(t, repo.Create(context.Background(), a))

	require.NoError(t, repo.Delete(context.Background(), a.ID, userID))

	accounts, err := repo.List(context.Background(), userID)
	require.NoError(t, err)
	assert.Empty(t, accounts)
}

func TestIntegration_AccountTotalBalance(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := setupAccUser(t, pool)

	repo.Create(context.Background(), &Account{UserID: userID, Name: "A1", Type: "bank", Icon: "i", Color: "#000", InitialBalance: 100000})
	repo.Create(context.Background(), &Account{UserID: userID, Name: "A2", Type: "cash", Icon: "i", Color: "#000", InitialBalance: 50000})

	total, err := repo.TotalBalance(context.Background(), userID)
	require.NoError(t, err)
	assert.Equal(t, 150000.0, total)
}
