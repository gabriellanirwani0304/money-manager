package middleware

import (
	"context"
	"net/http"
	"strings"

	"money-manager/pkg/jwt"
	"money-manager/pkg/response"
)

type contextKey string

const UserIDKey contextKey = "user_id"

func Auth(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if !strings.HasPrefix(header, "Bearer ") {
				response.Error(w, http.StatusUnauthorized, "missing or invalid token", "UNAUTHORIZED")
				return
			}

			tokenStr := strings.TrimPrefix(header, "Bearer ")
			claims, err := jwt.Validate(tokenStr, jwtSecret)
			if err != nil {
				response.Error(w, http.StatusUnauthorized, "invalid or expired token", "UNAUTHORIZED")
				return
			}

			if claims.RegisteredClaims.Subject != "access" {
				response.Error(w, http.StatusUnauthorized, "invalid token type", "UNAUTHORIZED")
				return
			}

			ctx := context.WithValue(r.Context(), UserIDKey, claims.UserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func GetUserID(r *http.Request) string {
	id, _ := r.Context().Value(UserIDKey).(string)
	return id
}
