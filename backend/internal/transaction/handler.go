package transaction

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"money-manager/internal/middleware"
	"money-manager/pkg/response"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	q := r.URL.Query()

	page, _ := strconv.Atoi(q.Get("page"))
	limit, _ := strconv.Atoi(q.Get("limit"))

	filter := &ListFilter{
		Page:       page,
		Limit:      limit,
		Type:       q.Get("type"),
		CategoryID: q.Get("category_id"),
		AccountID:  q.Get("account_id"),
		StartDate:  q.Get("start_date"),
		EndDate:    q.Get("end_date"),
		Search:     q.Get("search"),
		Sort:       q.Get("sort"),
	}

	result, err := h.svc.List(r.Context(), userID, filter)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to fetch transactions", "INTERNAL_ERROR")
		return
	}

	response.JSON(w, http.StatusOK, result)
}

func (h *Handler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	t, err := h.svc.GetByID(r.Context(), id, userID)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
			return
		}
		response.Error(w, http.StatusInternalServerError, "failed to get transaction", "INTERNAL_ERROR")
		return
	}

	response.JSON(w, http.StatusOK, t)
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req CreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	t, err := h.svc.Create(r.Context(), userID, &req)
	if err != nil {
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	response.JSON(w, http.StatusCreated, t)
}

func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	var req UpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	t, err := h.svc.Update(r.Context(), id, userID, &req)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
			return
		}
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	response.JSON(w, http.StatusOK, t)
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	if err := h.svc.Delete(r.Context(), id, userID); err != nil {
		response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
		return
	}

	response.Message(w, http.StatusOK, "Transaction deleted")
}

func (h *Handler) Export(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	q := r.URL.Query()

	txs, err := h.svc.ExportCSV(r.Context(), userID, q.Get("start_date"), q.Get("end_date"), q.Get("type"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	filename := fmt.Sprintf("transactions_%s.csv", time.Now().Format("2006-01"))
	w.Header().Set("Content-Type", "text/csv")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, filename))

	cw := csv.NewWriter(w)
	cw.Write([]string{"Date", "Type", "Category", "Account", "To_Account", "Amount", "Description"})
	for _, t := range txs {
		accountName := ""
		if t.Account != nil {
			accountName = t.Account.Name
		}
		toAccountName := ""
		if t.ToAccount != nil {
			toAccountName = t.ToAccount.Name
		}
		cw.Write([]string{t.Date, t.Type, t.Category.Name, accountName, toAccountName, fmt.Sprintf("%.0f", t.Amount), t.Description})
	}
	cw.Flush()
}

func (h *Handler) BatchCreate(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req BatchCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	if len(req.Transactions) == 0 {
		response.Error(w, http.StatusBadRequest, "no transactions provided", "BAD_REQUEST")
		return
	}
	if len(req.Transactions) > 1000 {
		response.Error(w, http.StatusBadRequest, "too many transactions (max 1000)", "BAD_REQUEST")
		return
	}

	result := &BatchCreateResult{Errors: make([]BatchError, 0)}
	for i, tx := range req.Transactions {
		if _, err := h.svc.Create(r.Context(), userID, &tx); err != nil {
			result.Failed++
			result.Errors = append(result.Errors, BatchError{Index: i, Message: err.Error()})
		} else {
			result.Imported++
		}
	}

	response.JSON(w, http.StatusOK, result)
}
