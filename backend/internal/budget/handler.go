package budget

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

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
	month, _ := strconv.Atoi(r.URL.Query().Get("month"))
	year, _ := strconv.Atoi(r.URL.Query().Get("year"))

	budgets, err := h.svc.List(r.Context(), userID, month, year)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to fetch budgets", "INTERNAL_ERROR")
		return
	}

	response.JSON(w, http.StatusOK, budgets)
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req CreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	b, err := h.svc.Create(r.Context(), userID, &req)
	if err != nil {
		if strings.Contains(err.Error(), "unique") || strings.Contains(err.Error(), "duplicate") {
			response.Error(w, http.StatusConflict, "budget already exists for this category and period", "CONFLICT")
			return
		}
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	response.JSON(w, http.StatusCreated, b)
}

func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	var req UpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	b, err := h.svc.Update(r.Context(), id, userID, &req)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
			return
		}
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	response.JSON(w, http.StatusOK, b)
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	if err := h.svc.Delete(r.Context(), id, userID); err != nil {
		response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
		return
	}

	response.Message(w, http.StatusOK, "Budget deleted")
}
