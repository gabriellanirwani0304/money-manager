package jwt

import (
	"encoding/base64"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const testSecret = "supersecrettestkey1234567890abcd"

func TestGenerate_ReturnsTokenPair(t *testing.T) {
	pair, err := Generate("user-123", testSecret, 15*time.Minute, 7*24*time.Hour)
	require.NoError(t, err)
	assert.NotEmpty(t, pair.AccessToken)
	assert.NotEmpty(t, pair.RefreshToken)
	assert.NotEqual(t, pair.AccessToken, pair.RefreshToken)
}

func TestGenerate_AccessTokenHasCorrectClaims(t *testing.T) {
	pair, err := Generate("user-abc", testSecret, 15*time.Minute, 7*24*time.Hour)
	require.NoError(t, err)

	claims, err := Validate(pair.AccessToken, testSecret)
	require.NoError(t, err)
	assert.Equal(t, "user-abc", claims.UserID)
	assert.Equal(t, "access", claims.RegisteredClaims.Subject)
}

func TestGenerate_RefreshTokenHasCorrectClaims(t *testing.T) {
	pair, err := Generate("user-abc", testSecret, 15*time.Minute, 7*24*time.Hour)
	require.NoError(t, err)

	claims, err := Validate(pair.RefreshToken, testSecret)
	require.NoError(t, err)
	assert.Equal(t, "user-abc", claims.UserID)
	assert.Equal(t, "refresh", claims.RegisteredClaims.Subject)
}

func TestValidate_Success(t *testing.T) {
	pair, err := Generate("user-xyz", testSecret, 15*time.Minute, 7*24*time.Hour)
	require.NoError(t, err)

	claims, err := Validate(pair.AccessToken, testSecret)
	require.NoError(t, err)
	assert.Equal(t, "user-xyz", claims.UserID)
}

func TestValidate_InvalidToken(t *testing.T) {
	_, err := Validate("not.a.valid.token", testSecret)
	assert.Error(t, err)
}

func TestValidate_WrongSecret(t *testing.T) {
	pair, err := Generate("user-123", testSecret, 15*time.Minute, 7*24*time.Hour)
	require.NoError(t, err)

	_, err = Validate(pair.AccessToken, "wrong-secret")
	assert.Error(t, err)
}

func TestValidate_ExpiredToken(t *testing.T) {
	pair, err := Generate("user-123", testSecret, -1*time.Second, 7*24*time.Hour)
	require.NoError(t, err)

	_, err = Validate(pair.AccessToken, testSecret)
	assert.Error(t, err)
}

func TestValidate_WrongSigningMethod(t *testing.T) {
	// Craft a token that claims RS256 signing method to trigger the method check.
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"RS256","typ":"JWT"}`))
	payload := base64.RawURLEncoding.EncodeToString([]byte(`{"sub":"access","user_id":"u1","exp":9999999999}`))
	sig := base64.RawURLEncoding.EncodeToString([]byte("fakesig"))
	tokenStr := strings.Join([]string{header, payload, sig}, ".")

	_, err := Validate(tokenStr, testSecret)
	assert.Error(t, err)
}

func TestValidate_EmptyString(t *testing.T) {
	_, err := Validate("", testSecret)
	assert.Error(t, err)
}

func TestHashToken_Deterministic(t *testing.T) {
	h1 := HashToken("some-token")
	h2 := HashToken("some-token")
	assert.Equal(t, h1, h2)
}

func TestHashToken_DifferentInputs(t *testing.T) {
	h1 := HashToken("token-a")
	h2 := HashToken("token-b")
	assert.NotEqual(t, h1, h2)
}

func TestHashToken_NotEmpty(t *testing.T) {
	h := HashToken("anything")
	assert.NotEmpty(t, h)
}
