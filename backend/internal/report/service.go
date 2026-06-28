package report

import (
	"context"
	"fmt"
	"time"
)

type reportRepository interface {
	MonthlySummary(ctx context.Context, userID string, month, year int) (*MonthlySummary, error)
	MonthlyTrend(ctx context.Context, userID string) ([]*MonthlyTrend, error)
	CategoryBreakdown(ctx context.Context, userID string, month, year int, txType string) ([]*CategoryBreakdown, error)
	Insights(ctx context.Context, userID string, month, year int) (*Insights, error)
	Dashboard(ctx context.Context, userID string, month, year int) (*DashboardData, error)
}

type Service struct {
	repo reportRepository
}

func NewService(repo reportRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Summary(ctx context.Context, userID string, month, year int) (*MonthlySummary, error) {
	month, year = normalizeMonthYear(month, year)
	return s.repo.MonthlySummary(ctx, userID, month, year)
}

func (s *Service) MonthlyTrend(ctx context.Context, userID string) ([]*MonthlyTrend, error) {
	return s.repo.MonthlyTrend(ctx, userID)
}

func (s *Service) CategoryBreakdown(ctx context.Context, userID string, month, year int, txType string) ([]*CategoryBreakdown, error) {
	if txType != "income" && txType != "expense" {
		return nil, fmt.Errorf("type must be 'income' or 'expense'")
	}
	month, year = normalizeMonthYear(month, year)
	return s.repo.CategoryBreakdown(ctx, userID, month, year, txType)
}

func (s *Service) Insights(ctx context.Context, userID string, month, year int) (*Insights, error) {
	month, year = normalizeMonthYear(month, year)
	return s.repo.Insights(ctx, userID, month, year)
}

func (s *Service) Dashboard(ctx context.Context, userID string, month, year int) (*DashboardData, error) {
	month, year = normalizeMonthYear(month, year)
	return s.repo.Dashboard(ctx, userID, month, year)
}

func normalizeMonthYear(month, year int) (int, int) {
	now := time.Now()
	if month == 0 {
		month = int(now.Month())
	}
	if year == 0 {
		year = now.Year()
	}
	return month, year
}
