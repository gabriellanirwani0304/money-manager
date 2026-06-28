package transaction

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"money-manager/internal/account"
	"money-manager/internal/category"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// scanRow reads a full transaction row including nullable category + two optional accounts.
func scanRow(rows interface {
	Scan(...any) error
}, t *Transaction) error {
	var (
		catID, catName, catType, catIcon, catColor *string
		catIsDefault                               *bool
		accID, accName, accType, accIcon, accColor *string
		accBalance                                 *float64
		toAccID, toAccName, toAccType, toAccIcon, toAccColor *string
		toAccBalance                                          *float64
	)
	err := rows.Scan(
		&t.ID, &t.CategoryID, &t.Type, &t.Amount, &t.Description, &t.Date,
		&t.AccountID, &t.ToAccountID, &t.RecurringID, &t.CreatedAt, &t.UpdatedAt,
		&catID, &catName, &catType, &catIcon, &catColor, &catIsDefault,
		&accID, &accName, &accType, &accIcon, &accColor, &accBalance,
		&toAccID, &toAccName, &toAccType, &toAccIcon, &toAccColor, &toAccBalance,
	)
	if err != nil {
		return err
	}
	if catID != nil {
		t.Category = &category.Category{
			ID: *catID, Name: *catName, Type: *catType,
			Icon: *catIcon, Color: *catColor, IsDefault: catIsDefault != nil && *catIsDefault,
		}
	}
	if accID != nil {
		t.Account = &account.Account{ID: *accID, Name: *accName, Type: *accType, Icon: *accIcon, Color: *accColor}
		if accBalance != nil {
			t.Account.Balance = *accBalance
		}
	}
	if toAccID != nil {
		t.ToAccount = &account.Account{ID: *toAccID, Name: *toAccName, Type: *toAccType, Icon: *toAccIcon, Color: *toAccColor}
		if toAccBalance != nil {
			t.ToAccount.Balance = *toAccBalance
		}
	}
	return nil
}

const selectCols = `
	t.id, t.category_id, t.type, t.amount, COALESCE(t.description,''), t.date::text,
	t.account_id, t.to_account_id, t.recurring_id, t.created_at, t.updated_at,
	c.id, c.name, c.type, c.icon, c.color, c.is_default,
	a.id, a.name, a.type, a.icon, a.color, a.balance,
	ta.id, ta.name, ta.type, ta.icon, ta.color, ta.balance`

const selectJoins = `
	FROM transactions t
	LEFT JOIN categories c ON c.id = t.category_id
	LEFT JOIN accounts a ON a.id = t.account_id
	LEFT JOIN accounts ta ON ta.id = t.to_account_id`

func (r *Repository) List(ctx context.Context, userID string, f *ListFilter) (*ListResult, error) {
	conditions := []string{"t.user_id = $1"}
	args := []any{userID}
	idx := 2

	if f.Type != "" {
		conditions = append(conditions, fmt.Sprintf("t.type = $%d", idx))
		args = append(args, f.Type)
		idx++
	}
	if f.CategoryID != "" {
		conditions = append(conditions, fmt.Sprintf("t.category_id = $%d", idx))
		args = append(args, f.CategoryID)
		idx++
	}
	if f.AccountID != "" {
		conditions = append(conditions, fmt.Sprintf("(t.account_id = $%d OR t.to_account_id = $%d)", idx, idx))
		args = append(args, f.AccountID)
		idx++
	}
	if f.StartDate != "" {
		conditions = append(conditions, fmt.Sprintf("t.date >= $%d", idx))
		args = append(args, f.StartDate)
		idx++
	}
	if f.EndDate != "" {
		conditions = append(conditions, fmt.Sprintf("t.date <= $%d", idx))
		args = append(args, f.EndDate)
		idx++
	}
	if f.Search != "" {
		conditions = append(conditions, fmt.Sprintf("t.description ILIKE $%d", idx))
		args = append(args, "%"+f.Search+"%")
		idx++
	}

	where := strings.Join(conditions, " AND ")

	var total int
	err := r.db.QueryRow(ctx, fmt.Sprintf(`SELECT COUNT(*) FROM transactions t WHERE %s`, where), args...).Scan(&total)
	if err != nil {
		return nil, fmt.Errorf("count transactions: %w", err)
	}

	var summary Summary
	r.db.QueryRow(ctx, fmt.Sprintf(`
		SELECT
			COALESCE(SUM(CASE WHEN t.type='income' THEN t.amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN t.type='expense' THEN t.amount ELSE 0 END), 0)
		FROM transactions t WHERE %s`, where), args...).Scan(&summary.TotalIncome, &summary.TotalExpense)

	orderMap := map[string]string{
		"date_desc":   "t.date DESC, t.created_at DESC",
		"date_asc":    "t.date ASC, t.created_at ASC",
		"amount_desc": "t.amount DESC",
		"amount_asc":  "t.amount ASC",
	}
	order, ok := orderMap[f.Sort]
	if !ok {
		order = "t.date DESC, t.created_at DESC"
	}

	offset := (f.Page - 1) * f.Limit
	args = append(args, f.Limit, offset)

	q := fmt.Sprintf(`SELECT %s %s WHERE %s ORDER BY %s LIMIT $%d OFFSET $%d`,
		selectCols, selectJoins, where, order, idx, idx+1)

	rows, err := r.db.Query(ctx, q, args...)
	if err != nil {
		return nil, fmt.Errorf("query transactions: %w", err)
	}
	defer rows.Close()

	txs := make([]*Transaction, 0)
	for rows.Next() {
		t := &Transaction{}
		if err := scanRow(rows, t); err != nil {
			return nil, err
		}
		txs = append(txs, t)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	totalPages := (total + f.Limit - 1) / f.Limit
	return &ListResult{
		Transactions: txs,
		Pagination:   Pagination{Page: f.Page, Limit: f.Limit, Total: total, TotalPages: totalPages},
		Summary:      summary,
	}, nil
}

func (r *Repository) GetByID(ctx context.Context, id, userID string) (*Transaction, error) {
	q := fmt.Sprintf(`SELECT %s %s WHERE t.id = $1 AND t.user_id = $2`, selectCols, selectJoins)
	t := &Transaction{}
	err := scanRow(r.db.QueryRow(ctx, q, id, userID), t)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return t, nil
}

// Create inserts a transaction and adjusts account balances atomically.
// For transfers: debit from_account, credit to_account, no category needed.
func (r *Repository) Create(ctx context.Context, t *Transaction) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	catID := ""
	if t.CategoryID != nil {
		catID = *t.CategoryID
	}
	accID := ""
	if t.AccountID != nil {
		accID = *t.AccountID
	}
	toAccID := ""
	if t.ToAccountID != nil {
		toAccID = *t.ToAccountID
	}

	q := `INSERT INTO transactions (user_id, category_id, account_id, to_account_id, type, amount, description, date)
	      VALUES ($1, NULLIF($2::text,'')::uuid, NULLIF($3::text,'')::uuid, NULLIF($4::text,'')::uuid, $5, $6, $7, $8)
	      RETURNING id, created_at, updated_at`
	if err := tx.QueryRow(ctx, q,
		t.UserID, catID, accID, toAccID, t.Type, t.Amount, t.Description, t.Date,
	).Scan(&t.ID, &t.CreatedAt, &t.UpdatedAt); err != nil {
		return err
	}

	if t.Type == "transfer" {
		if accID != "" {
			if _, err := tx.Exec(ctx,
				`UPDATE accounts SET balance = balance - $1, updated_at=NOW() WHERE id = $2`, t.Amount, accID); err != nil {
				return err
			}
		}
		if toAccID != "" {
			if _, err := tx.Exec(ctx,
				`UPDATE accounts SET balance = balance + $1, updated_at=NOW() WHERE id = $2`, t.Amount, toAccID); err != nil {
				return err
			}
		}
	} else if accID != "" {
		delta := t.Amount
		if t.Type == "expense" {
			delta = -t.Amount
		}
		if _, err := tx.Exec(ctx,
			`UPDATE accounts SET balance = balance + $1, updated_at=NOW() WHERE id = $2`, delta, accID); err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

// Update reverses old balance adjustments then applies new ones atomically.
func (r *Repository) Update(ctx context.Context, t *Transaction) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var oldType string
	var oldAmount float64
	var oldAccID, oldToAccID *string
	err = tx.QueryRow(ctx,
		`SELECT type, amount, account_id, to_account_id FROM transactions WHERE id=$1 AND user_id=$2`,
		t.ID, t.UserID).Scan(&oldType, &oldAmount, &oldAccID, &oldToAccID)
	if errors.Is(err, pgx.ErrNoRows) {
		return errors.New("transaction not found")
	}
	if err != nil {
		return err
	}

	// Reverse old balance effect
	if oldType == "transfer" {
		if oldAccID != nil {
			tx.Exec(ctx, `UPDATE accounts SET balance = balance + $1, updated_at=NOW() WHERE id=$2`, oldAmount, *oldAccID)
		}
		if oldToAccID != nil {
			tx.Exec(ctx, `UPDATE accounts SET balance = balance - $1, updated_at=NOW() WHERE id=$2`, oldAmount, *oldToAccID)
		}
	} else if oldAccID != nil {
		oldDelta := oldAmount
		if oldType == "expense" {
			oldDelta = -oldAmount
		}
		tx.Exec(ctx, `UPDATE accounts SET balance = balance - $1, updated_at=NOW() WHERE id=$2`, oldDelta, *oldAccID)
	}

	catID := ""
	if t.CategoryID != nil {
		catID = *t.CategoryID
	}
	newAccID := ""
	if t.AccountID != nil {
		newAccID = *t.AccountID
	}
	newToAccID := ""
	if t.ToAccountID != nil {
		newToAccID = *t.ToAccountID
	}

	q := `UPDATE transactions SET category_id=NULLIF($1::text,'')::uuid, account_id=NULLIF($2::text,'')::uuid,
	             to_account_id=NULLIF($3::text,'')::uuid, type=$4, amount=$5, description=$6, date=$7, updated_at=NOW()
	      WHERE id=$8 AND user_id=$9 RETURNING updated_at`
	if err := tx.QueryRow(ctx, q,
		catID, newAccID, newToAccID, t.Type, t.Amount, t.Description, t.Date, t.ID, t.UserID,
	).Scan(&t.UpdatedAt); err != nil {
		return err
	}

	// Apply new balance effect
	if t.Type == "transfer" {
		if newAccID != "" {
			tx.Exec(ctx, `UPDATE accounts SET balance = balance - $1, updated_at=NOW() WHERE id=$2`, t.Amount, newAccID)
		}
		if newToAccID != "" {
			tx.Exec(ctx, `UPDATE accounts SET balance = balance + $1, updated_at=NOW() WHERE id=$2`, t.Amount, newToAccID)
		}
	} else if newAccID != "" {
		delta := t.Amount
		if t.Type == "expense" {
			delta = -t.Amount
		}
		tx.Exec(ctx, `UPDATE accounts SET balance = balance + $1, updated_at=NOW() WHERE id=$2`, delta, newAccID)
	}

	return tx.Commit(ctx)
}

// Delete removes a transaction and reverses its balance impact atomically.
func (r *Repository) Delete(ctx context.Context, id, userID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var txType string
	var amount float64
	var accID, toAccID *string
	err = tx.QueryRow(ctx,
		`DELETE FROM transactions WHERE id=$1 AND user_id=$2 RETURNING type, amount, account_id, to_account_id`,
		id, userID).Scan(&txType, &amount, &accID, &toAccID)
	if errors.Is(err, pgx.ErrNoRows) {
		return errors.New("transaction not found")
	}
	if err != nil {
		return err
	}

	if txType == "transfer" {
		if accID != nil {
			tx.Exec(ctx, `UPDATE accounts SET balance = balance + $1, updated_at=NOW() WHERE id=$2`, amount, *accID)
		}
		if toAccID != nil {
			tx.Exec(ctx, `UPDATE accounts SET balance = balance - $1, updated_at=NOW() WHERE id=$2`, amount, *toAccID)
		}
	} else if accID != nil {
		delta := amount
		if txType == "expense" {
			delta = -amount
		}
		tx.Exec(ctx, `UPDATE accounts SET balance = balance - $1, updated_at=NOW() WHERE id=$2`, delta, *accID)
	}

	return tx.Commit(ctx)
}

func (r *Repository) ExportCSV(ctx context.Context, userID, startDate, endDate, txType string) ([]*Transaction, error) {
	conditions := []string{"t.user_id = $1", "t.date >= $2", "t.date <= $3"}
	args := []any{userID, startDate, endDate}
	idx := 4

	if txType != "" {
		conditions = append(conditions, fmt.Sprintf("t.type = $%d", idx))
		args = append(args, txType)
	}

	q := fmt.Sprintf(`
		SELECT t.id, t.type, t.amount, COALESCE(t.description,''), t.date::text,
		       COALESCE(c.name,'Transfer'), COALESCE(a.name,''), COALESCE(ta.name,'')
		FROM transactions t
		LEFT JOIN categories c ON c.id = t.category_id
		LEFT JOIN accounts a ON a.id = t.account_id
		LEFT JOIN accounts ta ON ta.id = t.to_account_id
		WHERE %s ORDER BY t.date DESC`, strings.Join(conditions, " AND "))

	rows, err := r.db.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	txs := make([]*Transaction, 0)
	for rows.Next() {
		t := &Transaction{Category: &category.Category{}, Account: &account.Account{}}
		toAccName := ""
		if err := rows.Scan(&t.ID, &t.Type, &t.Amount, &t.Description, &t.Date,
			&t.Category.Name, &t.Account.Name, &toAccName); err != nil {
			return nil, err
		}
		if toAccName != "" {
			t.ToAccount = &account.Account{Name: toAccName}
		}
		txs = append(txs, t)
	}
	return txs, rows.Err()
}
