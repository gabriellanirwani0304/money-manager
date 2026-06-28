package account

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) List(ctx context.Context, userID string) ([]*Account, error) {
	q := `SELECT id, user_id, name, type, COALESCE(bank_name,''), icon, color,
	             initial_balance, balance, is_active, created_at, updated_at
	      FROM accounts WHERE user_id = $1 AND is_active = TRUE
	      ORDER BY created_at ASC`

	rows, err := r.db.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	accounts := make([]*Account, 0)
	for rows.Next() {
		a := &Account{}
		if err := rows.Scan(
			&a.ID, &a.UserID, &a.Name, &a.Type, &a.BankName, &a.Icon, &a.Color,
			&a.InitialBalance, &a.Balance, &a.IsActive, &a.CreatedAt, &a.UpdatedAt,
		); err != nil {
			return nil, err
		}
		accounts = append(accounts, a)
	}
	return accounts, rows.Err()
}

func (r *Repository) GetByID(ctx context.Context, id, userID string) (*Account, error) {
	a := &Account{}
	q := `SELECT id, user_id, name, type, COALESCE(bank_name,''), icon, color,
	             initial_balance, balance, is_active, created_at, updated_at
	      FROM accounts WHERE id = $1 AND user_id = $2`
	err := r.db.QueryRow(ctx, q, id, userID).Scan(
		&a.ID, &a.UserID, &a.Name, &a.Type, &a.BankName, &a.Icon, &a.Color,
		&a.InitialBalance, &a.Balance, &a.IsActive, &a.CreatedAt, &a.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return a, err
}

func (r *Repository) Create(ctx context.Context, a *Account) error {
	q := `INSERT INTO accounts (user_id, name, type, bank_name, icon, color, initial_balance, balance)
	      VALUES ($1, $2, $3, NULLIF($4,''), $5, $6, $7, $7)
	      RETURNING id, created_at, updated_at`
	return r.db.QueryRow(ctx, q,
		a.UserID, a.Name, a.Type, a.BankName, a.Icon, a.Color, a.InitialBalance,
	).Scan(&a.ID, &a.CreatedAt, &a.UpdatedAt)
}

func (r *Repository) Update(ctx context.Context, id, userID string, req *UpdateRequest) (*Account, error) {
	a := &Account{}
	q := `UPDATE accounts SET name=$1, bank_name=NULLIF($2,''), icon=$3, color=$4, updated_at=NOW()
	      WHERE id=$5 AND user_id=$6
	      RETURNING id, user_id, name, type, COALESCE(bank_name,''), icon, color,
	                initial_balance, balance, is_active, created_at, updated_at`
	err := r.db.QueryRow(ctx, q, req.Name, req.BankName, req.Icon, req.Color, id, userID).Scan(
		&a.ID, &a.UserID, &a.Name, &a.Type, &a.BankName, &a.Icon, &a.Color,
		&a.InitialBalance, &a.Balance, &a.IsActive, &a.CreatedAt, &a.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return a, err
}

// SetBalance dipakai untuk set/adjust saldo manual
func (r *Repository) SetBalance(ctx context.Context, id, userID string, balance float64) error {
	tag, err := r.db.Exec(ctx,
		`UPDATE accounts SET balance=$1, updated_at=NOW() WHERE id=$2 AND user_id=$3`,
		balance, id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("account not found")
	}
	return nil
}

// AdjustBalance dipanggil saat transaksi dibuat/dihapus/diupdate
func (r *Repository) AdjustBalance(ctx context.Context, id string, delta float64) error {
	_, err := r.db.Exec(ctx,
		`UPDATE accounts SET balance = balance + $1, updated_at=NOW() WHERE id = $2`,
		delta, id)
	return err
}

func (r *Repository) Delete(ctx context.Context, id, userID string) error {
	// Soft delete
	tag, err := r.db.Exec(ctx,
		`UPDATE accounts SET is_active=FALSE, updated_at=NOW() WHERE id=$1 AND user_id=$2`,
		id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("account not found")
	}
	return nil
}

func (r *Repository) TotalBalance(ctx context.Context, userID string) (float64, error) {
	var total float64
	err := r.db.QueryRow(ctx,
		`SELECT COALESCE(SUM(balance), 0) FROM accounts WHERE user_id=$1 AND is_active=TRUE`,
		userID).Scan(&total)
	return total, err
}
