package report

import (
	"net/http"
	"strconv"

	"money-manager/internal/middleware"
	"money-manager/pkg/response"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) Dashboard(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	month, _ := strconv.Atoi(r.URL.Query().Get("month"))
	year, _ := strconv.Atoi(r.URL.Query().Get("year"))

	data, err := h.svc.Dashboard(r.Context(), userID, month, year)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to load dashboard", "INTERNAL_ERROR")
		return
	}

	response.JSON(w, http.StatusOK, data)
}

func (h *Handler) Summary(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	month, _ := strconv.Atoi(r.URL.Query().Get("month"))
	year, _ := strconv.Atoi(r.URL.Query().Get("year"))

	data, err := h.svc.Summary(r.Context(), userID, month, year)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to get summary", "INTERNAL_ERROR")
		return
	}

	response.JSON(w, http.StatusOK, data)
}

func (h *Handler) MonthlyTrend(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	data, err := h.svc.MonthlyTrend(r.Context(), userID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to get monthly trend", "INTERNAL_ERROR")
		return
	}

	response.JSON(w, http.StatusOK, data)
}

func (h *Handler) CategoryBreakdown(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	month, _ := strconv.Atoi(r.URL.Query().Get("month"))
	year, _ := strconv.Atoi(r.URL.Query().Get("year"))
	txType := r.URL.Query().Get("type")

	data, err := h.svc.CategoryBreakdown(r.Context(), userID, month, year, txType)
	if err != nil {
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	response.JSON(w, http.StatusOK, data)
}

func (h *Handler) Insights(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	month, _ := strconv.Atoi(r.URL.Query().Get("month"))
	year, _ := strconv.Atoi(r.URL.Query().Get("year"))

	data, err := h.svc.Insights(r.Context(), userID, month, year)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to get insights", "INTERNAL_ERROR")
		return
	}

	response.JSON(w, http.StatusOK, data)
}
