package budget

import (
	"context"
	"errors"

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

func (r *Repository) List(ctx context.Context, userID string, month, year int) ([]*Budget, error) {
	q := `
		SELECT
			b.id, b.category_id, b.amount, b.month, b.year, b.created_at, b.updated_at,
			c.id, c.name, c.type, c.icon, c.color, c.is_default,
			COALESCE(SUM(t.amount), 0) AS spent
		FROM budgets b
		JOIN categories c ON c.id = b.category_id
		LEFT JOIN transactions t
			ON t.category_id = b.category_id
			AND t.user_id = b.user_id
			AND t.type = 'expense'
			AND EXTRACT(MONTH FROM t.date) = b.month
			AND EXTRACT(YEAR FROM t.date) = b.year
		WHERE b.user_id = $1 AND b.month = $2 AND b.year = $3
		GROUP BY b.id, b.category_id, b.amount, b.month, b.year, b.created_at, b.updated_at,
		         c.id, c.name, c.type, c.icon, c.color, c.is_default
		ORDER BY c.name ASC`

	rows, err := r.db.Query(ctx, q, userID, month, year)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	budgets := make([]*Budget, 0)
	for rows.Next() {
		b := &Budget{Category: &category.Category{}}
		err := rows.Scan(
			&b.ID, &b.CategoryID, &b.Amount, &b.Month, &b.Year, &b.CreatedAt, &b.UpdatedAt,
			&b.Category.ID, &b.Category.Name, &b.Category.Type, &b.Category.Icon, &b.Category.Color, &b.Category.IsDefault,
			&b.Spent,
		)
		if err != nil {
			return nil, err
		}
		b.Remaining = b.Amount - b.Spent
		if b.Amount > 0 {
			b.Percentage = b.Spent / b.Amount * 100
		}
		b.Status = budgetStatus(b.Percentage)
		budgets = append(budgets, b)
	}
	return budgets, rows.Err()
}

func (r *Repository) GetByID(ctx context.Context, id, userID string) (*Budget, error) {
	b := &Budget{}
	q := `SELECT id, user_id, category_id, amount, month, year, created_at, updated_at
	      FROM budgets WHERE id = $1 AND user_id = $2`
	err := r.db.QueryRow(ctx, q, id, userID).Scan(
		&b.ID, &b.UserID, &b.CategoryID, &b.Amount, &b.Month, &b.Year, &b.CreatedAt, &b.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return b, err
}

func (r *Repository) Create(ctx context.Context, b *Budget) error {
	q := `INSERT INTO budgets (user_id, category_id, amount, month, year)
	      VALUES ($1, $2, $3, $4, $5)
	      RETURNING id, created_at, updated_at`
	return r.db.QueryRow(ctx, q, b.UserID, b.CategoryID, b.Amount, b.Month, b.Year).
		Scan(&b.ID, &b.CreatedAt, &b.UpdatedAt)
}

func (r *Repository) Update(ctx context.Context, id, userID string, amount float64) (*Budget, error) {
	b := &Budget{}
	q := `UPDATE budgets SET amount=$1, updated_at=NOW()
	      WHERE id=$2 AND user_id=$3
	      RETURNING id, user_id, category_id, amount, month, year, created_at, updated_at`
	err := r.db.QueryRow(ctx, q, amount, id, userID).Scan(
		&b.ID, &b.UserID, &b.CategoryID, &b.Amount, &b.Month, &b.Year, &b.CreatedAt, &b.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return b, err
}

func (r *Repository) Delete(ctx context.Context, id, userID string) error {
	tag, err := r.db.Exec(ctx, `DELETE FROM budgets WHERE id=$1 AND user_id=$2`, id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("budget not found")
	}
	return nil
}
