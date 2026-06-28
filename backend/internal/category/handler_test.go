package category

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

func jsonCatBody(t *testing.T, v any) *bytes.Buffer {
	t.Helper()
	b, err := json.Marshal(v)
	require.NoError(t, err)
	return bytes.NewBuffer(b)
}

// serveWithID routes a request through a mux so PathValue("id") is available.
func serveCatWithID(method, id string, h http.HandlerFunc, req *http.Request) *httptest.ResponseRecorder {
	mux := http.NewServeMux()
	mux.HandleFunc(method+" /categories/{id}", h)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

// ---------------------------------------------------------------------------
// List

func TestHandlerCategoryList_Success(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/categories", nil)
	h.List(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerCategoryList_ServiceError(t *testing.T) {
	svc := NewService(&mockCatRepo{
		listFn: func(_ context.Context, _ string, _ *ListFilter) (*ListResult, error) {
			return nil, errors.New("db error")
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/categories", nil)
	h.List(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// Create

func TestHandlerCategoryCreate_Success(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/categories", jsonCatBody(t, map[string]string{
		"name": "Food", "type": "expense",
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)
}

func TestHandlerCategoryCreate_InvalidJSON(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/categories", bytes.NewBufferString("bad"))
	h.Create(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerCategoryCreate_Conflict(t *testing.T) {
	svc := NewService(&mockCatRepo{
		existsByNameFn: func(_ context.Context, _, _, _ string) (bool, error) { return true, nil },
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/categories", jsonCatBody(t, map[string]string{
		"name": "Food", "type": "expense",
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusConflict, rec.Code)
}

func TestHandlerCategoryCreate_BadRequest(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/categories", jsonCatBody(t, map[string]string{
		"name": "", "type": "expense",
	}))
	h.Create(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// Update

func TestHandlerCategoryUpdate_Success(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/categories/cat-1", jsonCatBody(t, map[string]string{
		"name": "Updated Name",
	}))
	rec := serveCatWithID(http.MethodPut, "cat-1", h.Update, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerCategoryUpdate_InvalidJSON(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/categories/cat-1", bytes.NewBufferString("bad"))
	rec := serveCatWithID(http.MethodPut, "cat-1", h.Update, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerCategoryUpdate_NotFound(t *testing.T) {
	svc := NewService(&mockCatRepo{
		updateFn: func(_ context.Context, _, _, _, _, _ string) (*Category, error) { return nil, nil },
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/categories/cat-1", jsonCatBody(t, map[string]string{
		"name": "Name",
	}))
	rec := serveCatWithID(http.MethodPut, "cat-1", h.Update, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestHandlerCategoryUpdate_BadRequest(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodPut, "/categories/cat-1", jsonCatBody(t, map[string]string{
		"name": "",
	}))
	rec := serveCatWithID(http.MethodPut, "cat-1", h.Update, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// Delete

func TestHandlerCategoryDelete_Success(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/categories/cat-1", nil)
	rec := serveCatWithID(http.MethodDelete, "cat-1", h.Delete, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerCategoryDelete_HasTransactions(t *testing.T) {
	svc := NewService(&mockCatRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return errors.New("category has transactions")
		},
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/categories/cat-1", nil)
	rec := serveCatWithID(http.MethodDelete, "cat-1", h.Delete, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestHandlerCategoryDelete_NotFound(t *testing.T) {
	svc := NewService(&mockCatRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return errors.New("category not found")
		},
	})
	h := NewHandler(svc)
	req := httptest.NewRequest(http.MethodDelete, "/categories/cat-1", nil)
	rec := serveCatWithID(http.MethodDelete, "cat-1", h.Delete, req)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}
