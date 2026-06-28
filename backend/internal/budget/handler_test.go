package budget

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

func jsonBudgetBody(t *testing.T, v any) *bytes.Buffer {
	t.Helper()
	b, err := json.Marshal(v)
	require.NoError(t, err)
	return bytes.NewBuffer(b)
}

func serveBudgetWithID(method string, h http.HandlerFunc, req *http.Request) *httptest.ResponseRecorder {
	mux := http.NewServeMux()
	mux.HandleFunc(method+" /budgets/{id}", h)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

// ---------------------------------------------------------------------------
// List

func TestHandlerBudgetList_Success(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/budgets?month=1&year=2025", nil)
	h.List(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerBudgetList_ServiceError(t *testing.T) {
	svc := NewService(&mockBudgetRepo{
		listFn: func(_ context.Context, _ string, _, _ int) ([]*Budget, error) {
			return nil, errors.New("db error")
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/budgets", nil)
	h.List(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// Create

func TestHandlerBudgetCreate_Success(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/budgets", jsonBudgetBody(t, map[string]any{
		"category_id": "cat-1", "amount": 500000.0, "month": 1, "year": 2025,
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)
}

func TestHandlerBudgetCreate_InvalidJSON(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/budgets", bytes.NewBufferString("bad"))
	h.Create(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerBudgetCreate_Conflict(t *testing.T) {
	svc := NewService(&mockBudgetRepo{
		createFn: func(_ context.Context, _ *Budget) error { return errors.New("unique constraint violation") },
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/budgets", jsonBudgetBody(t, map[string]any{
		"category_id": "cat-1", "amount": 500000.0, "month": 1, "year": 2025,
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusConflict, rec.Code)
}

func TestHandlerBudgetCreate_BadRequest(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/budgets", jsonBudgetBody(t, map[string]any{
		"category_id": "", "amount": 100.0, "month": 1, "year": 2025,
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerBudgetCreate_DuplicateKeyword(t *testing.T) {
	svc := NewService(&mockBudgetRepo{
		createFn: func(_ context.Context, _ *Budget) error { return errors.New("duplicate key") },
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/budgets", jsonBudgetBody(t, map[string]any{
		"category_id": "c", "amount": 100.0, "month": 1, "year": 2025,
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusConflict, rec.Code)
}

// ---------------------------------------------------------------------------
// Update

func TestHandlerBudgetUpdate_Success(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/budgets/b-1", jsonBudgetBody(t, map[string]any{
		"amount": 300000.0,
	}))
	rec := serveBudgetWithID(http.MethodPut, h.Update, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerBudgetUpdate_InvalidJSON(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/budgets/b-1", bytes.NewBufferString("bad"))
	rec := serveBudgetWithID(http.MethodPut, h.Update, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerBudgetUpdate_NotFound(t *testing.T) {
	svc := NewService(&mockBudgetRepo{
		updateFn: func(_ context.Context, _, _ string, _ float64) (*Budget, error) { return nil, nil },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/budgets/b-1", jsonBudgetBody(t, map[string]any{
		"amount": 100.0,
	}))
	rec := serveBudgetWithID(http.MethodPut, h.Update, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestHandlerBudgetUpdate_BadRequest(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/budgets/b-1", jsonBudgetBody(t, map[string]any{
		"amount": 0.0,
	}))
	rec := serveBudgetWithID(http.MethodPut, h.Update, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// Delete

func TestHandlerBudgetDelete_Success(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/budgets/b-1", nil)
	rec := serveBudgetWithID(http.MethodDelete, h.Delete, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerBudgetDelete_Error(t *testing.T) {
	svc := NewService(&mockBudgetRepo{
		deleteFn: func(_ context.Context, _, _ string) error { return errors.New("budget not found") },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/budgets/b-1", nil)
	rec := serveBudgetWithID(http.MethodDelete, h.Delete, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}
