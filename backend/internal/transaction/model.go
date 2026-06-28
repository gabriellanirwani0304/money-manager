package transaction

import (
	"time"

	"money-manager/internal/account"
	"money-manager/internal/category"
)

type Transaction struct {
	ID          string             `json:"id"`
	UserID      string             `json:"user_id,omitempty"`
	CategoryID  *string            `json:"category_id"`
	Category    *category.Category `json:"category,omitempty"`
	AccountID   *string            `json:"account_id,omitempty"`
	Account     *account.Account   `json:"account,omitempty"`
	ToAccountID *string            `json:"to_account_id,omitempty"`
	ToAccount   *account.Account   `json:"to_account,omitempty"`
	Type        string             `json:"type"`
	Amount      float64            `json:"amount"`
	Description string             `json:"description,omitempty"`
	Date        string             `json:"date"`
	RecurringID *string            `json:"recurring_id,omitempty"`
	CreatedAt   time.Time          `json:"created_at"`
	UpdatedAt   time.Time          `json:"updated_at"`
}

type CreateRequest struct {
	CategoryID  string  `json:"category_id"`
	AccountID   string  `json:"account_id"`
	ToAccountID string  `json:"to_account_id"`
	Type        string  `json:"type"`
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
	Date        string  `json:"date"`
}

type UpdateRequest struct {
	CategoryID  string  `json:"category_id"`
	AccountID   string  `json:"account_id"`
	ToAccountID string  `json:"to_account_id"`
	Type        string  `json:"type"`
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
	Date        string  `json:"date"`
}

type ListFilter struct {
	Page       int
	Limit      int
	Type       string
	CategoryID string
	AccountID  string
	StartDate  string
	EndDate    string
	Search     string
	Sort       string
}

type ListResult struct {
	Transactions []*Transaction `json:"transactions"`
	Pagination   Pagination     `json:"pagination"`
	Summary      Summary        `json:"summary"`
}

type Pagination struct {
	Page       int `json:"page"`
	Limit      int `json:"limit"`
	Total      int `json:"total"`
	TotalPages int `json:"total_pages"`
}

type Summary struct {
	TotalIncome  float64 `json:"total_income"`
	TotalExpense float64 `json:"total_expense"`
}

type BatchCreateRequest struct {
	Transactions []CreateRequest `json:"transactions"`
}

type BatchError struct {
	Index   int    `json:"index"`
	Message string `json:"message"`
}

type BatchCreateResult struct {
	Imported int          `json:"imported"`
	Failed   int          `json:"failed"`
	Errors   []BatchError `json:"errors"`
}
