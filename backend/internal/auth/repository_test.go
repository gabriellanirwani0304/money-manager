//go:build integration

package auth

import (
	"context"
	"fmt"
	"testing"
	"time"

	"money-manager/internal/testutil"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIntegration_CreateAndGetUser(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	ctx := context.Background()

	email := fmt.Sprintf("test_%d@example.com", time.Now().UnixNano())
	user := &User{
		Name:         "Integration User",
		Email:        email,
		PasswordHash: "$2a$04$test_hash_placeholder_value",
		Currency:     "IDR",
	}

	err := repo.CreateUser(ctx, user)
	require.NoError(t, err)
	assert.NotEmpty(t, user.ID)
	t.Cleanup(func() { testutil.CleanUser(t, pool, user.ID) })

	got, err := repo.GetUserByEmail(ctx, email)
	require.NoError(t, err)
	require.NotNil(t, got)
	assert.Equal(t, user.ID, got.ID)
	assert.Equal(t, email, got.Email)
}

func TestIntegration_GetUserByEmail_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	ctx := context.Background()

	got, err := repo.GetUserByEmail(ctx, "nonexistent@example.com")
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_GetUserByID_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	ctx := context.Background()

	got, err := repo.GetUserByID(ctx, "00000000-0000-0000-0000-000000000000")
	require.NoError(t, err)
	assert.Nil(t, got)
}

func TestIntegration_RefreshTokenLifecycle(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	ctx := context.Background()

	email := fmt.Sprintf("refresh_%d@example.com", time.Now().UnixNano())
	user := &User{
		Name:         "Refresh User",
		Email:        email,
		PasswordHash: "$2a$04$placeholder",
		Currency:     "IDR",
	}
	require.NoError(t, repo.CreateUser(ctx, user))
	t.Cleanup(func() { testutil.CleanUser(t, pool, user.ID) })

	hash := "token_hash_" + user.ID
	expiresAt := time.Now().Add(7 * 24 * time.Hour)

	// Save
	err := repo.SaveRefreshToken(ctx, user.ID, hash, expiresAt)
	require.NoError(t, err)

	// Get
	gotUserID, gotExpiry, err := repo.GetRefreshToken(ctx, hash)
	require.NoError(t, err)
	assert.Equal(t, user.ID, gotUserID)
	assert.WithinDuration(t, expiresAt, gotExpiry, time.Second)

	// Delete
	require.NoError(t, repo.DeleteRefreshToken(ctx, hash))

	// Get after delete should return empty
	userID2, _, err2 := repo.GetRefreshToken(ctx, hash)
	require.NoError(t, err2)
	assert.Empty(t, userID2)
}

func TestIntegration_GetRefreshToken_NotFound(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	ctx := context.Background()

	userID, _, err := repo.GetRefreshToken(ctx, "nonexistent_hash")
	require.NoError(t, err)
	assert.Empty(t, userID)
}

func TestIntegration_DeleteExpiredTokens(t *testing.T) {
	pool := testutil.NewTestPool(t)
	repo := NewRepository(pool)
	ctx := context.Background()

	email := fmt.Sprintf("expired_%d@example.com", time.Now().UnixNano())
	user := &User{Name: "Expired User", Email: email, PasswordHash: "$2a$04$ph", Currency: "IDR"}
	require.NoError(t, repo.CreateUser(ctx, user))
	t.Cleanup(func() { testutil.CleanUser(t, pool, user.ID) })

	// Insert an already-expired token
	require.NoError(t, repo.SaveRefreshToken(ctx, user.ID, "expired_hash", time.Now().Add(-1*time.Hour)))
	require.NoError(t, repo.DeleteExpiredTokens(ctx))

	uid, _, err := repo.GetRefreshToken(ctx, "expired_hash")
	require.NoError(t, err)
	assert.Empty(t, uid)
}
