//go:build integration

package transaction

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

func setupTxUser(t *testing.T, pool *pgxpool.Pool) (userID, categoryID string) {
	t.Helper()
	ctx := context.Background()

	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (name, email, password_hash, currency) VALUES ($1,$2,$3,$4) RETURNING id`,
		"Tx Test", fmt.Sprintf("tx_%d@test.com", time.Now().UnixNano()), "$2a$04$ph", "IDR",
	).Scan(&userID))
	t.Cleanup(func() { testutil.CleanUser(t, pool, userID) })

	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO categories (name, type, icon, color, user_id) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
		"Test Cat", "expense", "icon", "#000", userID,
	).Scan(&categoryID))
	return
}

func TestIntegration_TxCreateAndList(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupTxUser(t, pool)

	tx := &Transaction{
		UserID:     userID,
		CategoryID: catID,
		Type:       "expense",
		Amount:     50000,
		Date:       "2025-01-15",
	}
	require.NoError(t, repo.Create(context.Background(), tx))
	assert.NotEmpty(t, tx.ID)

	result, err := repo.List(context.Background(), userID, &ListFilter{Page: 1, Limit: 10})
	require.NoError(t, err)
	assert.GreaterOrEqual(t, result.Pagination.Total, 1)
}

func TestIntegration_TxGetByID(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupTxUser(t, pool)

	tx := &Transaction{UserID: userID, CategoryID: catID, Type: "income", Amount: 100000, Date: "2025-01-15"}
	require.NoError(t, repo.Create(context.Background(), tx))

	got, err := repo.GetByID(context.Background(), tx.ID, userID)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, tx.ID, got.ID)
	assert.Equal(t, 100000.0, got.Amount)
}

func TestIntegration_TxGetByID_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)

	got, err := repo.GetByID(context.Background(), "00000000-0000-0000-0000-000000000000", "user1")
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_TxUpdate(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupTxUser(t, pool)

	tx := &Transaction{UserID: userID, CategoryID: catID, Type: "expense", Amount: 50000, Date: "2025-01-15"}
	require.NoError(t, repo.Create(context.Background(), tx))

	tx.Amount = 75000
	tx.Type = "expense"
	require.NoError(t, repo.Update(context.Background(), tx))

	got, err := repo.GetByID(context.Background(), tx.ID, userID)
	require.NoError(t, err)
	assert.Equal(t, 75000.0, got.Amount)
}

func TestIntegration_TxDelete(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupTxUser(t, pool)

	tx := &Transaction{UserID: userID, CategoryID: catID, Type: "expense", Amount: 10000, Date: "2025-01-15"}
	require.NoError(t, repo.Create(context.Background(), tx))

	require.NoError(t, repo.Delete(context.Background(), tx.ID, userID))

	got, err := repo.GetByID(context.Background(), tx.ID, userID)
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_TxExportCSV(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupTxUser(t, pool)

	tx := &Transaction{UserID: userID, CategoryID: catID, Type: "expense", Amount: 30000, Date: "2025-01-15"}
	require.NoError(t, repo.Create(context.Background(), tx))

	txs, err := repo.ExportCSV(context.Background(), userID, "2025-01-01", "2025-01-31", "expense")
	require.NoError(t, err)
	assert.GreaterOrEqual(t, len(txs), 1)
}

func TestIntegration_TxList_WithFilters(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupTxUser(t, pool)

	repo.Create(context.Background(), &Transaction{UserID: userID, CategoryID: catID, Type: "expense", Amount: 10000, Date: "2025-01-15"})
	repo.Create(context.Background(), &Transaction{UserID: userID, CategoryID: catID, Type: "income", Amount: 20000, Date: "2025-01-16"})

	result, err := repo.List(context.Background(), userID, &ListFilter{
		Page: 1, Limit: 10, Type: "expense",
	})
	require.NoError(t, err)
	for _, tx := range result.Transactions {
		assert.Equal(t, "expense", tx.Type)
	}
}
