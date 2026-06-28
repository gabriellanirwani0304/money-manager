package response

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestJSON_SetsHeaderAndBody(t *testing.T) {
	rec := httptest.NewRecorder()
	JSON(rec, http.StatusOK, map[string]string{"key": "value"})

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "application/json", rec.Header().Get("Content-Type"))

	var r Response
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &r))
	assert.True(t, r.Success)
}

func TestJSON_CreatedStatus(t *testing.T) {
	rec := httptest.NewRecorder()
	JSON(rec, http.StatusCreated, "created")
	assert.Equal(t, http.StatusCreated, rec.Code)
}

func TestMessage_SetsMessage(t *testing.T) {
	rec := httptest.NewRecorder()
	Message(rec, http.StatusOK, "operation successful")

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "application/json", rec.Header().Get("Content-Type"))

	var r Response
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &r))
	assert.True(t, r.Success)
	assert.Equal(t, "operation successful", r.Message)
}

func TestError_SetsErrorBody(t *testing.T) {
	rec := httptest.NewRecorder()
	Error(rec, http.StatusBadRequest, "something went wrong", "BAD_REQUEST")

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Equal(t, "application/json", rec.Header().Get("Content-Type"))

	var r ErrorResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &r))
	assert.False(t, r.Success)
	assert.Equal(t, "something went wrong", r.Error)
	assert.Equal(t, "BAD_REQUEST", r.Code)
}

func TestError_NotFound(t *testing.T) {
	rec := httptest.NewRecorder()
	Error(rec, http.StatusNotFound, "resource not found", "NOT_FOUND")
	assert.Equal(t, http.StatusNotFound, rec.Code)
}
