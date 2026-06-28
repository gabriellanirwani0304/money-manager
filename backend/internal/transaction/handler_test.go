package transaction

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"money-manager/internal/account"
	"money-manager/internal/category"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func jsonTxBody(t *testing.T, v any) *bytes.Buffer {
	t.Helper()
	b, err := json.Marshal(v)
	require.NoError(t, err)
	return bytes.NewBuffer(b)
}

func serveTxWithID(method, id string, h http.HandlerFunc, req *http.Request) *httptest.ResponseRecorder {
	mux := http.NewServeMux()
	mux.HandleFunc(method+" /transactions/{id}", h)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func goodTxRepo() *mockTxRepo {
	return &mockTxRepo{
		getByIDFn: func(_ context.Context, id, _ string) (*Transaction, error) {
			return &Transaction{ID: id, Category: &category.Category{Name: "Food"}}, nil
		},
	}
}

// ---------------------------------------------------------------------------
// List

func TestHandlerTxList_Success(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/transactions?page=1&limit=10", nil)
	h.List(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerTxList_ServiceError(t *testing.T) {
	svc := NewService(&mockTxRepo{
		listFn: func(_ context.Context, _ string, _ *ListFilter) (*ListResult, error) {
			return nil, errors.New("db error")
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/transactions", nil)
	h.List(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// GetByID

func TestHandlerTxGetByID_Success(t *testing.T) {
	svc := NewService(goodTxRepo())
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodGet, "/transactions/tx-1", nil)
	rec := serveTxWithID(http.MethodGet, "tx-1", h.GetByID, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerTxGetByID_NotFound(t *testing.T) {
	svc := NewService(&mockTxRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*Transaction, error) { return nil, nil },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodGet, "/transactions/tx-1", nil)
	rec := serveTxWithID(http.MethodGet, "tx-1", h.GetByID, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestHandlerTxGetByID_InternalError(t *testing.T) {
	svc := NewService(&mockTxRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*Transaction, error) {
			return nil, errors.New("db error")
		},
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodGet, "/transactions/tx-1", nil)
	rec := serveTxWithID(http.MethodGet, "tx-1", h.GetByID, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// Create

func TestHandlerTxCreate_Success(t *testing.T) {
	svc := NewService(goodTxRepo())
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/transactions", jsonTxBody(t, map[string]any{
		"category_id": "cat-1", "type": "expense", "amount": 50000.0, "date": "2025-01-01",
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)
}

func TestHandlerTxCreate_InvalidJSON(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/transactions", bytes.NewBufferString("bad"))
	h.Create(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerTxCreate_ValidationError(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/transactions", jsonTxBody(t, map[string]any{
		"category_id": "", "type": "expense", "amount": 100.0, "date": "2025-01-01",
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// Update

func TestHandlerTxUpdate_Success(t *testing.T) {
	svc := NewService(goodTxRepo())
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/transactions/tx-1", jsonTxBody(t, map[string]any{
		"category_id": "cat-1", "type": "income", "amount": 100000.0, "date": "2025-01-01",
	}))
	rec := serveTxWithID(http.MethodPut, "tx-1", h.Update, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerTxUpdate_InvalidJSON(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/transactions/tx-1", bytes.NewBufferString("bad"))
	rec := serveTxWithID(http.MethodPut, "tx-1", h.Update, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerTxUpdate_NotFound(t *testing.T) {
	svc := NewService(&mockTxRepo{
		updateFn: func(_ context.Context, _ *Transaction) error { return errors.New("transaction not found") },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/transactions/tx-1", jsonTxBody(t, map[string]any{
		"category_id": "c", "type": "expense", "amount": 100.0, "date": "2025-01-01",
	}))
	rec := serveTxWithID(http.MethodPut, "tx-1", h.Update, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestHandlerTxUpdate_BadRequest(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/transactions/tx-1", jsonTxBody(t, map[string]any{
		"category_id": "", "type": "expense", "amount": 100.0, "date": "2025-01-01",
	}))
	rec := serveTxWithID(http.MethodPut, "tx-1", h.Update, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// Delete

func TestHandlerTxDelete_Success(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/transactions/tx-1", nil)
	rec := serveTxWithID(http.MethodDelete, "tx-1", h.Delete, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerTxDelete_Error(t *testing.T) {
	svc := NewService(&mockTxRepo{
		deleteFn: func(_ context.Context, _, _ string) error { return errors.New("not found") },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/transactions/tx-1", nil)
	rec := serveTxWithID(http.MethodDelete, "tx-1", h.Delete, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

// ---------------------------------------------------------------------------
// Export CSV

func TestHandlerTxExport_Success(t *testing.T) {
	svc := NewService(&mockTxRepo{
		exportCSVFn: func(_ context.Context, _, _, _, _ string) ([]*Transaction, error) {
			return []*Transaction{
				{ID: "t1", Type: "expense", Amount: 50000, Date: "2025-01-01",
					Category: &category.Category{Name: "Food"}, Account: nil},
			}, nil
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/transactions/export?start_date=2025-01-01&end_date=2025-01-31", nil)
	h.Export(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "text/csv", rec.Header().Get("Content-Type"))
}

func TestHandlerTxExport_WithAccountName(t *testing.T) {
	acc := &account.Account{Name: "BCA"}
	svc := NewService(&mockTxRepo{
		exportCSVFn: func(_ context.Context, _, _, _, _ string) ([]*Transaction, error) {
			return []*Transaction{
				{ID: "t1", Type: "expense", Amount: 50000, Date: "2025-01-01",
					Category: &category.Category{Name: "Food"}, Account: acc},
			}, nil
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/transactions/export?start_date=2025-01-01&end_date=2025-01-31", nil)
	h.Export(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, rec.Body.String(), "BCA")
}

func TestHandlerTxExport_MissingDates(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/transactions/export", nil)
	h.Export(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}
