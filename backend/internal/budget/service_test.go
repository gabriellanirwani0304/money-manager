package budget

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ---------------------------------------------------------------------------
// mock

type mockBudgetRepo struct {
	listFn     func(ctx context.Context, userID string, month, year int) ([]*Budget, error)
	getByIDFn  func(ctx context.Context, id, userID string) (*Budget, error)
	createFn   func(ctx context.Context, b *Budget) error
	updateFn   func(ctx context.Context, id, userID string, amount float64) (*Budget, error)
	deleteFn   func(ctx context.Context, id, userID string) error
}

func (m *mockBudgetRepo) List(ctx context.Context, userID string, month, year int) ([]*Budget, error) {
	if m.listFn != nil {
		return m.listFn(ctx, userID, month, year)
	}
	return []*Budget{}, nil
}
func (m *mockBudgetRepo) GetByID(ctx context.Context, id, userID string) (*Budget, error) {
	if m.getByIDFn != nil {
		return m.getByIDFn(ctx, id, userID)
	}
	return &Budget{ID: id}, nil
}
func (m *mockBudgetRepo) Create(ctx context.Context, b *Budget) error {
	if m.createFn != nil {
		return m.createFn(ctx, b)
	}
	b.ID = "budget-id"
	return nil
}
func (m *mockBudgetRepo) Update(ctx context.Context, id, userID string, amount float64) (*Budget, error) {
	if m.updateFn != nil {
		return m.updateFn(ctx, id, userID, amount)
	}
	return &Budget{ID: id, Amount: amount}, nil
}
func (m *mockBudgetRepo) Delete(ctx context.Context, id, userID string) error {
	if m.deleteFn != nil {
		return m.deleteFn(ctx, id, userID)
	}
	return nil
}

// ---------------------------------------------------------------------------
// List

func TestBudgetList_DefaultsMonthAndYear(t *testing.T) {
	var gotMonth, gotYear int
	svc := NewService(&mockBudgetRepo{
		listFn: func(_ context.Context, _ string, m, y int) ([]*Budget, error) {
			gotMonth, gotYear = m, y
			return []*Budget{}, nil
		},
	})
	_, err := svc.List(context.Background(), "u", 0, 0)
	require.NoError(t, err)
	assert.NotZero(t, gotMonth)
	assert.NotZero(t, gotYear)
}

func TestBudgetList_UsesSupppliedMonthYear(t *testing.T) {
	var gotMonth, gotYear int
	svc := NewService(&mockBudgetRepo{
		listFn: func(_ context.Context, _ string, m, y int) ([]*Budget, error) {
			gotMonth, gotYear = m, y
			return nil, nil
		},
	})
	_, _ = svc.List(context.Background(), "u", 3, 2025)
	assert.Equal(t, 3, gotMonth)
	assert.Equal(t, 2025, gotYear)
}

// ---------------------------------------------------------------------------
// Create

func TestBudgetCreate_Success(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	b, err := svc.Create(context.Background(), "u", &CreateRequest{
		CategoryID: "cat-1", Amount: 500000, Month: 1, Year: 2025,
	})
	require.NoError(t, err)
	assert.Equal(t, "budget-id", b.ID)
}

func TestBudgetCreate_MissingCategoryID(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Amount: 100, Month: 1, Year: 2025})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "category_id")
}

func TestBudgetCreate_ZeroAmount(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Amount: 0, Month: 1, Year: 2025})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "amount")
}

func TestBudgetCreate_NegativeAmount(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Amount: -1, Month: 1, Year: 2025})
	assert.Error(t, err)
}

func TestBudgetCreate_InvalidMonth_Zero(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Amount: 100, Month: 0, Year: 2025})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "month")
}

func TestBudgetCreate_InvalidMonth_13(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Amount: 100, Month: 13, Year: 2025})
	assert.Error(t, err)
}

func TestBudgetCreate_InvalidYear(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Amount: 100, Month: 1, Year: 1999})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "year")
}

func TestBudgetCreate_RepoError(t *testing.T) {
	svc := NewService(&mockBudgetRepo{
		createFn: func(_ context.Context, _ *Budget) error { return errors.New("unique violation") },
	})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Amount: 100, Month: 1, Year: 2025})
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// Update

func TestBudgetUpdate_Success(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	b, err := svc.Update(context.Background(), "b-1", "u", &UpdateRequest{Amount: 200000})
	require.NoError(t, err)
	assert.Equal(t, 200000.0, b.Amount)
}

func TestBudgetUpdate_ZeroAmount(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	_, err := svc.Update(context.Background(), "b-1", "u", &UpdateRequest{Amount: 0})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "amount")
}

func TestBudgetUpdate_NotFound(t *testing.T) {
	svc := NewService(&mockBudgetRepo{
		updateFn: func(_ context.Context, _, _ string, _ float64) (*Budget, error) { return nil, nil },
	})
	_, err := svc.Update(context.Background(), "b-1", "u", &UpdateRequest{Amount: 100})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestBudgetUpdate_RepoError(t *testing.T) {
	svc := NewService(&mockBudgetRepo{
		updateFn: func(_ context.Context, _, _ string, _ float64) (*Budget, error) {
			return nil, errors.New("db error")
		},
	})
	_, err := svc.Update(context.Background(), "b-1", "u", &UpdateRequest{Amount: 100})
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// Delete

func TestBudgetDelete_Success(t *testing.T) {
	svc := NewService(&mockBudgetRepo{})
	err := svc.Delete(context.Background(), "b-1", "u")
	assert.NoError(t, err)
}

// ---------------------------------------------------------------------------
// budgetStatus (via List round-trip — it's used in repository but we test logic here)

func TestBudgetStatus_Safe(t *testing.T)     { assert.Equal(t, "safe", budgetStatus(50)) }
func TestBudgetStatus_Warning(t *testing.T)  { assert.Equal(t, "warning", budgetStatus(70)) }
func TestBudgetStatus_Danger(t *testing.T)   { assert.Equal(t, "danger", budgetStatus(90)) }
func TestBudgetStatus_Exceeded(t *testing.T) { assert.Equal(t, "exceeded", budgetStatus(110)) }
