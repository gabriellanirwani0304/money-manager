package budget

import (
	"time"

	"money-manager/internal/category"
)

type Budget struct {
	ID         string             `json:"id"`
	UserID     string             `json:"-"`
	CategoryID string             `json:"category_id"`
	Category   *category.Category `json:"category,omitempty"`
	Amount     float64            `json:"budget_amount"`
	Month      int                `json:"month"`
	Year       int                `json:"year"`
	Spent      float64            `json:"spent"`
	Remaining  float64            `json:"remaining"`
	Percentage float64            `json:"percentage"`
	Status     string             `json:"status"`
	CreatedAt  time.Time          `json:"created_at"`
	UpdatedAt  time.Time          `json:"updated_at"`
}

type CreateRequest struct {
	CategoryID string  `json:"category_id"`
	Amount     float64 `json:"amount"`
	Month      int     `json:"month"`
	Year       int     `json:"year"`
}

type UpdateRequest struct {
	Amount float64 `json:"amount"`
}

func budgetStatus(pct float64) string {
	switch {
	case pct > 100:
		return "exceeded"
	case pct > 80:
		return "danger"
	case pct > 60:
		return "warning"
	default:
		return "safe"
	}
}
