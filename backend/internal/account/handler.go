package account

import (
	"encoding/json"
	"net/http"
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
	accounts, err := h.svc.List(r.Context(), userID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to fetch accounts", "INTERNAL_ERROR")
		return
	}
	response.JSON(w, http.StatusOK, accounts)
}

func (h *Handler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	a, err := h.svc.GetByID(r.Context(), id, userID)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
			return
		}
		response.Error(w, http.StatusInternalServerError, "failed to get account", "INTERNAL_ERROR")
		return
	}
	response.JSON(w, http.StatusOK, a)
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req CreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	a, err := h.svc.Create(r.Context(), userID, &req)
	if err != nil {
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}
	response.JSON(w, http.StatusCreated, a)
}

func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	var req UpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	a, err := h.svc.Update(r.Context(), id, userID, &req)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
			return
		}
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}
	response.JSON(w, http.StatusOK, a)
}

func (h *Handler) SetBalance(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	var body struct {
		Balance float64 `json:"balance"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}
	if body.Balance < 0 {
		response.Error(w, http.StatusBadRequest, "balance tidak boleh negatif", "BAD_REQUEST")
		return
	}

	if err := h.svc.SetBalance(r.Context(), id, userID, body.Balance); err != nil {
		if strings.Contains(err.Error(), "not found") {
			response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
			return
		}
		response.Error(w, http.StatusInternalServerError, "failed to set balance", "INTERNAL_ERROR")
		return
	}
	response.Message(w, http.StatusOK, "Saldo berhasil diperbarui")
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	if err := h.svc.Delete(r.Context(), id, userID); err != nil {
		response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
		return
	}
	response.Message(w, http.StatusOK, "Account deleted")
}
