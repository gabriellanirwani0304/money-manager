package report

type MonthlySummary struct {
	Month            int     `json:"month"`
	Year             int     `json:"year"`
	Income           float64 `json:"income"`
	Expense          float64 `json:"expense"`
	Balance          float64 `json:"balance"`
	TransactionCount int     `json:"transaction_count"`
	AvgDailyExpense  float64 `json:"avg_daily_expense"`
}

type MonthlyTrend struct {
	Month   string  `json:"month"`
	Income  float64 `json:"income"`
	Expense float64 `json:"expense"`
}

type CategoryBreakdown struct {
	Category   CategoryInfo `json:"category"`
	Amount     float64      `json:"amount"`
	Count      int          `json:"count"`
	Percentage float64      `json:"percentage"`
}

type CategoryInfo struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Icon  string `json:"icon"`
	Color string `json:"color"`
}

type TopCategory struct {
	CategoryName string  `json:"category_name"`
	Amount       float64 `json:"amount"`
	Percentage   float64 `json:"percentage"`
}

type BiggestExpense struct {
	Amount       float64 `json:"amount"`
	Description  string  `json:"description"`
	Date         string  `json:"date"`
	CategoryName string  `json:"category_name"`
}

type MonthOverMonth struct {
	ExpenseChangePct float64 `json:"expense_change_percent"`
	IncomeChangePct  float64 `json:"income_change_percent"`
	Trend            string  `json:"trend"`
}

type Insights struct {
	TopExpenseCategory          *TopCategory    `json:"top_expense_category"`
	BiggestSingleExpense        *BiggestExpense `json:"biggest_single_expense"`
	MonthOverMonth              *MonthOverMonth `json:"month_over_month"`
	BudgetExceededCategories    []string        `json:"budget_exceeded_categories"`
	SavingsRate                 float64         `json:"savings_rate"`
}

type DashboardData struct {
	Balance            float64              `json:"balance"`
	Income             float64              `json:"income"`
	Expense            float64              `json:"expense"`
	RecentTransactions []RecentTransaction  `json:"recent_transactions"`
	BudgetAlerts       []BudgetAlert        `json:"budget_alerts"`
	TopExpenses        []TopCategory        `json:"top_expenses"`
}

type RecentTransaction struct {
	ID          string       `json:"id"`
	Type        string       `json:"type"`
	Amount      float64      `json:"amount"`
	Description string       `json:"description"`
	Date        string       `json:"date"`
	Category    CategoryInfo `json:"category"`
}

type BudgetAlert struct {
	CategoryName string  `json:"category_name"`
	BudgetAmount float64 `json:"budget_amount"`
	Spent        float64 `json:"spent"`
	Percentage   float64 `json:"percentage"`
}
