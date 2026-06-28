package transaction

import (
	"context"
	"fmt"
)

type transactionRepository interface {
	List(ctx context.Context, userID string, f *ListFilter) (*ListResult, error)
	GetByID(ctx context.Context, id, userID string) (*Transaction, error)
	Create(ctx context.Context, t *Transaction) error
	Update(ctx context.Context, t *Transaction) error
	Delete(ctx context.Context, id, userID string) error
	ExportCSV(ctx context.Context, userID, startDate, endDate, txType string) ([]*Transaction, error)
}

type Service struct {
	repo transactionRepository
}

func NewService(repo transactionRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) List(ctx context.Context, userID string, f *ListFilter) (*ListResult, error) {
	if f.Page < 1 {
		f.Page = 1
	}
	if f.Limit < 1 {
		f.Limit = 20
	} else if f.Limit > 500 {
		f.Limit = 500
	}
	return s.repo.List(ctx, userID, f)
}

func (s *Service) GetByID(ctx context.Context, id, userID string) (*Transaction, error) {
	t, err := s.repo.GetByID(ctx, id, userID)
	if err != nil {
		return nil, fmt.Errorf("get transaction: %w", err)
	}
	if t == nil {
		return nil, fmt.Errorf("transaction not found")
	}
	return t, nil
}

func (s *Service) Create(ctx context.Context, userID string, req *CreateRequest) (*Transaction, error) {
	if err := s.validateRequest(req.CategoryID, req.Type, req.Amount, req.Date); err != nil {
		return nil, err
	}

	var catID *string
	if req.CategoryID != "" {
		catID = &req.CategoryID
	}
	var accID *string
	if req.AccountID != "" {
		accID = &req.AccountID
	}
	var toAccID *string
	if req.ToAccountID != "" {
		toAccID = &req.ToAccountID
	}

	t := &Transaction{
		UserID:      userID,
		CategoryID:  catID,
		AccountID:   accID,
		ToAccountID: toAccID,
		Type:        req.Type,
		Amount:      req.Amount,
		Description: req.Description,
		Date:        req.Date,
	}

	if err := s.repo.Create(ctx, t); err != nil {
		return nil, fmt.Errorf("create transaction: %w", err)
	}

	return s.repo.GetByID(ctx, t.ID, userID)
}

func (s *Service) Update(ctx context.Context, id, userID string, req *UpdateRequest) (*Transaction, error) {
	if err := s.validateRequest(req.CategoryID, req.Type, req.Amount, req.Date); err != nil {
		return nil, err
	}

	var catID *string
	if req.CategoryID != "" {
		catID = &req.CategoryID
	}
	var accID *string
	if req.AccountID != "" {
		accID = &req.AccountID
	}
	var toAccID *string
	if req.ToAccountID != "" {
		toAccID = &req.ToAccountID
	}

	t := &Transaction{
		ID:          id,
		UserID:      userID,
		CategoryID:  catID,
		AccountID:   accID,
		ToAccountID: toAccID,
		Type:        req.Type,
		Amount:      req.Amount,
		Description: req.Description,
		Date:        req.Date,
	}

	if err := s.repo.Update(ctx, t); err != nil {
		return nil, err
	}

	return s.repo.GetByID(ctx, id, userID)
}

func (s *Service) Delete(ctx context.Context, id, userID string) error {
	return s.repo.Delete(ctx, id, userID)
}

func (s *Service) ExportCSV(ctx context.Context, userID, startDate, endDate, txType string) ([]*Transaction, error) {
	if startDate == "" || endDate == "" {
		return nil, fmt.Errorf("start_date and end_date are required")
	}
	return s.repo.ExportCSV(ctx, userID, startDate, endDate, txType)
}

func (s *Service) validateRequest(categoryID, txType string, amount float64, date string) error {
	if txType != "income" && txType != "expense" && txType != "transfer" {
		return fmt.Errorf("type must be 'income', 'expense', or 'transfer'")
	}
	if txType != "transfer" && categoryID == "" {
		return fmt.Errorf("category_id is required")
	}
	if amount <= 0 {
		return fmt.Errorf("amount must be greater than 0")
	}
	if date == "" {
		return fmt.Errorf("date is required")
	}
	return nil
}
