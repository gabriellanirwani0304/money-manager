//go:build integration

package category

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

func createTestUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	var id string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO users (name, email, password_hash, currency) VALUES ($1,$2,$3,$4) RETURNING id`,
		"Cat Test User", fmt.Sprintf("cat_%d@test.com", time.Now().UnixNano()), "$2a$04$ph", "IDR",
	).Scan(&id)
	require.NoError(t, err)
	t.Cleanup(func() { testutil.CleanUser(t, pool, id) })
	return id
}

func TestIntegration_CategoryList(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := createTestUser(t, pool)

	result, err := repo.List(context.Background(), userID, &ListFilter{Page: 1, Limit: 20})
	require.NoError(t, err)
	assert.NotNil(t, result.Categories) // default categories are always present
}

func TestIntegration_CategoryList_WithTypeFilter(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := createTestUser(t, pool)

	result, err := repo.List(context.Background(), userID, &ListFilter{Page: 1, Limit: 20, Type: "expense"})
	require.NoError(t, err)
	for _, c := range result.Categories {
		assert.Equal(t, "expense", c.Type)
	}
}

func TestIntegration_CategoryCreateAndGetByID(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := createTestUser(t, pool)

	cat := &Category{
		Name:   fmt.Sprintf("TestCat_%d", time.Now().UnixNano()),
		Type:   "expense",
		Icon:   "food",
		Color:  "#FF0000",
		UserID: &userID,
	}
	require.NoError(t, repo.Create(context.Background(), cat))
	assert.NotEmpty(t, cat.ID)

	got, err := repo.GetByID(context.Background(), cat.ID, userID)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, cat.Name, got.Name)
}

func TestIntegration_CategoryExistsByName(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := createTestUser(t, pool)

	name := fmt.Sprintf("UniqueNameCheck_%d", time.Now().UnixNano())
	cat := &Category{Name: name, Type: "expense", Icon: "x", Color: "#000", UserID: &userID}
	require.NoError(t, repo.Create(context.Background(), cat))

	exists, err := repo.ExistsByName(context.Background(), userID, name, "expense")
	require.NoError(t, err)
	assert.True(t, exists)

	notExists, err := repo.ExistsByName(context.Background(), userID, "NonExistent_999", "expense")
	require.NoError(t, err)
	assert.False(t, notExists)
}

func TestIntegration_CategoryUpdate(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	userID := createTestUser(t, pool)

	name := fmt.Sprintf("UpdateTest_%d", time.Now().UnixNano())
	cat := &Category{Name: name, Type: "income", Icon: "i", Color: "#111", UserID: &userID}
	require.NoError(t, repo.Create(context.Background(), cat))

	updated, err := repo.Update(context.Background(), cat.ID, userID, "Updated Name", "icon2", "#222")
	require.NoError(t, err)
	require.NotNil(t, updated)
	assert.Equal(t, "Updated Name", updated.Name)
}

func TestIntegration_CategoryUpdate_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)

	got, err := repo.Update(context.Background(), "00000000-0000-0000-0000-000000000000", "user1", "Name", "icon", "#000")
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_CategoryGetByID_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)

	got, err := repo.GetByID(context.Background(), "00000000-0000-0000-0000-000000000000", "user1")
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_CategoryDelete_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)

	err := repo.Delete(context.Background(), "00000000-0000-0000-0000-000000000000", "user1")
	assert.Error(t, err) // rows affected = 0
}
