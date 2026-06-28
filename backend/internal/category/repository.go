package category

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) List(ctx context.Context, userID string, f *ListFilter) (*ListResult, error) {
	conditions := []string{"(user_id = $1 OR user_id IS NULL)"}
	args := []any{userID}
	idx := 2

	if f.Type != "" {
		conditions = append(conditions, fmt.Sprintf("type = $%d", idx))
		args = append(args, f.Type)
		idx++
	}
	if f.Search != "" {
		conditions = append(conditions, fmt.Sprintf("name ILIKE $%d", idx))
		args = append(args, "%"+f.Search+"%")
		idx++
	}

	where := strings.Join(conditions, " AND ")

	var total int
	err := r.db.QueryRow(ctx, fmt.Sprintf(`SELECT COUNT(*) FROM categories WHERE %s`, where), args...).Scan(&total)
	if err != nil {
		return nil, err
	}

	offset := (f.Page - 1) * f.Limit
	args = append(args, f.Limit, offset)

	q := fmt.Sprintf(`
		SELECT id, user_id, name, type, icon, color, is_default, created_at
		FROM categories
		WHERE %s
		ORDER BY is_default DESC, name ASC
		LIMIT $%d OFFSET $%d`, where, idx, idx+1)

	rows, err := r.db.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cats := make([]*Category, 0)
	for rows.Next() {
		c := &Category{}
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.Type, &c.Icon, &c.Color, &c.IsDefault, &c.CreatedAt); err != nil {
			return nil, err
		}
		cats = append(cats, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	totalPages := (total + f.Limit - 1) / f.Limit
	return &ListResult{
		Categories: cats,
		Pagination: Pagination{Page: f.Page, Limit: f.Limit, Total: total, TotalPages: totalPages},
	}, nil
}

func (r *Repository) GetByID(ctx context.Context, id, userID string) (*Category, error) {
	c := &Category{}
	q := `SELECT id, user_id, name, type, icon, color, is_default, created_at
	      FROM categories WHERE id = $1 AND (user_id = $2 OR user_id IS NULL)`
	err := r.db.QueryRow(ctx, q, id, userID).Scan(
		&c.ID, &c.UserID, &c.Name, &c.Type, &c.Icon, &c.Color, &c.IsDefault, &c.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return c, err
}

func (r *Repository) Create(ctx context.Context, c *Category) error {
	q := `INSERT INTO categories (user_id, name, type, icon, color, is_default)
	      VALUES ($1, $2, $3, $4, $5, FALSE)
	      RETURNING id, created_at`
	return r.db.QueryRow(ctx, q, c.UserID, c.Name, c.Type, c.Icon, c.Color).
		Scan(&c.ID, &c.CreatedAt)
}

func (r *Repository) Update(ctx context.Context, id, userID, name, icon, color string) (*Category, error) {
	c := &Category{}
	q := `UPDATE categories SET name=$1, icon=$2, color=$3
	      WHERE id=$4 AND user_id=$5 AND is_default=FALSE
	      RETURNING id, user_id, name, type, icon, color, is_default, created_at`
	err := r.db.QueryRow(ctx, q, name, icon, color, id, userID).Scan(
		&c.ID, &c.UserID, &c.Name, &c.Type, &c.Icon, &c.Color, &c.IsDefault, &c.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return c, err
}

func (r *Repository) Delete(ctx context.Context, id, userID string) error {
	var count int
	r.db.QueryRow(ctx, `SELECT COUNT(*) FROM transactions WHERE category_id=$1`, id).Scan(&count)
	if count > 0 {
		return errors.New("category has existing transactions")
	}

	tag, err := r.db.Exec(ctx,
		`DELETE FROM categories WHERE id=$1 AND user_id=$2 AND is_default=FALSE`, id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("category not found or cannot be deleted")
	}
	return nil
}

func (r *Repository) ExistsByName(ctx context.Context, userID, name, typ string) (bool, error) {
	var exists bool
	q := `SELECT EXISTS(SELECT 1 FROM categories WHERE user_id=$1 AND LOWER(name)=LOWER($2) AND type=$3)`
	err := r.db.QueryRow(ctx, q, userID, name, typ).Scan(&exists)
	return exists, err
}
