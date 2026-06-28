package report

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) MonthlySummary(ctx context.Context, userID string, month, year int) (*MonthlySummary, error) {
	s := &MonthlySummary{Month: month, Year: year}
	q := `
		SELECT
			COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0),
			COUNT(*) FILTER (WHERE type != 'transfer')
		FROM transactions
		WHERE user_id = $1
		  AND type != 'transfer'
		  AND EXTRACT(MONTH FROM date) = $2
		  AND EXTRACT(YEAR FROM date) = $3`

	err := r.db.QueryRow(ctx, q, userID, month, year).Scan(&s.Income, &s.Expense, &s.TransactionCount)
	if err != nil {
		return nil, err
	}

	s.Balance = s.Income - s.Expense

	daysInMonth := time.Date(year, time.Month(month+1), 0, 0, 0, 0, 0, time.UTC).Day()
	if daysInMonth > 0 {
		s.AvgDailyExpense = s.Expense / float64(daysInMonth)
	}

	return s, nil
}

func (r *Repository) MonthlyTrend(ctx context.Context, userID string) ([]*MonthlyTrend, error) {
	q := `
		SELECT
			TO_CHAR(DATE_TRUNC('month', date), 'YYYY-MM') AS month,
			COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0)
		FROM transactions
		WHERE user_id = $1
		  AND type != 'transfer'
		  AND date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '5 months'
		GROUP BY DATE_TRUNC('month', date)
		ORDER BY DATE_TRUNC('month', date) ASC`

	rows, err := r.db.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	trends := make([]*MonthlyTrend, 0)
	for rows.Next() {
		t := &MonthlyTrend{}
		if err := rows.Scan(&t.Month, &t.Income, &t.Expense); err != nil {
			return nil, err
		}
		trends = append(trends, t)
	}
	return trends, rows.Err()
}

func (r *Repository) CategoryBreakdown(ctx context.Context, userID string, month, year int, txType string) ([]*CategoryBreakdown, error) {
	q := `
		SELECT
			c.id, c.name, c.icon, c.color,
			SUM(t.amount) AS total,
			COUNT(*) AS cnt,
			ROUND(SUM(t.amount) / NULLIF(SUM(SUM(t.amount)) OVER (), 0) * 100, 2) AS pct
		FROM transactions t
		JOIN categories c ON c.id = t.category_id
		WHERE t.user_id = $1 AND t.type = $2
		  AND EXTRACT(MONTH FROM t.date) = $3
		  AND EXTRACT(YEAR FROM t.date) = $4
		GROUP BY c.id, c.name, c.icon, c.color
		ORDER BY total DESC`

	rows, err := r.db.Query(ctx, q, userID, txType, month, year)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	breakdown := make([]*CategoryBreakdown, 0)
	for rows.Next() {
		b := &CategoryBreakdown{}
		err := rows.Scan(&b.Category.ID, &b.Category.Name, &b.Category.Icon, &b.Category.Color,
			&b.Amount, &b.Count, &b.Percentage)
		if err != nil {
			return nil, err
		}
		breakdown = append(breakdown, b)
	}
	return breakdown, rows.Err()
}

func (r *Repository) Insights(ctx context.Context, userID string, month, year int) (*Insights, error) {
	ins := &Insights{}

	// Top expense category
	top := &TopCategory{}
	err := r.db.QueryRow(ctx, `
		SELECT c.name, SUM(t.amount),
		       ROUND(SUM(t.amount) / NULLIF((SELECT SUM(amount) FROM transactions
		           WHERE user_id=$1 AND type='expense'
		           AND EXTRACT(MONTH FROM date)=$2 AND EXTRACT(YEAR FROM date)=$3), 0) * 100, 2)
		FROM transactions t
		JOIN categories c ON c.id = t.category_id
		WHERE t.user_id=$1 AND t.type='expense'
		  AND EXTRACT(MONTH FROM t.date)=$2 AND EXTRACT(YEAR FROM t.date)=$3
		GROUP BY c.name ORDER BY SUM(t.amount) DESC LIMIT 1`,
		userID, month, year,
	).Scan(&top.CategoryName, &top.Amount, &top.Percentage)
	if err == nil {
		ins.TopExpenseCategory = top
	}

	// Biggest single expense
	big := &BiggestExpense{}
	err = r.db.QueryRow(ctx, `
		SELECT t.amount, COALESCE(t.description,''), t.date::text, c.name
		FROM transactions t JOIN categories c ON c.id=t.category_id
		WHERE t.user_id=$1 AND t.type='expense'
		  AND EXTRACT(MONTH FROM t.date)=$2 AND EXTRACT(YEAR FROM t.date)=$3
		ORDER BY t.amount DESC LIMIT 1`,
		userID, month, year,
	).Scan(&big.Amount, &big.Description, &big.Date, &big.CategoryName)
	if err == nil {
		ins.BiggestSingleExpense = big
	}

	// Month over month (exclude transfers)
	var prevIncome, prevExpense, currIncome, currExpense float64
	prevMonth, prevYear := month-1, year
	if prevMonth == 0 {
		prevMonth, prevYear = 12, year-1
	}

	r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0),
		       COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END),0)
		FROM transactions WHERE user_id=$1 AND type != 'transfer'
		  AND EXTRACT(MONTH FROM date)=$2 AND EXTRACT(YEAR FROM date)=$3`,
		userID, prevMonth, prevYear).Scan(&prevIncome, &prevExpense)

	r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0),
		       COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END),0)
		FROM transactions WHERE user_id=$1 AND type != 'transfer'
		  AND EXTRACT(MONTH FROM date)=$2 AND EXTRACT(YEAR FROM date)=$3`,
		userID, month, year).Scan(&currIncome, &currExpense)

	mom := &MonthOverMonth{}
	if prevExpense > 0 {
		mom.ExpenseChangePct = (currExpense - prevExpense) / prevExpense * 100
	}
	if prevIncome > 0 {
		mom.IncomeChangePct = (currIncome - prevIncome) / prevIncome * 100
	}
	if mom.ExpenseChangePct < 0 {
		mom.Trend = "improving"
	} else if mom.ExpenseChangePct > 10 {
		mom.Trend = "worsening"
	} else {
		mom.Trend = "stable"
	}
	ins.MonthOverMonth = mom

	// Budget exceeded
	rows, err := r.db.Query(ctx, `
		SELECT c.name
		FROM budgets b JOIN categories c ON c.id=b.category_id
		LEFT JOIN transactions t ON t.category_id=b.category_id AND t.user_id=b.user_id AND t.type='expense'
		    AND EXTRACT(MONTH FROM t.date)=b.month AND EXTRACT(YEAR FROM t.date)=b.year
		WHERE b.user_id=$1 AND b.month=$2 AND b.year=$3
		GROUP BY c.name, b.amount HAVING COALESCE(SUM(t.amount),0) > b.amount`,
		userID, month, year)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var name string
			rows.Scan(&name)
			ins.BudgetExceededCategories = append(ins.BudgetExceededCategories, name)
		}
	}

	// Savings rate
	if currIncome > 0 {
		ins.SavingsRate = (currIncome - currExpense) / currIncome * 100
	}

	return ins, nil
}

func (r *Repository) Dashboard(ctx context.Context, userID string, month, year int) (*DashboardData, error) {
	d := &DashboardData{}

	// All-time balance from account balances (exclude transfers from income/expense count)
	r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE -amount END), 0)
		FROM transactions WHERE user_id=$1 AND type != 'transfer'`, userID).Scan(&d.Balance)

	// This month income/expense (exclude transfers)
	r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0),
		       COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END),0)
		FROM transactions WHERE user_id=$1 AND type != 'transfer'
		  AND EXTRACT(MONTH FROM date)=$2 AND EXTRACT(YEAR FROM date)=$3`,
		userID, month, year).Scan(&d.Income, &d.Expense)

	// Recent 5 transactions (all types including transfer, LEFT JOIN for nullable category)
	rows, err := r.db.Query(ctx, `
		SELECT t.id, t.type, t.amount, COALESCE(t.description,''), t.date::text,
		       COALESCE(c.id::text,''), COALESCE(c.name,'Transfer'), COALESCE(c.icon,'↔'), COALESCE(c.color,'#6366f1'),
		       COALESCE(a.name,''), COALESCE(ta.name,'')
		FROM transactions t
		LEFT JOIN categories c ON c.id=t.category_id
		LEFT JOIN accounts a ON a.id=t.account_id
		LEFT JOIN accounts ta ON ta.id=t.to_account_id
		WHERE t.user_id=$1 ORDER BY t.date DESC, t.created_at DESC LIMIT 5`, userID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			rt := RecentTransaction{}
			var fromAcc, toAcc string
			rows.Scan(&rt.ID, &rt.Type, &rt.Amount, &rt.Description, &rt.Date,
				&rt.Category.ID, &rt.Category.Name, &rt.Category.Icon, &rt.Category.Color,
				&fromAcc, &toAcc)
			if rt.Type == "transfer" && toAcc != "" {
				rt.Description = fromAcc + " → " + toAcc
			}
			d.RecentTransactions = append(d.RecentTransactions, rt)
		}
	}

	// Budget alerts (>= 80%)
	alertRows, err := r.db.Query(ctx, `
		SELECT c.name, b.amount, COALESCE(SUM(t.amount),0)
		FROM budgets b JOIN categories c ON c.id=b.category_id
		LEFT JOIN transactions t ON t.category_id=b.category_id AND t.user_id=b.user_id
		    AND t.type='expense' AND EXTRACT(MONTH FROM t.date)=b.month AND EXTRACT(YEAR FROM t.date)=b.year
		WHERE b.user_id=$1 AND b.month=$2 AND b.year=$3
		GROUP BY c.name, b.amount HAVING COALESCE(SUM(t.amount),0) >= b.amount * 0.8`,
		userID, month, year)
	if err == nil {
		defer alertRows.Close()
		for alertRows.Next() {
			a := BudgetAlert{}
			alertRows.Scan(&a.CategoryName, &a.BudgetAmount, &a.Spent)
			if a.BudgetAmount > 0 {
				a.Percentage = a.Spent / a.BudgetAmount * 100
			}
			d.BudgetAlerts = append(d.BudgetAlerts, a)
		}
	}

	// Top 3 expense categories this month
	topRows, err := r.db.Query(ctx, `
		SELECT c.name, SUM(t.amount),
		       ROUND(SUM(t.amount) / NULLIF((SELECT SUM(amount) FROM transactions
		           WHERE user_id=$1 AND type='expense'
		           AND EXTRACT(MONTH FROM date)=$2 AND EXTRACT(YEAR FROM date)=$3), 0) * 100, 2)
		FROM transactions t JOIN categories c ON c.id=t.category_id
		WHERE t.user_id=$1 AND t.type='expense'
		  AND EXTRACT(MONTH FROM t.date)=$2 AND EXTRACT(YEAR FROM t.date)=$3
		GROUP BY c.name ORDER BY SUM(t.amount) DESC LIMIT 3`,
		userID, month, year)
	if err == nil {
		defer topRows.Close()
		for topRows.Next() {
			tc := TopCategory{}
			topRows.Scan(&tc.CategoryName, &tc.Amount, &tc.Percentage)
			d.TopExpenses = append(d.TopExpenses, tc)
		}
	}

	return d, nil
}
