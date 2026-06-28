package auth

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
)

// newTestHandler creates a Handler backed by a real Service with mock repo.
func newTestHandler(repo authRepository) *Handler {
	svc := newTestService(repo)
	return NewHandler(svc)
}

func jsonBody(t *testing.T, v any) *bytes.Buffer {
	t.Helper()
	b, err := json.Marshal(v)
	require.NoError(t, err)
	return bytes.NewBuffer(b)
}

// ---------------------------------------------------------------------------
// Register

func TestHandlerRegister_Success(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/register", jsonBody(t, map[string]string{
		"name": "Alice", "email": "alice@example.com", "password": "password123",
	}))
	h.Register(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)
}

func TestHandlerRegister_InvalidJSON(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/register", bytes.NewBufferString("not-json"))
	h.Register(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerRegister_ConflictOnDuplicateEmail(t *testing.T) {
	existing := &User{ID: "u1", Email: "dupe@example.com"}
	h := newTestHandler(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) { return existing, nil },
	})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/register", jsonBody(t, map[string]string{
		"name": "Bob", "email": "dupe@example.com", "password": "password123",
	}))
	h.Register(rec, req)
	assert.Equal(t, http.StatusConflict, rec.Code)
}

func TestHandlerRegister_BadRequestOnValidationError(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/register", jsonBody(t, map[string]string{
		"name": "Bob", "email": "bob@example.com", "password": "short",
	}))
	h.Register(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// Login

func TestHandlerLogin_Success(t *testing.T) {
	raw, err := bcrypt.GenerateFromPassword([]byte("password123"), 4)
	require.NoError(t, err)
	hash := string(raw)

	h := newTestHandler(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) {
			return &User{ID: "u1", Email: "a@example.com", PasswordHash: hash}, nil
		},
	})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/login", jsonBody(t, map[string]string{
		"email": "a@example.com", "password": "password123",
	}))
	h.Login(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerLogin_InvalidJSON(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewBufferString("{bad"))
	h.Login(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerLogin_Unauthorized(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) { return nil, nil },
	})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/login", jsonBody(t, map[string]string{
		"email": "a@example.com", "password": "pw",
	}))
	h.Login(rec, req)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

// ---------------------------------------------------------------------------
// Refresh

func TestHandlerRefresh_Success(t *testing.T) {
	pair := genPair(t)
	h := newTestHandler(&mockAuthRepo{
		getRefreshTokenFn: func(_ context.Context, _ string) (string, time.Time, error) {
			return "user-1", time.Now().Add(1 * time.Hour), nil
		},
	})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/refresh", jsonBody(t, map[string]string{
		"refresh_token": pair.RefreshToken,
	}))
	h.Refresh(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerRefresh_InvalidJSON(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/refresh", bytes.NewBufferString("{bad"))
	h.Refresh(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerRefresh_Unauthorized(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/refresh", jsonBody(t, map[string]string{
		"refresh_token": "invalid-token",
	}))
	h.Refresh(rec, req)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

// ---------------------------------------------------------------------------
// Logout

func TestHandlerLogout_Success(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/logout", jsonBody(t, map[string]string{
		"refresh_token": "some-token",
	}))
	h.Logout(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerLogout_InvalidJSON(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/logout", bytes.NewBufferString("{{"))
	h.Logout(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerLogout_InternalError(t *testing.T) {
	h := newTestHandler(&mockAuthRepo{
		deleteRefreshTokenFn: func(_ context.Context, _ string) error {
			return errors.New("db error")
		},
	})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/auth/logout", jsonBody(t, map[string]string{
		"refresh_token": "some-token",
	}))
	h.Logout(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}
