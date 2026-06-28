package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setEnv(t *testing.T, key, value string) {
	t.Helper()
	t.Setenv(key, value)
}

func TestLoad_Success(t *testing.T) {
	setEnv(t, "JWT_SECRET", "test-secret-key")
	setEnv(t, "JWT_ACCESS_EXPIRY", "15m")
	setEnv(t, "JWT_REFRESH_EXPIRY", "168h")

	cfg, err := Load()
	require.NoError(t, err)
	assert.Equal(t, "test-secret-key", cfg.JWTSecret)
	assert.Equal(t, "8080", cfg.Port)
}

func TestLoad_MissingJWTSecret(t *testing.T) {
	os.Unsetenv("JWT_SECRET")

	_, err := Load()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "JWT_SECRET")
}

func TestLoad_InvalidAccessExpiry(t *testing.T) {
	setEnv(t, "JWT_SECRET", "test-secret")
	setEnv(t, "JWT_ACCESS_EXPIRY", "invalid")

	_, err := Load()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "JWT_ACCESS_EXPIRY")
}

func TestLoad_InvalidRefreshExpiry(t *testing.T) {
	setEnv(t, "JWT_SECRET", "test-secret")
	setEnv(t, "JWT_ACCESS_EXPIRY", "15m")
	setEnv(t, "JWT_REFRESH_EXPIRY", "bad")

	_, err := Load()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "JWT_REFRESH_EXPIRY")
}

func TestLoad_DefaultValues(t *testing.T) {
	setEnv(t, "JWT_SECRET", "my-secret")
	os.Unsetenv("APP_PORT")
	os.Unsetenv("APP_ENV")
	os.Unsetenv("JWT_ACCESS_EXPIRY")
	os.Unsetenv("JWT_REFRESH_EXPIRY")

	cfg, err := Load()
	require.NoError(t, err)
	assert.Equal(t, "8080", cfg.Port)
	assert.Equal(t, "development", cfg.Env)
}

func TestDSN_Format(t *testing.T) {
	cfg := &Config{
		DBHost: "localhost", DBPort: "5432",
		DBUser: "user", DBPassword: "pass",
		DBName: "db", DBSSLMode: "disable",
	}
	dsn := cfg.DSN()
	assert.Contains(t, dsn, "host=localhost")
	assert.Contains(t, dsn, "port=5432")
	assert.Contains(t, dsn, "user=user")
	assert.Contains(t, dsn, "dbname=db")
}
