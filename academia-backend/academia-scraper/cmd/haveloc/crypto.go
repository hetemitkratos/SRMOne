package main

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"strings"
	"time"
)

const (
	ivString         = "1234567812345678"
	randomAlphabet   = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	ihavelocPrefix   = 10 // gat
	ihavelocSuffix   = 12 // Aat
	ihavelocKeySplit = 23 // wW
	ihavelocMidRand  = 6  // bat

	apiKeyRand1     = 7  // u$t
	apiKeyRand2     = 3  // f$t
	apiKeyRand3     = 5  // h$t
	apiKeyRand4     = 7  // m$t
	apiKeyRand5     = 8  // p$t
	apiKeyKeySplit1 = 11 // G3
	apiKeyKeySplit2 = 5  // X9
	apiKeyKeySplit3 = 9  // VRe

	dRandLen = 5 // o$t, c$t
)

func randomString(length int) string {
	b := make([]byte, length)
	maxN := big.NewInt(int64(len(randomAlphabet)))
	for i := range b {
		n, err := rand.Int(rand.Reader, maxN)
		if err != nil {
			b[i] = randomAlphabet[i%len(randomAlphabet)]
			continue
		}
		b[i] = randomAlphabet[n.Int64()]
	}
	return string(b)
}

func pkcs7Pad(data []byte, blockSize int) []byte {
	padding := blockSize - len(data)%blockSize
	pad := bytes.Repeat([]byte{byte(padding)}, padding)
	return append(data, pad...)
}

func aesCBCEncrypt(plaintext, key []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	iv := []byte(ivString)
	padded := pkcs7Pad(plaintext, aes.BlockSize)
	ciphertext := make([]byte, len(padded))
	mode := cipher.NewCBCEncrypter(block, iv)
	mode.CryptBlocks(ciphertext, padded)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

func aesECBEncrypt(plaintext, key []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	padded := pkcs7Pad(plaintext, aes.BlockSize)
	ciphertext := make([]byte, len(padded))
	for i := 0; i < len(padded); i += aes.BlockSize {
		block.Encrypt(ciphertext[i:i+aes.BlockSize], padded[i:i+aes.BlockSize])
	}
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// encryptToken encrypts a JWT token and obfuscates it for ihaveloc storage.
// Equivalent to JS _$t function.
func encryptToken(jwt string) string {
	key := randomString(32)
	encrypted, err := aesCBCEncrypt([]byte(jwt), []byte(key))
	if err != nil {
		return ""
	}
	return obfuscateToken(encrypted, key)
}

// obfuscateToken interleaves the key and ciphertext with random strings.
// Equivalent to JS x$t function.
// Format: [10 random][key[0:23]][6 random][ciphertext][key[23:32]][12 random]
func obfuscateToken(ciphertext, key string) string {
	r1 := randomString(ihavelocPrefix)
	r2 := randomString(ihavelocMidRand)
	r3 := randomString(ihavelocSuffix)
	keyPart1 := key[:ihavelocKeySplit]
	keyPart2 := key[ihavelocKeySplit:]
	return r1 + keyPart1 + r2 + ciphertext + keyPart2 + r3
}

// decryptToken reverses obfuscateToken and decrypts the JWT.
// Equivalent to JS S$t + AES.decrypt
func decryptToken(ihaveloc string) (string, error) {
	if len(ihaveloc) < ihavelocPrefix+ihavelocSuffix+ihavelocKeySplit+9 {
		return "", fmt.Errorf("ihaveloc too short")
	}
	e := ihaveloc[ihavelocPrefix:]
	e = e[:len(e)-ihavelocSuffix]
	keyPart1 := e[:ihavelocKeySplit]
	e = e[ihavelocKeySplit:]
	keyPart2 := e[len(e)-9:]
	e = e[:len(e)-9]
	key := keyPart1 + keyPart2

	ciphertext, err := base64.StdEncoding.DecodeString(e)
	if err != nil {
		return "", fmt.Errorf("base64 decode: %w", err)
	}

	block, err := aes.NewCipher([]byte(key))
	if err != nil {
		return "", err
	}
	iv := []byte(ivString)
	if len(ciphertext)%aes.BlockSize != 0 {
		return "", fmt.Errorf("ciphertext not multiple of block size")
	}
	plaintext := make([]byte, len(ciphertext))
	mode := cipher.NewCBCDecrypter(block, iv)
	mode.CryptBlocks(plaintext, ciphertext)

	// Remove PKCS7 padding
	if len(plaintext) > 0 {
		padding := int(plaintext[len(plaintext)-1])
		if padding > 0 && padding <= aes.BlockSize {
			plaintext = plaintext[:len(plaintext)-padding]
		}
	}
	return string(plaintext), nil
}

// generateAPIKey creates the API-KEY header value from the JWT's sub field.
// Equivalent to JS PX function.
func generateAPIKey(sub string, phaveloc int64) string {
	key := randomString(32)
	plaintext := buildAPIKeyPlaintext(sub, phaveloc)
	encrypted, err := aesECBEncrypt([]byte(plaintext), []byte(key))
	if err != nil {
		return ""
	}
	return obfuscateAPIKey(encrypted, key)
}

// buildAPIKeyPlaintext creates the plaintext for API-KEY encryption.
// Equivalent to JS d$t function.
// Format: random5#R#sub#R#timestampDiff#R#random5
func buildAPIKeyPlaintext(sub string, phaveloc int64) string {
	now := time.Now().Unix()
	diff := now - phaveloc
	r1 := randomString(dRandLen)
	r2 := randomString(dRandLen)
	return fmt.Sprintf("%s#R#%s#R#%d#R#%s", r1, sub, diff, r2)
}

// obfuscateAPIKey interleaves the key and ciphertext with random strings.
// Equivalent to JS g$t function.
// Format: [7 random][key[0:11]][3 random][key[11:16]][ciphertext][5 random][key[16:25]][7 random][key[25:32]][8 random]
func obfuscateAPIKey(ciphertext, key string) string {
	r1 := randomString(apiKeyRand1)
	r2 := randomString(apiKeyRand2)
	r3 := randomString(apiKeyRand3)
	r4 := randomString(apiKeyRand4)
	r5 := randomString(apiKeyRand5)
	keyPart1 := key[:apiKeyKeySplit1]                                                                  // key[0:11]
	keyPart2 := key[apiKeyKeySplit1 : apiKeyKeySplit1+apiKeyKeySplit2]                                 // key[11:16]
	keyPart3 := key[apiKeyKeySplit1+apiKeyKeySplit2 : apiKeyKeySplit1+apiKeyKeySplit2+apiKeyKeySplit3] // key[16:25]
	keyPart4 := key[apiKeyKeySplit1+apiKeyKeySplit2+apiKeyKeySplit3:]                                  // key[25:32]
	return r1 + keyPart1 + r2 + keyPart2 + ciphertext + r3 + keyPart3 + r4 + keyPart4 + r5
}

// extractJWTClaims extracts claims from a JWT token.
func extractJWTClaims(jwt string) (map[string]interface{}, error) {
	parts := strings.Split(jwt, ".")
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid JWT format")
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		payload, err = base64.StdEncoding.DecodeString(parts[1])
		if err != nil {
			return nil, fmt.Errorf("could not decode JWT payload: %w", err)
		}
	}
	var claims map[string]interface{}
	if err := json.Unmarshal(payload, &claims); err != nil {
		return nil, fmt.Errorf("could not parse JWT claims: %w", err)
	}
	return claims, nil
}

// extractSubFromJWT extracts the "sub" field from a JWT token.
func extractSubFromJWT(jwt string) (string, error) {
	claims, err := extractJWTClaims(jwt)
	if err != nil {
		return "", err
	}
	sub, ok := claims["sub"]
	if !ok {
		return "", fmt.Errorf("JWT missing sub claim")
	}
	subStr, ok := sub.(string)
	if !ok {
		return "", fmt.Errorf("JWT sub is not a string")
	}
	return subStr, nil
}

// extractTSFromJWT extracts the "ts" field from a JWT token as int64.
func extractTSFromJWT(jwt string) (int64, error) {
	claims, err := extractJWTClaims(jwt)
	if err != nil {
		return 0, err
	}
	ts, ok := claims["ts"]
	if !ok {
		return 0, fmt.Errorf("JWT missing ts claim")
	}
	// JSON numbers come back as float64
	switch v := ts.(type) {
	case float64:
		return int64(v), nil
	case int64:
		return v, nil
	default:
		return 0, fmt.Errorf("JWT ts is not a number")
	}
}

// extractUUIDFromJWT extracts the "uuid" field from a JWT token.
func extractUUIDFromJWT(jwt string) (string, error) {
	claims, err := extractJWTClaims(jwt)
	if err != nil {
		return "", err
	}
	uuid, ok := claims["uuid"]
	if !ok {
		return "", fmt.Errorf("JWT missing uuid claim")
	}
	uuidStr, ok := uuid.(string)
	if !ok {
		return "", fmt.Errorf("JWT uuid is not a string")
	}
	return uuidStr, nil
}
