package category

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ---------------------------------------------------------------------------
// mock

type mockCatRepo struct {
	listFn         func(ctx context.Context, userID string, f *ListFilter) (*ListResult, error)
	getByIDFn      func(ctx context.Context, id, userID string) (*Category, error)
	createFn       func(ctx context.Context, c *Category) error
	updateFn       func(ctx context.Context, id, userID, name, icon, color string) (*Category, error)
	deleteFn       func(ctx context.Context, id, userID string) error
	existsByNameFn func(ctx context.Context, userID, name, categoryType string) (bool, error)
}

func (m *mockCatRepo) List(ctx context.Context, userID string, f *ListFilter) (*ListResult, error) {
	if m.listFn != nil {
		return m.listFn(ctx, userID, f)
	}
	return &ListResult{Categories: []*Category{}}, nil
}
func (m *mockCatRepo) GetByID(ctx context.Context, id, userID string) (*Category, error) {
	if m.getByIDFn != nil {
		return m.getByIDFn(ctx, id, userID)
	}
	return nil, nil
}
func (m *mockCatRepo) Create(ctx context.Context, c *Category) error {
	if m.createFn != nil {
		return m.createFn(ctx, c)
	}
	c.ID = "new-cat-id"
	return nil
}
func (m *mockCatRepo) Update(ctx context.Context, id, userID, name, icon, color string) (*Category, error) {
	if m.updateFn != nil {
		return m.updateFn(ctx, id, userID, name, icon, color)
	}
	return &Category{ID: id, Name: name}, nil
}
func (m *mockCatRepo) Delete(ctx context.Context, id, userID string) error {
	if m.deleteFn != nil {
		return m.deleteFn(ctx, id, userID)
	}
	return nil
}
func (m *mockCatRepo) ExistsByName(ctx context.Context, userID, name, categoryType string) (bool, error) {
	if m.existsByNameFn != nil {
		return m.existsByNameFn(ctx, userID, name, categoryType)
	}
	return false, nil
}

// ---------------------------------------------------------------------------
// List

func TestCategoryList_Delegates(t *testing.T) {
	called := false
	svc := NewService(&mockCatRepo{
		listFn: func(_ context.Context, _ string, f *ListFilter) (*ListResult, error) {
			called = true
			return &ListResult{Categories: []*Category{{ID: "c1"}}, Pagination: Pagination{Total: 1}}, nil
		},
	})
	result, err := svc.List(context.Background(), "user1", &ListFilter{Type: "expense"})
	require.NoError(t, err)
	assert.True(t, called)
	assert.Len(t, result.Categories, 1)
}

// ---------------------------------------------------------------------------
// Create

func TestCategoryCreate_Success(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	cat, err := svc.Create(context.Background(), "user1", &CreateRequest{
		Name: "Food", Type: "expense",
	})
	require.NoError(t, err)
	assert.Equal(t, "Food", cat.Name)
	assert.Equal(t, "category", cat.Icon)   // default
	assert.Equal(t, "#6366F1", cat.Color) // default
}

func TestCategoryCreate_SetsIconDefault(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	cat, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "X", Type: "income", Icon: ""})
	require.NoError(t, err)
	assert.Equal(t, "category", cat.Icon)
}

func TestCategoryCreate_SetsColorDefault(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	cat, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "X", Type: "income", Color: ""})
	require.NoError(t, err)
	assert.Equal(t, "#6366F1", cat.Color)
}

func TestCategoryCreate_EmptyName(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "   ", Type: "expense"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "name is required")
}

func TestCategoryCreate_InvalidType(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "X", Type: "invalid"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "type must be")
}

func TestCategoryCreate_ExistsByNameError(t *testing.T) {
	svc := NewService(&mockCatRepo{
		existsByNameFn: func(_ context.Context, _, _, _ string) (bool, error) {
			return false, errors.New("db error")
		},
	})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "Food", Type: "expense"})
	assert.Error(t, err)
}

func TestCategoryCreate_DuplicateName(t *testing.T) {
	svc := NewService(&mockCatRepo{
		existsByNameFn: func(_ context.Context, _, _, _ string) (bool, error) {
			return true, nil
		},
	})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "Food", Type: "expense"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "already exists")
}

func TestCategoryCreate_CreateError(t *testing.T) {
	svc := NewService(&mockCatRepo{
		createFn: func(_ context.Context, _ *Category) error {
			return errors.New("insert error")
		},
	})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "Food", Type: "expense"})
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// Update

func TestCategoryUpdate_Success(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	cat, err := svc.Update(context.Background(), "cat-1", "user1", &UpdateRequest{Name: "Updated"})
	require.NoError(t, err)
	assert.Equal(t, "Updated", cat.Name)
}

func TestCategoryUpdate_EmptyName(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	_, err := svc.Update(context.Background(), "cat-1", "user1", &UpdateRequest{Name: "  "})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "name is required")
}

func TestCategoryUpdate_UpdateError(t *testing.T) {
	svc := NewService(&mockCatRepo{
		updateFn: func(_ context.Context, _, _, _, _, _ string) (*Category, error) {
			return nil, errors.New("db error")
		},
	})
	_, err := svc.Update(context.Background(), "cat-1", "u", &UpdateRequest{Name: "Name"})
	assert.Error(t, err)
}

func TestCategoryUpdate_NotFound(t *testing.T) {
	svc := NewService(&mockCatRepo{
		updateFn: func(_ context.Context, _, _, _, _, _ string) (*Category, error) {
			return nil, nil // nil = not found
		},
	})
	_, err := svc.Update(context.Background(), "cat-1", "u", &UpdateRequest{Name: "Name"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

// ---------------------------------------------------------------------------
// Delete

func TestCategoryDelete_Success(t *testing.T) {
	svc := NewService(&mockCatRepo{})
	err := svc.Delete(context.Background(), "cat-1", "user1")
	assert.NoError(t, err)
}

func TestCategoryDelete_Error(t *testing.T) {
	svc := NewService(&mockCatRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return errors.New("has transactions")
		},
	})
	err := svc.Delete(context.Background(), "cat-1", "u")
	assert.Error(t, err)
}
