//go:build integration

package budget

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

func setupBudgetDeps(t *testing.T, pool *pgxpool.Pool) (userID, categoryID string) {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (name, email, password_hash, currency) VALUES ($1,$2,$3,$4) RETURNING id`,
		"Budget Test", fmt.Sprintf("budget_%d@test.com", time.Now().UnixNano()), "$2a$04$ph", "IDR",
	).Scan(&userID))
	t.Cleanup(func() { testutil.CleanUser(t, pool, userID) })

	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO categories (name, type, icon, color, user_id) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
		"Budget Cat", "expense", "icon", "#000", userID,
	).Scan(&categoryID))
	return
}

func TestIntegration_BudgetCreateAndList(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupBudgetDeps(t, pool)

	b := &Budget{UserID: userID, CategoryID: catID, Amount: 500000, Month: 1, Year: 2025}
	require.NoError(t, repo.Create(context.Background(), b))
	assert.NotEmpty(t, b.ID)

	budgets, err := repo.List(context.Background(), userID, 1, 2025)
	require.NoError(t, err)
	assert.Len(t, budgets, 1)
	assert.Equal(t, 500000.0, budgets[0].Amount)
}

func TestIntegration_BudgetUpdate(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupBudgetDeps(t, pool)

	b := &Budget{UserID: userID, CategoryID: catID, Amount: 200000, Month: 2, Year: 2025}
	require.NoError(t, repo.Create(context.Background(), b))

	updated, err := repo.Update(context.Background(), b.ID, userID, 300000)
	require.NoError(t, err)
	require.NotNil(t, updated)
	assert.Equal(t, 300000.0, updated.Amount)
}

func TestIntegration_BudgetUpdate_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)

	got, err := repo.Update(context.Background(), "00000000-0000-0000-0000-000000000000", "u", 100)
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_BudgetDelete(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupBudgetDeps(t, pool)

	b := &Budget{UserID: userID, CategoryID: catID, Amount: 100000, Month: 3, Year: 2025}
	require.NoError(t, repo.Create(context.Background(), b))
	require.NoError(t, repo.Delete(context.Background(), b.ID, userID))

	budgets, err := repo.List(context.Background(), userID, 3, 2025)
	require.NoError(t, err)
	assert.Empty(t, budgets)
}

func TestIntegration_BudgetDelete_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	err := repo.Delete(context.Background(), "00000000-0000-0000-0000-000000000000", "u")
	assert.Error(t, err)
}

func TestIntegration_BudgetGetByID(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupBudgetDeps(t, pool)

	b := &Budget{UserID: userID, CategoryID: catID, Amount: 400000, Month: 4, Year: 2025}
	require.NoError(t, repo.Create(context.Background(), b))

	got, err := repo.GetByID(context.Background(), b.ID, userID)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, 400000.0, got.Amount)
}

func TestIntegration_BudgetGetByID_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	got, err := repo.GetByID(context.Background(), "00000000-0000-0000-0000-000000000000", "u")
	require.NoError(t, err)
	assert.Nil(t, got)
}
