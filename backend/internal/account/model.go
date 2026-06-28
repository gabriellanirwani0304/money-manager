package account

import "time"

type Account struct {
	ID             string    `json:"id"`
	UserID         string    `json:"-"`
	Name           string    `json:"name"`
	Type           string    `json:"type"`
	BankName       string    `json:"bank_name,omitempty"`
	Icon           string    `json:"icon"`
	Color          string    `json:"color"`
	InitialBalance float64   `json:"initial_balance"`
	Balance        float64   `json:"balance"`
	IsActive       bool      `json:"is_active"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type CreateRequest struct {
	Name           string  `json:"name"`
	Type           string  `json:"type"`
	BankName       string  `json:"bank_name"`
	Icon           string  `json:"icon"`
	Color          string  `json:"color"`
	InitialBalance float64 `json:"initial_balance"`
}

type UpdateRequest struct {
	Name     string `json:"name"`
	BankName string `json:"bank_name"`
	Icon     string `json:"icon"`
	Color    string `json:"color"`
}

var AccountTypes = map[string]struct{ Label, Icon, Color string }{
	"bank":       {Label: "Bank", Icon: "account_balance", Color: "#6C5CE7"},
	"cash":       {Label: "Tunai", Icon: "payments", Color: "#00C49A"},
	"ewallet":    {Label: "E-Wallet", Icon: "account_balance_wallet", Color: "#00B4D8"},
	"investment": {Label: "Investasi", Icon: "trending_up", Color: "#FFB300"},
	"other":      {Label: "Lainnya", Icon: "wallet", Color: "#636E72"},
}
