package account

import (
	"context"
	"fmt"
	"strings"
)

type accountRepository interface {
	List(ctx context.Context, userID string) ([]*Account, error)
	GetByID(ctx context.Context, id, userID string) (*Account, error)
	Create(ctx context.Context, a *Account) error
	Update(ctx context.Context, id, userID string, req *UpdateRequest) (*Account, error)
	SetBalance(ctx context.Context, id, userID string, balance float64) error
	Delete(ctx context.Context, id, userID string) error
	TotalBalance(ctx context.Context, userID string) (float64, error)
}

type Service struct {
	repo accountRepository
}

func NewService(repo accountRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) List(ctx context.Context, userID string) ([]*Account, error) {
	return s.repo.List(ctx, userID)
}

func (s *Service) GetByID(ctx context.Context, id, userID string) (*Account, error) {
	a, err := s.repo.GetByID(ctx, id, userID)
	if err != nil {
		return nil, fmt.Errorf("get account: %w", err)
	}
	if a == nil {
		return nil, fmt.Errorf("account not found")
	}
	return a, nil
}

func (s *Service) Create(ctx context.Context, userID string, req *CreateRequest) (*Account, error) {
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return nil, fmt.Errorf("nama rekening harus diisi")
	}

	validTypes := map[string]bool{"bank": true, "cash": true, "ewallet": true, "investment": true, "other": true}
	if !validTypes[req.Type] {
		req.Type = "bank"
	}

	info, ok := AccountTypes[req.Type]
	if req.Icon == "" {
		if ok {
			req.Icon = info.Icon
		} else {
			req.Icon = "account_balance"
		}
	}
	if req.Color == "" {
		if ok {
			req.Color = info.Color
		} else {
			req.Color = "#6C5CE7"
		}
	}

	a := &Account{
		UserID:         userID,
		Name:           req.Name,
		Type:           req.Type,
		BankName:       req.BankName,
		Icon:           req.Icon,
		Color:          req.Color,
		InitialBalance: req.InitialBalance,
	}

	if err := s.repo.Create(ctx, a); err != nil {
		return nil, fmt.Errorf("create account: %w", err)
	}
	return a, nil
}

func (s *Service) Update(ctx context.Context, id, userID string, req *UpdateRequest) (*Account, error) {
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return nil, fmt.Errorf("nama rekening harus diisi")
	}

	a, err := s.repo.Update(ctx, id, userID, req)
	if err != nil {
		return nil, fmt.Errorf("update account: %w", err)
	}
	if a == nil {
		return nil, fmt.Errorf("account not found")
	}
	return a, nil
}

func (s *Service) SetBalance(ctx context.Context, id, userID string, balance float64) error {
	return s.repo.SetBalance(ctx, id, userID, balance)
}

func (s *Service) Delete(ctx context.Context, id, userID string) error {
	return s.repo.Delete(ctx, id, userID)
}

func (s *Service) TotalBalance(ctx context.Context, userID string) (float64, error) {
	return s.repo.TotalBalance(ctx, userID)
}
