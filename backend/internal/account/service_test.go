package account

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ---------------------------------------------------------------------------
// mock

type mockAccRepo struct {
	listFn         func(ctx context.Context, userID string) ([]*Account, error)
	getByIDFn      func(ctx context.Context, id, userID string) (*Account, error)
	createFn       func(ctx context.Context, a *Account) error
	updateFn       func(ctx context.Context, id, userID string, req *UpdateRequest) (*Account, error)
	setBalanceFn   func(ctx context.Context, id, userID string, balance float64) error
	deleteFn       func(ctx context.Context, id, userID string) error
	totalBalanceFn func(ctx context.Context, userID string) (float64, error)
}

func (m *mockAccRepo) List(ctx context.Context, userID string) ([]*Account, error) {
	if m.listFn != nil {
		return m.listFn(ctx, userID)
	}
	return []*Account{}, nil
}
func (m *mockAccRepo) GetByID(ctx context.Context, id, userID string) (*Account, error) {
	if m.getByIDFn != nil {
		return m.getByIDFn(ctx, id, userID)
	}
	return &Account{ID: id}, nil
}
func (m *mockAccRepo) Create(ctx context.Context, a *Account) error {
	if m.createFn != nil {
		return m.createFn(ctx, a)
	}
	a.ID = "new-acc-id"
	return nil
}
func (m *mockAccRepo) Update(ctx context.Context, id, userID string, req *UpdateRequest) (*Account, error) {
	if m.updateFn != nil {
		return m.updateFn(ctx, id, userID, req)
	}
	return &Account{ID: id, Name: req.Name}, nil
}
func (m *mockAccRepo) SetBalance(ctx context.Context, id, userID string, balance float64) error {
	if m.setBalanceFn != nil {
		return m.setBalanceFn(ctx, id, userID, balance)
	}
	return nil
}
func (m *mockAccRepo) Delete(ctx context.Context, id, userID string) error {
	if m.deleteFn != nil {
		return m.deleteFn(ctx, id, userID)
	}
	return nil
}
func (m *mockAccRepo) TotalBalance(ctx context.Context, userID string) (float64, error) {
	if m.totalBalanceFn != nil {
		return m.totalBalanceFn(ctx, userID)
	}
	return 0, nil
}

// ---------------------------------------------------------------------------
// List

func TestAccList_Delegates(t *testing.T) {
	called := false
	svc := NewService(&mockAccRepo{
		listFn: func(_ context.Context, _ string) ([]*Account, error) {
			called = true
			return []*Account{{ID: "a1"}}, nil
		},
	})
	accounts, err := svc.List(context.Background(), "user-1")
	require.NoError(t, err)
	assert.True(t, called)
	assert.Len(t, accounts, 1)
}

// ---------------------------------------------------------------------------
// GetByID

func TestAccGetByID_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{
		getByIDFn: func(_ context.Context, id, _ string) (*Account, error) {
			return &Account{ID: id, Name: "BCA"}, nil
		},
	})
	a, err := svc.GetByID(context.Background(), "acc-1", "user-1")
	require.NoError(t, err)
	assert.Equal(t, "BCA", a.Name)
}

func TestAccGetByID_NotFound(t *testing.T) {
	svc := NewService(&mockAccRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*Account, error) { return nil, nil },
	})
	_, err := svc.GetByID(context.Background(), "acc-1", "u")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestAccGetByID_RepoError(t *testing.T) {
	svc := NewService(&mockAccRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*Account, error) { return nil, errors.New("db") },
	})
	_, err := svc.GetByID(context.Background(), "acc-1", "u")
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// Create

func TestAccCreate_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	a, err := svc.Create(context.Background(), "u", &CreateRequest{
		Name: "My BCA", Type: "bank",
	})
	require.NoError(t, err)
	assert.Equal(t, "new-acc-id", a.ID)
	assert.Equal(t, "account_balance", a.Icon)   // default from AccountTypes["bank"]
	assert.Equal(t, "#6C5CE7", a.Color)
}

func TestAccCreate_EmptyName(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "  ", Type: "bank"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "harus diisi")
}

func TestAccCreate_InvalidTypeFallsToBank(t *testing.T) {
	var savedType string
	svc := NewService(&mockAccRepo{
		createFn: func(_ context.Context, a *Account) error {
			savedType = a.Type
			a.ID = "id"
			return nil
		},
	})
	_, _ = svc.Create(context.Background(), "u", &CreateRequest{Name: "X", Type: "unknown"})
	assert.Equal(t, "bank", savedType)
}

func TestAccCreate_CustomIconAndColorPreserved(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	a, err := svc.Create(context.Background(), "u", &CreateRequest{
		Name: "GoPay", Type: "ewallet", Icon: "my_icon", Color: "#AABBCC",
	})
	require.NoError(t, err)
	assert.Equal(t, "my_icon", a.Icon)
	assert.Equal(t, "#AABBCC", a.Color)
}

func TestAccCreate_DefaultIconForUnknownTypeOk(t *testing.T) {
	// Even after fallback to "bank", icon default applies
	svc := NewService(&mockAccRepo{})
	a, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "X", Type: "nope"})
	require.NoError(t, err)
	assert.Equal(t, "bank", a.Type)
	assert.NotEmpty(t, a.Icon)
}

func TestAccCreate_RepoError(t *testing.T) {
	svc := NewService(&mockAccRepo{
		createFn: func(_ context.Context, _ *Account) error { return errors.New("db error") },
	})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "X", Type: "cash"})
	assert.Error(t, err)
}

func TestAccCreate_AllAccountTypes(t *testing.T) {
	for typeName := range AccountTypes {
		t.Run(typeName, func(t *testing.T) {
			svc := NewService(&mockAccRepo{})
			a, err := svc.Create(context.Background(), "u", &CreateRequest{Name: "Acc", Type: typeName})
			require.NoError(t, err)
			assert.Equal(t, typeName, a.Type)
		})
	}
}

// ---------------------------------------------------------------------------
// Update

func TestAccUpdate_Success(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	a, err := svc.Update(context.Background(), "acc-1", "u", &UpdateRequest{Name: "New Name"})
	require.NoError(t, err)
	assert.Equal(t, "New Name", a.Name)
}

func TestAccUpdate_EmptyName(t *testing.T) {
	svc := NewService(&mockAccRepo{})
	_, err := svc.Update(context.Background(), "acc-1", "u", &UpdateRequest{Name: "  "})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "harus diisi")
}

func TestAccUpdate_NotFound(t *testing.T) {
	svc := NewService(&mockAccRepo{
		updateFn: func(_ context.Context, _, _ string, _ *UpdateRequest) (*Account, error) { return nil, nil },
	})
	_, err := svc.Update(context.Background(), "acc-1", "u", &UpdateRequest{Name: "Name"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestAccUpdate_RepoError(t *testing.T) {
	svc := NewService(&mockAccRepo{
		updateFn: func(_ context.Context, _, _ string, _ *UpdateRequest) (*Account, error) {
			return nil, errors.New("db error")
		},
	})
	_, err := svc.Update(context.Background(), "acc-1", "u", &UpdateRequest{Name: "Name"})
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// SetBalance / Delete / TotalBalance

func TestAccSetBalance_Delegates(t *testing.T) {
	called := false
	svc := NewService(&mockAccRepo{
		setBalanceFn: func(_ context.Context, _, _ string, _ float64) error {
			called = true
			return nil
		},
	})
	err := svc.SetBalance(context.Background(), "acc-1", "u", 100000)
	require.NoError(t, err)
	assert.True(t, called)
}

func TestAccDelete_Delegates(t *testing.T) {
	called := false
	svc := NewService(&mockAccRepo{
		deleteFn: func(_ context.Context, _, _ string) error { called = true; return nil },
	})
	err := svc.Delete(context.Background(), "acc-1", "u")
	require.NoError(t, err)
	assert.True(t, called)
}

func TestAccTotalBalance_Returns(t *testing.T) {
	svc := NewService(&mockAccRepo{
		totalBalanceFn: func(_ context.Context, _ string) (float64, error) { return 999999, nil },
	})
	total, err := svc.TotalBalance(context.Background(), "u")
	require.NoError(t, err)
	assert.Equal(t, 999999.0, total)
}
