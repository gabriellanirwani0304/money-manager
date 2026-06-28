package report

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ---------------------------------------------------------------------------
// mock

type mockReportRepo struct {
	monthlySummaryFn    func(ctx context.Context, userID string, month, year int) (*MonthlySummary, error)
	monthlyTrendFn      func(ctx context.Context, userID string) ([]*MonthlyTrend, error)
	categoryBreakdownFn func(ctx context.Context, userID string, month, year int, txType string) ([]*CategoryBreakdown, error)
	insightsFn          func(ctx context.Context, userID string, month, year int) (*Insights, error)
	dashboardFn         func(ctx context.Context, userID string, month, year int) (*DashboardData, error)
}

func (m *mockReportRepo) MonthlySummary(ctx context.Context, userID string, month, year int) (*MonthlySummary, error) {
	if m.monthlySummaryFn != nil {
		return m.monthlySummaryFn(ctx, userID, month, year)
	}
	return &MonthlySummary{Month: month, Year: year}, nil
}
func (m *mockReportRepo) MonthlyTrend(ctx context.Context, userID string) ([]*MonthlyTrend, error) {
	if m.monthlyTrendFn != nil {
		return m.monthlyTrendFn(ctx, userID)
	}
	return []*MonthlyTrend{}, nil
}
func (m *mockReportRepo) CategoryBreakdown(ctx context.Context, userID string, month, year int, txType string) ([]*CategoryBreakdown, error) {
	if m.categoryBreakdownFn != nil {
		return m.categoryBreakdownFn(ctx, userID, month, year, txType)
	}
	return []*CategoryBreakdown{}, nil
}
func (m *mockReportRepo) Insights(ctx context.Context, userID string, month, year int) (*Insights, error) {
	if m.insightsFn != nil {
		return m.insightsFn(ctx, userID, month, year)
	}
	return &Insights{}, nil
}
func (m *mockReportRepo) Dashboard(ctx context.Context, userID string, month, year int) (*DashboardData, error) {
	if m.dashboardFn != nil {
		return m.dashboardFn(ctx, userID, month, year)
	}
	return &DashboardData{}, nil
}

// ---------------------------------------------------------------------------
// normalizeMonthYear

func TestNormalizeMonthYear_ZeroValues(t *testing.T) {
	m, y := normalizeMonthYear(0, 0)
	assert.NotZero(t, m)
	assert.NotZero(t, y)
}

func TestNormalizeMonthYear_NonZeroValues(t *testing.T) {
	m, y := normalizeMonthYear(3, 2025)
	assert.Equal(t, 3, m)
	assert.Equal(t, 2025, y)
}

func TestNormalizeMonthYear_ZeroMonth(t *testing.T) {
	_, y := normalizeMonthYear(0, 2024)
	assert.Equal(t, 2024, y)
}

// ---------------------------------------------------------------------------
// Summary

func TestReportSummary_NormalizesZeroMonth(t *testing.T) {
	var gotMonth, gotYear int
	svc := NewService(&mockReportRepo{
		monthlySummaryFn: func(_ context.Context, _ string, m, y int) (*MonthlySummary, error) {
			gotMonth, gotYear = m, y
			return &MonthlySummary{}, nil
		},
	})
	_, _ = svc.Summary(context.Background(), "u", 0, 0)
	assert.NotZero(t, gotMonth)
	assert.NotZero(t, gotYear)
}

func TestReportSummary_PassesCorrectValues(t *testing.T) {
	var gotMonth, gotYear int
	svc := NewService(&mockReportRepo{
		monthlySummaryFn: func(_ context.Context, _ string, m, y int) (*MonthlySummary, error) {
			gotMonth, gotYear = m, y
			return &MonthlySummary{}, nil
		},
	})
	_, _ = svc.Summary(context.Background(), "u", 5, 2024)
	assert.Equal(t, 5, gotMonth)
	assert.Equal(t, 2024, gotYear)
}

// ---------------------------------------------------------------------------
// MonthlyTrend

func TestReportMonthlyTrend_Success(t *testing.T) {
	svc := NewService(&mockReportRepo{
		monthlyTrendFn: func(_ context.Context, _ string) ([]*MonthlyTrend, error) {
			return []*MonthlyTrend{{Month: "2025-01", Income: 5000000}}, nil
		},
	})
	data, err := svc.MonthlyTrend(context.Background(), "u")
	require.NoError(t, err)
	assert.Len(t, data, 1)
}

func TestReportMonthlyTrend_Error(t *testing.T) {
	svc := NewService(&mockReportRepo{
		monthlyTrendFn: func(_ context.Context, _ string) ([]*MonthlyTrend, error) {
			return nil, errors.New("db error")
		},
	})
	_, err := svc.MonthlyTrend(context.Background(), "u")
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// CategoryBreakdown

func TestReportCategoryBreakdown_InvalidType(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	_, err := svc.CategoryBreakdown(context.Background(), "u", 1, 2025, "invalid")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "type must be")
}

func TestReportCategoryBreakdown_Income(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	_, err := svc.CategoryBreakdown(context.Background(), "u", 1, 2025, "income")
	require.NoError(t, err)
}

func TestReportCategoryBreakdown_Expense(t *testing.T) {
	svc := NewService(&mockReportRepo{})
	_, err := svc.CategoryBreakdown(context.Background(), "u", 1, 2025, "expense")
	require.NoError(t, err)
}

// ---------------------------------------------------------------------------
// Insights

func TestReportInsights_Success(t *testing.T) {
	svc := NewService(&mockReportRepo{
		insightsFn: func(_ context.Context, _ string, _, _ int) (*Insights, error) {
			return &Insights{SavingsRate: 0.2}, nil
		},
	})
	data, err := svc.Insights(context.Background(), "u", 1, 2025)
	require.NoError(t, err)
	assert.Equal(t, 0.2, data.SavingsRate)
}

// ---------------------------------------------------------------------------
// Dashboard

func TestReportDashboard_Success(t *testing.T) {
	svc := NewService(&mockReportRepo{
		dashboardFn: func(_ context.Context, _ string, _, _ int) (*DashboardData, error) {
			return &DashboardData{Balance: 1000000}, nil
		},
	})
	data, err := svc.Dashboard(context.Background(), "u", 1, 2025)
	require.NoError(t, err)
	assert.Equal(t, 1000000.0, data.Balance)
}

func TestReportDashboard_Error(t *testing.T) {
	svc := NewService(&mockReportRepo{
		dashboardFn: func(_ context.Context, _ string, _, _ int) (*DashboardData, error) {
			return nil, errors.New("db error")
		},
	})
	_, err := svc.Dashboard(context.Background(), "u", 1, 2025)
	assert.Error(t, err)
}
