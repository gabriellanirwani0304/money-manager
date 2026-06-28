package category

import (
	"context"
	"fmt"
	"strings"
)

type categoryRepository interface {
	List(ctx context.Context, userID string, f *ListFilter) (*ListResult, error)
	GetByID(ctx context.Context, id, userID string) (*Category, error)
	Create(ctx context.Context, c *Category) error
	Update(ctx context.Context, id, userID, name, icon, color string) (*Category, error)
	Delete(ctx context.Context, id, userID string) error
	ExistsByName(ctx context.Context, userID, name, categoryType string) (bool, error)
}

type Service struct {
	repo categoryRepository
}

func NewService(repo categoryRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) List(ctx context.Context, userID string, f *ListFilter) (*ListResult, error) {
	if f.Page < 1 {
		f.Page = 1
	}
	if f.Limit < 1 {
		f.Limit = 20
	} else if f.Limit > 200 {
		f.Limit = 200
	}
	return s.repo.List(ctx, userID, f)
}

func (s *Service) Create(ctx context.Context, userID string, req *CreateRequest) (*Category, error) {
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return nil, fmt.Errorf("name is required")
	}
	if req.Type != "income" && req.Type != "expense" {
		return nil, fmt.Errorf("type must be 'income' or 'expense'")
	}
	if req.Icon == "" {
		req.Icon = "category"
	}
	if req.Color == "" {
		req.Color = "#6366F1"
	}

	exists, err := s.repo.ExistsByName(ctx, userID, req.Name, req.Type)
	if err != nil {
		return nil, fmt.Errorf("check name: %w", err)
	}
	if exists {
		return nil, fmt.Errorf("category name already exists")
	}

	c := &Category{
		UserID: &userID,
		Name:   req.Name,
		Type:   req.Type,
		Icon:   req.Icon,
		Color:  req.Color,
	}

	if err := s.repo.Create(ctx, c); err != nil {
		return nil, fmt.Errorf("create category: %w", err)
	}
	return c, nil
}

func (s *Service) Update(ctx context.Context, id, userID string, req *UpdateRequest) (*Category, error) {
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return nil, fmt.Errorf("name is required")
	}

	c, err := s.repo.Update(ctx, id, userID, req.Name, req.Icon, req.Color)
	if err != nil {
		return nil, fmt.Errorf("update category: %w", err)
	}
	if c == nil {
		return nil, fmt.Errorf("category not found or cannot be updated")
	}
	return c, nil
}

func (s *Service) Delete(ctx context.Context, id, userID string) error {
	if err := s.repo.Delete(ctx, id, userID); err != nil {
		return err
	}
	return nil
}
