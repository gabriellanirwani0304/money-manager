package auth

import (
	"context"
	"fmt"
	"strings"
	"time"

	pkgjwt "money-manager/pkg/jwt"

	"golang.org/x/crypto/bcrypt"
)

type authRepository interface {
	CreateUser(ctx context.Context, u *User) error
	GetUserByEmail(ctx context.Context, email string) (*User, error)
	SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error
	GetRefreshToken(ctx context.Context, tokenHash string) (string, time.Time, error)
	DeleteRefreshToken(ctx context.Context, tokenHash string) error
}

type Service struct {
	repo            authRepository
	jwtSecret       string
	accessTokenExp  time.Duration
	refreshTokenExp time.Duration
}

func NewService(repo authRepository, jwtSecret string, accessExp, refreshExp time.Duration) *Service {
	return &Service{
		repo:            repo,
		jwtSecret:       jwtSecret,
		accessTokenExp:  accessExp,
		refreshTokenExp: refreshExp,
	}
}

func (s *Service) Register(ctx context.Context, req *RegisterRequest) (*AuthResponse, error) {
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	if req.Name == "" || req.Email == "" || req.Password == "" {
		return nil, fmt.Errorf("name, email, and password are required")
	}
	if len(req.Password) < 8 {
		return nil, fmt.Errorf("password must be at least 8 characters")
	}

	existing, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("check existing user: %w", err)
	}
	if existing != nil {
		return nil, fmt.Errorf("email already registered")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	currency := req.Currency
	if currency == "" {
		currency = "IDR"
	}

	user := &User{
		Name:         req.Name,
		Email:        req.Email,
		PasswordHash: string(hash),
		Currency:     currency,
	}

	if err := s.repo.CreateUser(ctx, user); err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	return s.generateAuthResponse(ctx, user)
}

func (s *Service) Login(ctx context.Context, req *LoginRequest) (*AuthResponse, error) {
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	user, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("get user: %w", err)
	}
	if user == nil {
		return nil, fmt.Errorf("invalid email or password")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, fmt.Errorf("invalid email or password")
	}

	return s.generateAuthResponse(ctx, user)
}

func (s *Service) Refresh(ctx context.Context, refreshToken string) (*TokenResponse, error) {
	claims, err := pkgjwt.Validate(refreshToken, s.jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token")
	}

	if claims.RegisteredClaims.Subject != "refresh" {
		return nil, fmt.Errorf("invalid token type")
	}

	tokenHash := pkgjwt.HashToken(refreshToken)
	userID, expiresAt, err := s.repo.GetRefreshToken(ctx, tokenHash)
	if err != nil {
		return nil, fmt.Errorf("get refresh token: %w", err)
	}
	if userID == "" || expiresAt.Before(time.Now()) {
		return nil, fmt.Errorf("refresh token expired or not found")
	}

	if err := s.repo.DeleteRefreshToken(ctx, tokenHash); err != nil {
		return nil, fmt.Errorf("delete old refresh token: %w", err)
	}

	pair, err := pkgjwt.Generate(userID, s.jwtSecret, s.accessTokenExp, s.refreshTokenExp)
	if err != nil {
		return nil, fmt.Errorf("generate tokens: %w", err)
	}

	newHash := pkgjwt.HashToken(pair.RefreshToken)
	if err := s.repo.SaveRefreshToken(ctx, userID, newHash, time.Now().Add(s.refreshTokenExp)); err != nil {
		return nil, fmt.Errorf("save refresh token: %w", err)
	}

	return &TokenResponse{AccessToken: pair.AccessToken, RefreshToken: pair.RefreshToken}, nil
}

func (s *Service) Logout(ctx context.Context, refreshToken string) error {
	tokenHash := pkgjwt.HashToken(refreshToken)
	return s.repo.DeleteRefreshToken(ctx, tokenHash)
}

func (s *Service) generateAuthResponse(ctx context.Context, user *User) (*AuthResponse, error) {
	pair, err := pkgjwt.Generate(user.ID, s.jwtSecret, s.accessTokenExp, s.refreshTokenExp)
	if err != nil {
		return nil, fmt.Errorf("generate tokens: %w", err)
	}

	tokenHash := pkgjwt.HashToken(pair.RefreshToken)
	if err := s.repo.SaveRefreshToken(ctx, user.ID, tokenHash, time.Now().Add(s.refreshTokenExp)); err != nil {
		return nil, fmt.Errorf("save refresh token: %w", err)
	}

	return &AuthResponse{User: user, AccessToken: pair.AccessToken, RefreshToken: pair.RefreshToken}, nil
}
