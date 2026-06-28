package category

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
	q := r.URL.Query()

	page, _ := strconv.Atoi(q.Get("page"))
	limit, _ := strconv.Atoi(q.Get("limit"))

	result, err := h.svc.List(r.Context(), userID, &ListFilter{
		Page:   page,
		Limit:  limit,
		Type:   q.Get("type"),
		Search: q.Get("search"),
	})
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to fetch categories", "INTERNAL_ERROR")
		return
	}

	response.JSON(w, http.StatusOK, result)
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req CreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	cat, err := h.svc.Create(r.Context(), userID, &req)
	if err != nil {
		if strings.Contains(err.Error(), "already exists") {
			response.Error(w, http.StatusConflict, err.Error(), "CONFLICT")
			return
		}
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	response.JSON(w, http.StatusCreated, cat)
}

func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	var req UpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	cat, err := h.svc.Update(r.Context(), id, userID, &req)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
			return
		}
		response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	response.JSON(w, http.StatusOK, cat)
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := r.PathValue("id")

	if err := h.svc.Delete(r.Context(), id, userID); err != nil {
		if strings.Contains(err.Error(), "transactions") {
			response.Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
			return
		}
		response.Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")
		return
	}

	response.Message(w, http.StatusOK, "Category deleted")
}
