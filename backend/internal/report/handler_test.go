package report

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

// ---------------------------------------------------------------------------
// Dashboard

func TestHandlerDashboard_Success(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/dashboard?month=1&year=2025", nil)
	h.Dashboard(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerDashboard_ServiceError(t *testing.T) {
	svc := NewService(&mockReportRepo{
		dashboardFn: func(_ context.Context, _ string, _, _ int) (*DashboardData, error) {
			return nil, errors.New("db error")
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/dashboard", nil)
	h.Dashboard(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// Summary

func TestHandlerSummary_Success(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/reports/summary?month=1&year=2025", nil)
	h.Summary(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerSummary_ServiceError(t *testing.T) {
	svc := NewService(&mockReportRepo{
		monthlySummaryFn: func(_ context.Context, _ string, _, _ int) (*MonthlySummary, error) {
			return nil, errors.New("db error")
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/reports/summary", nil)
	h.Summary(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// MonthlyTrend

func TestHandlerMonthlyTrend_Success(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/reports/monthly", nil)
	h.MonthlyTrend(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerMonthlyTrend_ServiceError(t *testing.T) {
	svc := NewService(&mockReportRepo{
		monthlyTrendFn: func(_ context.Context, _ string) ([]*MonthlyTrend, error) {
			return nil, errors.New("db error")
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/reports/monthly", nil)
	h.MonthlyTrend(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}

// ---------------------------------------------------------------------------
// CategoryBreakdown

func TestHandlerCategoryBreakdown_Success(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/reports/by-category?type=expense&month=1&year=2025", nil)
	h.CategoryBreakdown(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerCategoryBreakdown_InvalidType(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/reports/by-category?type=invalid", nil)
	h.CategoryBreakdown(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ---------------------------------------------------------------------------
// Insights

func TestHandlerInsights_Success(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/reports/insights?month=1&year=2025", nil)
	h.Insights(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestHandlerInsights_ServiceError(t *testing.T) {
	svc := NewService(&mockReportRepo{
		insightsFn: func(_ context.Context, _ string, _, _ int) (*Insights, error) {
			return nil, errors.New("db error")
		},
	})
	h := NewHandler(svc)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/reports/insights", nil)
	h.Insights(rec, req)
	assert.Equal(t, http.StatusInternalServerError, rec.Code)
}
