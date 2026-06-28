package budget

import (
	"context"
	"fmt"
	"time"
)

type budgetRepository interface {
	List(ctx context.Context, userID string, month, year int) ([]*Budget, error)
	GetByID(ctx context.Context, id, userID string) (*Budget, error)
	Create(ctx context.Context, b *Budget) error
	Update(ctx context.Context, id, userID string, amount float64) (*Budget, error)
	Delete(ctx context.Context, id, userID string) error
}

type Service struct {
	repo budgetRepository
}

func NewService(repo budgetRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) List(ctx context.Context, userID string, month, year int) ([]*Budget, error) {
	if month == 0 {
		month = int(time.Now().Month())
	}
	if year == 0 {
		year = time.Now().Year()
	}
	return s.repo.List(ctx, userID, month, year)
}

func (s *Service) Create(ctx context.Context, userID string, req *CreateRequest) (*Budget, error) {
	if req.CategoryID == "" {
		return nil, fmt.Errorf("category_id is required")
	}
	if req.Amount <= 0 {
		return nil, fmt.Errorf("amount must be greater than 0")
	}
	if req.Month < 1 || req.Month > 12 {
		return nil, fmt.Errorf("invalid month")
	}
	if req.Year < 2000 {
		return nil, fmt.Errorf("invalid year")
	}

	b := &Budget{
		UserID:     userID,
		CategoryID: req.CategoryID,
		Amount:     req.Amount,
		Month:      req.Month,
		Year:       req.Year,
	}

	if err := s.repo.Create(ctx, b); err != nil {
		return nil, fmt.Errorf("create budget: %w", err)
	}
	return b, nil
}

func (s *Service) Update(ctx context.Context, id, userID string, req *UpdateRequest) (*Budget, error) {
	if req.Amount <= 0 {
		return nil, fmt.Errorf("amount must be greater than 0")
	}

	b, err := s.repo.Update(ctx, id, userID, req.Amount)
	if err != nil {
		return nil, fmt.Errorf("update budget: %w", err)
	}
	if b == nil {
		return nil, fmt.Errorf("budget not found")
	}
	return b, nil
}

func (s *Service) Delete(ctx context.Context, id, userID string) error {
	return s.repo.Delete(ctx, id, userID)
}
