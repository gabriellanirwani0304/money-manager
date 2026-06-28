package auth

import (
	"context"
	"errors"
	"testing"
	"time"

	pkgjwt "money-manager/pkg/jwt"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const svcTestSecret = "test-service-secret-key-32chars!"

func newTestService(repo authRepository) *Service {
	return NewService(repo, svcTestSecret, 15*time.Minute, 7*24*time.Hour)
}

func genPair(t *testing.T) *pkgjwt.TokenPair {
	t.Helper()
	pair, err := pkgjwt.Generate("user-1", svcTestSecret, 15*time.Minute, 7*24*time.Hour)
	require.NoError(t, err)
	return pair
}

// ---------------------------------------------------------------------------
// mock

type mockAuthRepo struct {
	createUserFn         func(ctx context.Context, u *User) error
	getUserByEmailFn     func(ctx context.Context, email string) (*User, error)
	saveRefreshTokenFn   func(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error
	getRefreshTokenFn    func(ctx context.Context, tokenHash string) (string, time.Time, error)
	deleteRefreshTokenFn func(ctx context.Context, tokenHash string) error
}

func (m *mockAuthRepo) CreateUser(ctx context.Context, u *User) error {
	if m.createUserFn != nil {
		return m.createUserFn(ctx, u)
	}
	u.ID = "generated-user-id"
	return nil
}
func (m *mockAuthRepo) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	if m.getUserByEmailFn != nil {
		return m.getUserByEmailFn(ctx, email)
	}
	return nil, nil
}
func (m *mockAuthRepo) SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	if m.saveRefreshTokenFn != nil {
		return m.saveRefreshTokenFn(ctx, userID, tokenHash, expiresAt)
	}
	return nil
}
func (m *mockAuthRepo) GetRefreshToken(ctx context.Context, tokenHash string) (string, time.Time, error) {
	if m.getRefreshTokenFn != nil {
		return m.getRefreshTokenFn(ctx, tokenHash)
	}
	return "", time.Time{}, nil
}
func (m *mockAuthRepo) DeleteRefreshToken(ctx context.Context, tokenHash string) error {
	if m.deleteRefreshTokenFn != nil {
		return m.deleteRefreshTokenFn(ctx, tokenHash)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Register

func TestRegister_Success(t *testing.T) {
	svc := newTestService(&mockAuthRepo{})
	res, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "alice@example.com", Password: "password123",
	})
	require.NoError(t, err)
	assert.NotEmpty(t, res.AccessToken)
	assert.NotEmpty(t, res.RefreshToken)
}

func TestRegister_MissingName(t *testing.T) {
	svc := newTestService(&mockAuthRepo{})
	_, err := svc.Register(context.Background(), &RegisterRequest{
		Email: "alice@example.com", Password: "password123",
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "required")
}

func TestRegister_MissingEmail(t *testing.T) {
	svc := newTestService(&mockAuthRepo{})
	_, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Password: "password123",
	})
	assert.Error(t, err)
}

func TestRegister_MissingPassword(t *testing.T) {
	svc := newTestService(&mockAuthRepo{})
	_, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "alice@example.com",
	})
	assert.Error(t, err)
}

func TestRegister_ShortPassword(t *testing.T) {
	svc := newTestService(&mockAuthRepo{})
	_, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "alice@example.com", Password: "short",
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "8 characters")
}

func TestRegister_EmailLowercased(t *testing.T) {
	var savedEmail string
	svc := newTestService(&mockAuthRepo{
		createUserFn: func(_ context.Context, u *User) error {
			savedEmail = u.Email
			u.ID = "id"
			return nil
		},
	})
	_, _ = svc.Register(context.Background(), &RegisterRequest{
		Name: "Bob", Email: "  BOB@EXAMPLE.COM  ", Password: "password123",
	})
	assert.Equal(t, "bob@example.com", savedEmail)
}

func TestRegister_GetEmailError(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) {
			return nil, errors.New("db error")
		},
	})
	_, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "a@example.com", Password: "password123",
	})
	assert.Error(t, err)
}

func TestRegister_EmailAlreadyRegistered(t *testing.T) {
	existing := &User{ID: "u1", Email: "a@example.com"}
	svc := newTestService(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) {
			return existing, nil
		},
	})
	_, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "a@example.com", Password: "password123",
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "already registered")
}

func TestRegister_CreateUserError(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		createUserFn: func(_ context.Context, _ *User) error {
			return errors.New("db insert error")
		},
	})
	_, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "a@example.com", Password: "password123",
	})
	assert.Error(t, err)
}

func TestRegister_SaveRefreshTokenError(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		createUserFn: func(_ context.Context, u *User) error { u.ID = "id"; return nil },
		saveRefreshTokenFn: func(_ context.Context, _, _ string, _ time.Time) error {
			return errors.New("save token error")
		},
	})
	_, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "a@example.com", Password: "password123",
	})
	assert.Error(t, err)
}

func TestRegister_DefaultCurrency(t *testing.T) {
	var savedCurrency string
	svc := newTestService(&mockAuthRepo{
		createUserFn: func(_ context.Context, u *User) error {
			savedCurrency = u.Currency
			u.ID = "id"
			return nil
		},
	})
	_, _ = svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "a@example.com", Password: "password123",
	})
	assert.Equal(t, "IDR", savedCurrency)
}

// ---------------------------------------------------------------------------
// Login

func TestLogin_Success(t *testing.T) {
	// Register first to get a real bcrypt hash, then log in with same password.
	svc := newTestService(&mockAuthRepo{
		createUserFn: func(_ context.Context, u *User) error { u.ID = "u1"; return nil },
	})
	res, err := svc.Register(context.Background(), &RegisterRequest{
		Name: "Alice", Email: "a@example.com", Password: "password123",
	})
	require.NoError(t, err)
	hash := res.User.PasswordHash

	svc2 := newTestService(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) {
			return &User{ID: "u1", Email: "a@example.com", PasswordHash: hash}, nil
		},
	})
	resp, err := svc2.Login(context.Background(), &LoginRequest{Email: "a@example.com", Password: "password123"})
	require.NoError(t, err)
	assert.NotEmpty(t, resp.AccessToken)
}

func TestLogin_UserNotFound(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) { return nil, nil },
	})
	_, err := svc.Login(context.Background(), &LoginRequest{Email: "a@example.com", Password: "pw"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "invalid email or password")
}

func TestLogin_GetUserError(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) {
			return nil, errors.New("db error")
		},
	})
	_, err := svc.Login(context.Background(), &LoginRequest{Email: "a@example.com", Password: "pw"})
	assert.Error(t, err)
}

func TestLogin_WrongPassword(t *testing.T) {
	// bcrypt hash of "password123" with cost 12
	hash := "$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/oqVjmTcV2"
	svc := newTestService(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, _ string) (*User, error) {
			return &User{ID: "u1", Email: "a@example.com", PasswordHash: hash}, nil
		},
	})
	_, err := svc.Login(context.Background(), &LoginRequest{Email: "a@example.com", Password: "wrongpassword"})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "invalid email or password")
}

func TestLogin_EmailLowercased(t *testing.T) {
	var queriedEmail string
	svc := newTestService(&mockAuthRepo{
		getUserByEmailFn: func(_ context.Context, email string) (*User, error) {
			queriedEmail = email
			return nil, nil
		},
	})
	_, _ = svc.Login(context.Background(), &LoginRequest{Email: "  ALICE@EXAMPLE.COM  ", Password: "pw"})
	assert.Equal(t, "alice@example.com", queriedEmail)
}

// ---------------------------------------------------------------------------
// Refresh

func TestRefresh_InvalidToken(t *testing.T) {
	svc := newTestService(&mockAuthRepo{})
	_, err := svc.Refresh(context.Background(), "not-a-token")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "invalid refresh token")
}

func TestRefresh_WrongTokenType(t *testing.T) {
	svc := newTestService(&mockAuthRepo{})
	pair := genPair(t)
	_, err := svc.Refresh(context.Background(), pair.AccessToken) // access token instead of refresh
	require.Error(t, err)
	assert.Contains(t, err.Error(), "invalid token type")
}

func TestRefresh_GetTokenError(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getRefreshTokenFn: func(_ context.Context, _ string) (string, time.Time, error) {
			return "", time.Time{}, errors.New("db error")
		},
	})
	pair := genPair(t)
	_, err := svc.Refresh(context.Background(), pair.RefreshToken)
	assert.Error(t, err)
}

func TestRefresh_TokenNotFound(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getRefreshTokenFn: func(_ context.Context, _ string) (string, time.Time, error) {
			return "", time.Time{}, nil // empty = not found
		},
	})
	pair := genPair(t)
	_, err := svc.Refresh(context.Background(), pair.RefreshToken)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "expired or not found")
}

func TestRefresh_TokenExpired(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getRefreshTokenFn: func(_ context.Context, _ string) (string, time.Time, error) {
			return "user-1", time.Now().Add(-1 * time.Hour), nil // past expiry
		},
	})
	pair := genPair(t)
	_, err := svc.Refresh(context.Background(), pair.RefreshToken)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "expired or not found")
}

func TestRefresh_DeleteError(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getRefreshTokenFn: func(_ context.Context, _ string) (string, time.Time, error) {
			return "user-1", time.Now().Add(1 * time.Hour), nil
		},
		deleteRefreshTokenFn: func(_ context.Context, _ string) error {
			return errors.New("delete error")
		},
	})
	pair := genPair(t)
	_, err := svc.Refresh(context.Background(), pair.RefreshToken)
	assert.Error(t, err)
}

func TestRefresh_SaveNewTokenError(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getRefreshTokenFn: func(_ context.Context, _ string) (string, time.Time, error) {
			return "user-1", time.Now().Add(1 * time.Hour), nil
		},
		saveRefreshTokenFn: func(_ context.Context, _, _ string, _ time.Time) error {
			return errors.New("save error")
		},
	})
	pair := genPair(t)
	_, err := svc.Refresh(context.Background(), pair.RefreshToken)
	assert.Error(t, err)
}

func TestRefresh_Success(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		getRefreshTokenFn: func(_ context.Context, _ string) (string, time.Time, error) {
			return "user-1", time.Now().Add(1 * time.Hour), nil
		},
	})
	pair := genPair(t)
	resp, err := svc.Refresh(context.Background(), pair.RefreshToken)
	require.NoError(t, err)
	assert.NotEmpty(t, resp.AccessToken)
	assert.NotEmpty(t, resp.RefreshToken)
}

// ---------------------------------------------------------------------------
// Logout

func TestLogout_Success(t *testing.T) {
	svc := newTestService(&mockAuthRepo{})
	err := svc.Logout(context.Background(), "some-refresh-token")
	assert.NoError(t, err)
}

func TestLogout_DeleteError(t *testing.T) {
	svc := newTestService(&mockAuthRepo{
		deleteRefreshTokenFn: func(_ context.Context, _ string) error {
			return errors.New("delete error")
		},
	})
	err := svc.Logout(context.Background(), "token")
	assert.Error(t, err)
}
