package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	pkgjwt "money-manager/pkg/jwt"

	"github.com/stretchr/testify/assert"
)

const authTestSecret = "test-secret-middleware-key-12345"

func makeAccessToken(t *testing.T, userID string) string {
	t.Helper()
	pair, err := pkgjwt.Generate(userID, authTestSecret, 15*time.Minute, 7*24*time.Hour)
	if err != nil {
		t.Fatalf("generate token: %v", err)
	}
	return pair.AccessToken
}

func makeRefreshToken(t *testing.T, userID string) string {
	t.Helper()
	pair, err := pkgjwt.Generate(userID, authTestSecret, 15*time.Minute, 7*24*time.Hour)
	if err != nil {
		t.Fatalf("generate token: %v", err)
	}
	return pair.RefreshToken
}

func okHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func TestAuth_MissingAuthorizationHeader(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	Auth(authTestSecret)(http.HandlerFunc(okHandler)).ServeHTTP(rec, req)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestAuth_MissingBearerPrefix(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Basic sometoken")
	Auth(authTestSecret)(http.HandlerFunc(okHandler)).ServeHTTP(rec, req)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestAuth_InvalidToken(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer not-a-valid-token")
	Auth(authTestSecret)(http.HandlerFunc(okHandler)).ServeHTTP(rec, req)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestAuth_RefreshTokenRejected(t *testing.T) {
	token := makeRefreshToken(t, "user-1")
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	Auth(authTestSecret)(http.HandlerFunc(okHandler)).ServeHTTP(rec, req)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestAuth_ValidAccessToken_CallsNext(t *testing.T) {
	token := makeAccessToken(t, "user-42")
	called := false
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		assert.Equal(t, "user-42", GetUserID(r))
		w.WriteHeader(http.StatusOK)
	})

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	Auth(authTestSecret)(next).ServeHTTP(rec, req)

	assert.True(t, called)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestGetUserID_FromContext(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	ctx := context.WithValue(req.Context(), UserIDKey, "user-99")
	req = req.WithContext(ctx)
	assert.Equal(t, "user-99", GetUserID(req))
}

func TestGetUserID_EmptyWhenNotSet(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	assert.Equal(t, "", GetUserID(req))
}
