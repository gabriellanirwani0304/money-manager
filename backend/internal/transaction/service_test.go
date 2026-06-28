package transaction

import (
	"context"
	"errors"
	"testing"

	"money-manager/internal/category"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ---------------------------------------------------------------------------
// mock

type mockTxRepo struct {
	listFn      func(ctx context.Context, userID string, f *ListFilter) (*ListResult, error)
	getByIDFn   func(ctx context.Context, id, userID string) (*Transaction, error)
	createFn    func(ctx context.Context, t *Transaction) error
	updateFn    func(ctx context.Context, t *Transaction) error
	deleteFn    func(ctx context.Context, id, userID string) error
	exportCSVFn func(ctx context.Context, userID, startDate, endDate, txType string) ([]*Transaction, error)
}

func (m *mockTxRepo) List(ctx context.Context, userID string, f *ListFilter) (*ListResult, error) {
	if m.listFn != nil {
		return m.listFn(ctx, userID, f)
	}
	return &ListResult{}, nil
}
func (m *mockTxRepo) GetByID(ctx context.Context, id, userID string) (*Transaction, error) {
	if m.getByIDFn != nil {
		return m.getByIDFn(ctx, id, userID)
	}
	return &Transaction{ID: id}, nil
}
func (m *mockTxRepo) Create(ctx context.Context, t *Transaction) error {
	if m.createFn != nil {
		return m.createFn(ctx, t)
	}
	t.ID = "new-tx-id"
	return nil
}
func (m *mockTxRepo) Update(ctx context.Context, t *Transaction) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, t)
	}
	return nil
}
func (m *mockTxRepo) Delete(ctx context.Context, id, userID string) error {
	if m.deleteFn != nil {
		return m.deleteFn(ctx, id, userID)
	}
	return nil
}
func (m *mockTxRepo) ExportCSV(ctx context.Context, userID, startDate, endDate, txType string) ([]*Transaction, error) {
	if m.exportCSVFn != nil {
		return m.exportCSVFn(ctx, userID, startDate, endDate, txType)
	}
	return []*Transaction{}, nil
}

// ---------------------------------------------------------------------------
// List

func TestTxList_DefaultPage(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.List(context.Background(), "u", &ListFilter{Page: 0, Limit: 0})
	require.NoError(t, err)
}

func TestTxList_LimitClamped(t *testing.T) {
	var capturedFilter *ListFilter
	svc := NewService(&mockTxRepo{
		listFn: func(_ context.Context, _ string, f *ListFilter) (*ListResult, error) {
			capturedFilter = f
			return &ListResult{}, nil
		},
	})
	_, _ = svc.List(context.Background(), "u", &ListFilter{Page: 0, Limit: 600})
	require.NotNil(t, capturedFilter)
	assert.Equal(t, 500, capturedFilter.Limit)
}

func TestTxList_ValidPageAndLimit(t *testing.T) {
	var captured *ListFilter
	svc := NewService(&mockTxRepo{
		listFn: func(_ context.Context, _ string, f *ListFilter) (*ListResult, error) {
			captured = f
			return &ListResult{}, nil
		},
	})
	_, _ = svc.List(context.Background(), "u", &ListFilter{Page: 2, Limit: 10})
	assert.Equal(t, 2, captured.Page)
	assert.Equal(t, 10, captured.Limit)
}

// ---------------------------------------------------------------------------
// GetByID

func TestTxGetByID_Success(t *testing.T) {
	svc := NewService(&mockTxRepo{
		getByIDFn: func(_ context.Context, id, _ string) (*Transaction, error) {
			return &Transaction{ID: id}, nil
		},
	})
	tx, err := svc.GetByID(context.Background(), "tx-1", "user-1")
	require.NoError(t, err)
	assert.Equal(t, "tx-1", tx.ID)
}

func TestTxGetByID_NotFound(t *testing.T) {
	svc := NewService(&mockTxRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*Transaction, error) { return nil, nil },
	})
	_, err := svc.GetByID(context.Background(), "tx-1", "user-1")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

func TestTxGetByID_RepoError(t *testing.T) {
	svc := NewService(&mockTxRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*Transaction, error) {
			return nil, errors.New("db error")
		},
	})
	_, err := svc.GetByID(context.Background(), "tx-1", "user-1")
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// Create

func TestTxCreate_Success(t *testing.T) {
	svc := NewService(&mockTxRepo{
		getByIDFn: func(_ context.Context, id, _ string) (*Transaction, error) {
			return &Transaction{ID: id, Category: &category.Category{Name: "Food"}}, nil
		},
	})
	tx, err := svc.Create(context.Background(), "user-1", &CreateRequest{
		CategoryID: "cat-1", Type: "expense", Amount: 50000, Date: "2025-01-01",
	})
	require.NoError(t, err)
	assert.NotNil(t, tx)
}

func TestTxCreate_WithAccountID(t *testing.T) {
	var capturedTx *Transaction
	svc := NewService(&mockTxRepo{
		createFn: func(_ context.Context, t *Transaction) error {
			capturedTx = t
			t.ID = "id"
			return nil
		},
		getByIDFn: func(_ context.Context, id, _ string) (*Transaction, error) {
			return &Transaction{ID: id}, nil
		},
	})
	_, _ = svc.Create(context.Background(), "u", &CreateRequest{
		CategoryID: "c", AccountID: "acc-1", Type: "income", Amount: 100, Date: "2025-01-01",
	})
	require.NotNil(t, capturedTx)
	require.NotNil(t, capturedTx.AccountID)
	assert.Equal(t, "acc-1", *capturedTx.AccountID)
}

func TestTxCreate_EmptyAccountID(t *testing.T) {
	var capturedTx *Transaction
	svc := NewService(&mockTxRepo{
		createFn: func(_ context.Context, t *Transaction) error {
			capturedTx = t
			t.ID = "id"
			return nil
		},
		getByIDFn: func(_ context.Context, id, _ string) (*Transaction, error) {
			return &Transaction{ID: id}, nil
		},
	})
	_, _ = svc.Create(context.Background(), "u", &CreateRequest{
		CategoryID: "c", AccountID: "", Type: "income", Amount: 100, Date: "2025-01-01",
	})
	assert.Nil(t, capturedTx.AccountID)
}

func TestTxCreate_MissingCategoryID(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{Type: "expense", Amount: 100, Date: "2025-01-01"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "category_id")
}

func TestTxCreate_InvalidType(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Type: "bad", Amount: 100, Date: "2025-01-01"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "type must be")
}

func TestTxCreate_ZeroAmount(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Type: "expense", Amount: 0, Date: "2025-01-01"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "amount")
}

func TestTxCreate_NegativeAmount(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Type: "expense", Amount: -1, Date: "2025-01-01"})
	assert.Error(t, err)
}

func TestTxCreate_MissingDate(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Type: "expense", Amount: 100})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "date")
}

func TestTxCreate_RepoError(t *testing.T) {
	svc := NewService(&mockTxRepo{
		createFn: func(_ context.Context, _ *Transaction) error { return errors.New("db error") },
	})
	_, err := svc.Create(context.Background(), "u", &CreateRequest{CategoryID: "c", Type: "expense", Amount: 100, Date: "2025-01-01"})
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// Update

func TestTxUpdate_Success(t *testing.T) {
	svc := NewService(&mockTxRepo{
		getByIDFn: func(_ context.Context, id, _ string) (*Transaction, error) {
			return &Transaction{ID: id}, nil
		},
	})
	tx, err := svc.Update(context.Background(), "tx-1", "u", &UpdateRequest{
		CategoryID: "c", Type: "income", Amount: 100, Date: "2025-01-01",
	})
	require.NoError(t, err)
	assert.NotNil(t, tx)
}

func TestTxUpdate_WithAccountID(t *testing.T) {
	var capturedTx *Transaction
	svc := NewService(&mockTxRepo{
		updateFn: func(_ context.Context, t *Transaction) error {
			capturedTx = t
			return nil
		},
		getByIDFn: func(_ context.Context, id, _ string) (*Transaction, error) {
			return &Transaction{ID: id}, nil
		},
	})
	_, _ = svc.Update(context.Background(), "tx-1", "u", &UpdateRequest{
		CategoryID: "c", AccountID: "acc-1", Type: "expense", Amount: 100, Date: "2025-01-01",
	})
	require.NotNil(t, capturedTx)
	require.NotNil(t, capturedTx.AccountID)
	assert.Equal(t, "acc-1", *capturedTx.AccountID)
}

func TestTxUpdate_ValidationError(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.Update(context.Background(), "tx-1", "u", &UpdateRequest{
		CategoryID: "", Type: "income", Amount: 100, Date: "2025-01-01",
	})
	assert.Error(t, err)
}

func TestTxUpdate_RepoError(t *testing.T) {
	svc := NewService(&mockTxRepo{
		updateFn: func(_ context.Context, _ *Transaction) error { return errors.New("not found") },
	})
	_, err := svc.Update(context.Background(), "tx-1", "u", &UpdateRequest{
		CategoryID: "c", Type: "expense", Amount: 100, Date: "2025-01-01",
	})
	assert.Error(t, err)
}

// ---------------------------------------------------------------------------
// Delete

func TestTxDelete_Success(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	err := svc.Delete(context.Background(), "tx-1", "u")
	assert.NoError(t, err)
}

// ---------------------------------------------------------------------------
// ExportCSV

func TestTxExportCSV_MissingDates(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.ExportCSV(context.Background(), "u", "", "2025-01-31", "expense")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "start_date and end_date")
}

func TestTxExportCSV_MissingEndDate(t *testing.T) {
	svc := NewService(&mockTxRepo{})
	_, err := svc.ExportCSV(context.Background(), "u", "2025-01-01", "", "expense")
	assert.Error(t, err)
}

func TestTxExportCSV_Success(t *testing.T) {
	svc := NewService(&mockTxRepo{
		exportCSVFn: func(_ context.Context, _, _, _, _ string) ([]*Transaction, error) {
			return []*Transaction{{ID: "t1"}}, nil
		},
	})
	txs, err := svc.ExportCSV(context.Background(), "u", "2025-01-01", "2025-01-31", "")
	require.NoError(t, err)
	assert.Len(t, txs, 1)
}
