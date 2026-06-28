//go:build integration

package report

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

func setupReportDeps(t *testing.T, pool *pgxpool.Pool) (userID, categoryID string) {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (name, email, password_hash, currency) VALUES ($1,$2,$3,$4) RETURNING id`,
		"Report User", fmt.Sprintf("report_%d@test.com", time.Now().UnixNano()), "$2a$04$ph", "IDR",
	).Scan(&userID))
	t.Cleanup(func() { testutil.CleanUser(t, pool, userID) })

	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO categories (name, type, icon, color, user_id) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
		"Report Cat", "expense", "icon", "#000", userID,
	).Scan(&categoryID))
	return
}

func insertTx(t *testing.T, pool *pgxpool.Pool, userID, catID, txType string, amount float64, date string) {
	t.Helper()
	_, err := pool.Exec(context.Background(),
		`INSERT INTO transactions (user_id, category_id, type, amount, date) VALUES ($1,$2,$3,$4,$5)`,
		userID, catID, txType, amount, date,
	)
	require.NoError(t, err)
}

func TestIntegration_ReportMonthlySummary(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupReportDeps(t, pool)

	insertTx(t, pool, userID, catID, "income", 5000000, "2025-01-10")
	insertTx(t, pool, userID, catID, "expense", 2000000, "2025-01-15")

	summary, err := repo.MonthlySummary(context.Background(), userID, 1, 2025)
	require.NoError(t, err)
	require.NotNil(t, summary)
	assert.Equal(t, 5000000.0, summary.Income)
	assert.Equal(t, 2000000.0, summary.Expense)
	assert.Equal(t, 3000000.0, summary.Balance)
}

func TestIntegration_ReportMonthlyTrend(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupReportDeps(t, pool)

	insertTx(t, pool, userID, catID, "income", 1000000, "2025-01-05")

	trends, err := repo.MonthlyTrend(context.Background(), userID)
	require.NoError(t, err)
	assert.NotNil(t, trends)
}

func TestIntegration_ReportCategoryBreakdown(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupReportDeps(t, pool)

	insertTx(t, pool, userID, catID, "expense", 300000, "2025-02-10")
	insertTx(t, pool, userID, catID, "expense", 200000, "2025-02-15")

	breakdowns, err := repo.CategoryBreakdown(context.Background(), userID, 2, 2025, "expense")
	require.NoError(t, err)
	require.NotEmpty(t, breakdowns)
	assert.Equal(t, 500000.0, breakdowns[0].Amount)
}

func TestIntegration_ReportInsights(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupReportDeps(t, pool)

	insertTx(t, pool, userID, catID, "income", 10000000, "2025-03-01")
	insertTx(t, pool, userID, catID, "expense", 3000000, "2025-03-15")

	insights, err := repo.Insights(context.Background(), userID, 3, 2025)
	require.NoError(t, err)
	assert.NotNil(t, insights)
}

func TestIntegration_ReportDashboard(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID, catID := setupReportDeps(t, pool)

	insertTx(t, pool, userID, catID, "income", 5000000, "2025-04-01")

	data, err := repo.Dashboard(context.Background(), userID, 4, 2025)
	require.NoError(t, err)
	assert.NotNil(t, data)
}
