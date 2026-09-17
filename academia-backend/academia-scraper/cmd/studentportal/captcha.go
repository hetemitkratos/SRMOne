package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// solveCaptcha2Captcha sends the captcha image to 2Captcha and polls for the result.
// captchaAPIURL should be the base URL (e.g. "https://2captcha.com").
// If apiKey is empty, falls back to local OCR, then manual mode.
func solveCaptcha2Captcha(apiKey, apiURL string, imageBytes []byte) (string, error) {
	if apiKey == "" || apiURL == "" {
		return solveCaptchaLocal(imageBytes)
	}
	b64Image := base64.StdEncoding.EncodeToString(imageBytes)

	// Step 1: Submit captcha to 2Captcha
	submitURL := strings.TrimRight(apiURL, "/") + "/in.php"
	form := url.Values{}
	form.Set("key", apiKey)
	form.Set("method", "base64")
	form.Set("body", b64Image)
	form.Set("json", "1")

	resp, err := http.Post(submitURL, "application/x-www-form-urlencoded", strings.NewReader(form.Encode()))
	if err != nil {
		return "", fmt.Errorf("2captcha submit request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("2captcha submit read failed: %w", err)
	}

	var submitResult struct {
		Status  int    `json:"status"`
		Request string `json:"request"`
	}
	if err := json.Unmarshal(body, &submitResult); err != nil {
		return "", fmt.Errorf("2captcha submit parse failed: %w (body: %s)", err, string(body))
	}

	if submitResult.Status != 1 {
		return "", fmt.Errorf("2captcha submit error: %s", submitResult.Request)
	}

	captchaID := submitResult.Request

	// Step 2: Poll for result (2Captcha typically takes 5-30 seconds)
	resultURL := strings.TrimRight(apiURL, "/") + "/res.php"
	maxAttempts := 30
	for attempt := 0; attempt < maxAttempts; attempt++ {
		time.Sleep(5 * time.Second)

		pollForm := url.Values{}
		pollForm.Set("key", apiKey)
		pollForm.Set("action", "get")
		pollForm.Set("id", captchaID)
		pollForm.Set("json", "1")

		pollResp, err := http.Post(resultURL, "application/x-www-form-urlencoded", strings.NewReader(pollForm.Encode()))
		if err != nil {
			return "", fmt.Errorf("2captcha poll request failed: %w", err)
		}
		defer pollResp.Body.Close()

		pollBody, err := io.ReadAll(pollResp.Body)
		if err != nil {
			return "", fmt.Errorf("2captcha poll read failed: %w", err)
		}

		var pollResult struct {
			Status  int    `json:"status"`
			Request string `json:"request"`
		}
		if err := json.Unmarshal(pollBody, &pollResult); err != nil {
			return "", fmt.Errorf("2captcha poll parse failed: %w (body: %s)", err, string(pollBody))
		}

		if pollResult.Status == 1 {
			return pollResult.Request, nil
		}

		if pollResult.Request != "CAPCHA_NOT_READY" {
			return "", fmt.Errorf("2captcha error: %s", pollResult.Request)
		}
		// CAPCHA_NOT_READY — keep polling
	}

	return "", fmt.Errorf("2captcha timeout: no result after %d attempts", maxAttempts)
}

// solveCaptchaLocal uses the local ddddocr Python script to solve the captcha image.
// Falls back to solveCaptchaManual if the script fails.
func solveCaptchaLocal(imageBytes []byte) (string, error) {
	// Save image to temp file
	tmpDir, err := os.MkdirTemp("", "sp_captcha_")
	if err != nil {
		return "", fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	imgPath := filepath.Join(tmpDir, "captcha.png")
	if err := os.WriteFile(imgPath, imageBytes, 0644); err != nil {
		return "", fmt.Errorf("failed to write captcha image: %w", err)
	}

	// Find solve_captcha.py in current or parent directories
	scriptPath := "solve_captcha.py"
	for i := 0; i < 4; i++ {
		if _, err := os.Stat(scriptPath); err == nil {
			break
		}
		scriptPath = filepath.Join("..", scriptPath)
	}

	// Try python3 first (Render/Linux), then python (Windows)
	var output []byte
	var lastErr error
	for _, py := range []string{"python3", "python"} {
		var errBuf bytes.Buffer
		cmd := exec.Command(py, scriptPath, imgPath)
		cmd.Stderr = &errBuf
		out, err := cmd.Output()
		if err == nil {
			output = out
			lastErr = nil
			break
		}
		lastErr = fmt.Errorf("%s solve_captcha.py failed: %w (stderr: %s)", py, err, strings.TrimSpace(errBuf.String()))
		// Script missing or python unavailable — no point trying again
		if ee, ok := err.(*exec.ExitError); !ok || ee.ExitCode() == 2 {
			continue
		}
	}
	if lastErr != nil {
		return "", lastErr
	}

	// Clean up the result: strip whitespace and newlines
	result := strings.TrimSpace(string(output))

	if result == "" {
		return "", fmt.Errorf("local OCR result was empty")
	}

	fmt.Fprintf(os.Stderr, "[spLogin] Local OCR result: %s\n", result)
	return result, nil
}

// solveCaptchaManual saves the captcha image to sp_captcha.png and waits
// for the user to write the answer in sp_captcha_answer.txt.
func solveCaptchaManual(imageBytes []byte) (string, error) {
	_ = os.WriteFile("sp_captcha.png", imageBytes, 0644)
	fmt.Fprintf(os.Stderr, "[spLogin] captcha image saved to sp_captcha.png — write answer to sp_captcha_answer.txt\n")

	answerFile := "sp_captcha_answer.txt"
	// Remove any stale answer
	_ = os.Remove(answerFile)

	for attempt := 0; attempt < 120; attempt++ {
		time.Sleep(2 * time.Second)
		data, err := os.ReadFile(answerFile)
		if err != nil {
			continue
		}
		answer := strings.TrimSpace(string(data))
		if answer != "" {
			_ = os.Remove(answerFile)
			return answer, nil
		}
	}
	return "", fmt.Errorf("manual captcha timeout: no answer file after %d seconds", 240)
}
