package main

import (
	"log"
	"net/http"

	"money-manager/internal/account"
	"money-manager/internal/auth"
	"money-manager/internal/budget"
	"money-manager/internal/category"
	"money-manager/internal/config"
	"money-manager/internal/middleware"
	"money-manager/internal/report"
	"money-manager/internal/transaction"
	"money-manager/pkg/database"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	db, err := database.NewPool(cfg.DSN())
	if err != nil {
		log.Fatalf("connect db: %v", err)
	}
	defer db.Close()
	log.Println("connected to database")

	// Repositories
	authRepo := auth.NewRepository(db)
	categoryRepo := category.NewRepository(db)
	txRepo := transaction.NewRepository(db)
	budgetRepo := budget.NewRepository(db)
	reportRepo := report.NewRepository(db)
	accountRepo := account.NewRepository(db)

	// Services
	authSvc := auth.NewService(authRepo, cfg.JWTSecret, cfg.AccessTokenExp, cfg.RefreshTokenExp)
	categorySvc := category.NewService(categoryRepo)
	txSvc := transaction.NewService(txRepo)
	budgetSvc := budget.NewService(budgetRepo)
	reportSvc := report.NewService(reportRepo)
	accountSvc := account.NewService(accountRepo)

	// Handlers
	authH := auth.NewHandler(authSvc)
	categoryH := category.NewHandler(categorySvc)
	txH := transaction.NewHandler(txSvc)
	budgetH := budget.NewHandler(budgetSvc)
	reportH := report.NewHandler(reportSvc)
	accountH := account.NewHandler(accountSvc)

	// Router
	mux := http.NewServeMux()

	// Auth (public)
	mux.HandleFunc("POST /api/v1/auth/register", authH.Register)
	mux.HandleFunc("POST /api/v1/auth/login", authH.Login)
	mux.HandleFunc("POST /api/v1/auth/refresh", authH.Refresh)

	// Authenticated middleware
	authMw := middleware.Auth(cfg.JWTSecret)

	// Auth (protected)
	mux.Handle("POST /api/v1/auth/logout", authMw(http.HandlerFunc(authH.Logout)))

	// Dashboard
	mux.Handle("GET /api/v1/dashboard", authMw(http.HandlerFunc(reportH.Dashboard)))

	// Categories
	mux.Handle("GET /api/v1/categories", authMw(http.HandlerFunc(categoryH.List)))
	mux.Handle("POST /api/v1/categories", authMw(http.HandlerFunc(categoryH.Create)))
	mux.Handle("PUT /api/v1/categories/{id}", authMw(http.HandlerFunc(categoryH.Update)))
	mux.Handle("DELETE /api/v1/categories/{id}", authMw(http.HandlerFunc(categoryH.Delete)))

	// Transactions
	mux.Handle("GET /api/v1/transactions/export", authMw(http.HandlerFunc(txH.Export)))
	mux.Handle("POST /api/v1/transactions/batch", authMw(http.HandlerFunc(txH.BatchCreate)))
	mux.Handle("GET /api/v1/transactions", authMw(http.HandlerFunc(txH.List)))
	mux.Handle("POST /api/v1/transactions", authMw(http.HandlerFunc(txH.Create)))
	mux.Handle("GET /api/v1/transactions/{id}", authMw(http.HandlerFunc(txH.GetByID)))
	mux.Handle("PUT /api/v1/transactions/{id}", authMw(http.HandlerFunc(txH.Update)))
	mux.Handle("DELETE /api/v1/transactions/{id}", authMw(http.HandlerFunc(txH.Delete)))

	// Budgets
	mux.Handle("GET /api/v1/budgets", authMw(http.HandlerFunc(budgetH.List)))
	mux.Handle("POST /api/v1/budgets", authMw(http.HandlerFunc(budgetH.Create)))
	mux.Handle("PUT /api/v1/budgets/{id}", authMw(http.HandlerFunc(budgetH.Update)))
	mux.Handle("DELETE /api/v1/budgets/{id}", authMw(http.HandlerFunc(budgetH.Delete)))

	// Reports
	mux.Handle("GET /api/v1/reports/summary", authMw(http.HandlerFunc(reportH.Summary)))
	mux.Handle("GET /api/v1/reports/monthly", authMw(http.HandlerFunc(reportH.MonthlyTrend)))
	mux.Handle("GET /api/v1/reports/by-category", authMw(http.HandlerFunc(reportH.CategoryBreakdown)))
	mux.Handle("GET /api/v1/reports/insights", authMw(http.HandlerFunc(reportH.Insights)))

	// Accounts (rekening)
	mux.Handle("GET /api/v1/accounts", authMw(http.HandlerFunc(accountH.List)))
	mux.Handle("POST /api/v1/accounts", authMw(http.HandlerFunc(accountH.Create)))
	mux.Handle("GET /api/v1/accounts/{id}", authMw(http.HandlerFunc(accountH.GetByID)))
	mux.Handle("PUT /api/v1/accounts/{id}", authMw(http.HandlerFunc(accountH.Update)))
	mux.Handle("PATCH /api/v1/accounts/{id}/balance", authMw(http.HandlerFunc(accountH.SetBalance)))
	mux.Handle("DELETE /api/v1/accounts/{id}", authMw(http.HandlerFunc(accountH.Delete)))

	handler := middleware.CORS(mux)

	addr := ":" + cfg.Port
	log.Printf("server running on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
