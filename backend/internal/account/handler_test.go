package account

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func jsonAccBody(t *testing.T, v any) *bytes.Buffer {
	t.Helper()
	b, err := json.Marshal(v)
	require.NoError(t, err)
	return bytes.NewBuffer(b)
}

func serveAccWithID(method string, h http.HandlerFunc, req *http.Request) *httptest.ResponseRecorder {
	mux := http.NewServeMux()
	mux.HandleFunc(method+" /accounts/{id}", h)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func serveAccBalanceWithID(h http.HandlerFunc, req *http.Request) *httptest.ResponseRecorder {
	mux := http.NewServeMux()
	mux.HandleFunc("PATCH /accounts/{id}/balance", h)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

// ---------------------------------------------------------------------------
// List

func TestHandlerAccList_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/accounts", nil)
	h.List(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerAccList_ServiceError(t *testing.T) {
	svc := NewService(&mockAccRepo{
		listFn: func(_ context.Context, _ string) ([]*Account, error) { return nil, errors.New("db") },
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/accounts", nil)
	h.List(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// GetByID

func TestHandlerAccGetByID_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodGet, "/accounts/acc-1", nil)
	rec := serveAccWithID(http.MethodGet, h.GetByID, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerAccGetByID_NotFound(t *testing.T) {
	svc := NewService(&mockAccRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*Account, error) { return nil, nil },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodGet, "/accounts/acc-1", nil)
	rec := serveAccWithID(http.MethodGet, h.GetByID, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestHandlerAccGetByID_InternalError(t *testing.T) {
	svc := NewService(&mockAccRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*Account, error) { return nil, errors.New("db") },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodGet, "/accounts/acc-1", nil)
	rec := serveAccWithID(http.MethodGet, h.GetByID, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// Create

func TestHandlerAccCreate_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/accounts", jsonAccBody(t, map[string]any{
		"name": "My Bank", "type": "bank",
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)
}

func TestHandlerAccCreate_InvalidJSON(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/accounts", bytes.NewBufferString("bad"))
	h.Create(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerAccCreate_ValidationError(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/accounts", jsonAccBody(t, map[string]any{
		"name": "", "type": "bank",
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// Update

func TestHandlerAccUpdate_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/accounts/acc-1", jsonAccBody(t, map[string]any{
		"name": "Updated BCA",
	}))
	rec := serveAccWithID(http.MethodPut, h.Update, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerAccUpdate_InvalidJSON(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/accounts/acc-1", bytes.NewBufferString("bad"))
	rec := serveAccWithID(http.MethodPut, h.Update, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerAccUpdate_NotFound(t *testing.T) {
	svc := NewService(&mockAccRepo{
		updateFn: func(_ context.Context, _, _ string, _ *UpdateRequest) (*Account, error) { return nil, nil },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/accounts/acc-1", jsonAccBody(t, map[string]any{
		"name": "Name",
	}))
	rec := serveAccWithID(http.MethodPut, h.Update, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestHandlerAccUpdate_BadRequest(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/accounts/acc-1", jsonAccBody(t, map[string]any{
		"name": "",
	}))
	rec := serveAccWithID(http.MethodPut, h.Update, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// SetBalance

func TestHandlerAccSetBalance_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPatch, "/accounts/acc-1/balance", jsonAccBody(t, map[string]any{
		"balance": 500000.0,
	}))
	rec := serveAccBalanceWithID(h.SetBalance, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerAccSetBalance_InvalidJSON(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPatch, "/accounts/acc-1/balance", bytes.NewBufferString("bad"))
	rec := serveAccBalanceWithID(h.SetBalance, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerAccSetBalance_NegativeBalance(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPatch, "/accounts/acc-1/balance", jsonAccBody(t, map[string]any{
		"balance": -100.0,
	}))
	rec := serveAccBalanceWithID(h.SetBalance, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerAccSetBalance_NotFound(t *testing.T) {
	svc := NewService(&mockAccRepo{
		setBalanceFn: func(_ context.Context, _, _ string, _ float64) error {
			return errors.New("account not found")
		},
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPatch, "/accounts/acc-1/balance", jsonAccBody(t, map[string]any{
		"balance": 0.0,
	}))
	rec := serveAccBalanceWithID(h.SetBalance, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestHandlerAccSetBalance_InternalError(t *testing.T) {
	svc := NewService(&mockAccRepo{
		setBalanceFn: func(_ context.Context, _, _ string, _ float64) error {
			return errors.New("connection lost")
		},
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPatch, "/accounts/acc-1/balance", jsonAccBody(t, map[string]any{
		"balance": 100.0,
	}))
	rec := serveAccBalanceWithID(h.SetBalance, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// Delete

func TestHandlerAccDelete_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/accounts/acc-1", nil)
	rec := serveAccWithID(http.MethodDelete, h.Delete, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerAccDelete_Error(t *testing.T) {
	svc := NewService(&mockAccRepo{
		deleteFn: func(_ context.Context, _, _ string) error { return errors.New("not found") },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/accounts/acc-1", nil)
	rec := serveAccWithID(http.MethodDelete, h.Delete, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}
