package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

func main() {
	var req SPRequest
	if err := json.NewDecoder(os.Stdin).Decode(&req); err != nil {
		writeSPJSON(SPResponse{
			Success:        false,
			Classification: spClassUnknown,
			Error:          "could not decode stdin JSON: " + err.Error(),
		})
		os.Exit(1)
	}

	mode := spNormalizeMode(req)
	if strings.TrimSpace(req.Email) == "" {
		writeSPJSON(SPResponse{
			Success:        false,
			Classification: spClassUnknown,
			Error:          "email is required",
		})
		os.Exit(1)
	}
	if mode != spModeFetch && strings.TrimSpace(req.Password) == "" {
		writeSPJSON(SPResponse{
			Success:        false,
			Classification: spClassUnknown,
			Error:          "password is required for login modes",
		})
		os.Exit(1)
	}

	result := spRun(req, mode)
	writeSPJSON(result)
	if !result.Success {
		os.Exit(1)
	}
}

func writeSPJSON(v SPResponse) {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		fmt.Fprintln(os.Stderr, "could not encode JSON:", err)
	}
}

func spNormalizeMode(req SPRequest) string {
	switch strings.ToLower(strings.TrimSpace(req.Mode)) {
	case spModeLogin, spModeFetch, spModeLoginAndFetch:
		return strings.ToLower(strings.TrimSpace(req.Mode))
	}
	if len(req.Cookies) > 0 && strings.TrimSpace(req.Password) == "" {
		return spModeFetch
	}
	return spModeLoginAndFetch
}

func spRun(req SPRequest, mode string) SPResponse {
	client := NewSPClient()

	// Seed cookies for fetch mode
	if mode == spModeFetch && len(req.Cookies) > 0 {
		cookieMap := make(map[string]string)
		for _, c := range req.Cookies {
			if c.Name != "" {
				cookieMap[c.Name] = c.Value
			}
		}
		client.jar.SeedCookies(cookieMap)
	}

	resp := SPResponse{Classification: spClassUnknown}

	if mode == spModeFetch {
		// Just fetch data with existing cookies
		attendance, studentInfo, err := spFetchAttendance(client, "")
		if err != nil {
			resp.Error = err.Error()
			return resp
		}
		resp.Success = true
		resp.Classification = spClassAuthenticated
		resp.Attendance = attendance
		resp.StudentInfo = studentInfo
		resp.Cookies = client.jar.Serialized()
		return resp
	}

	// Login flow
	loginSnap, err := spLogin(client, req.Email, req.Password, req.CaptchaAPIKey, req.CaptchaAPIURL)
	if err != nil {
		errMsg := err.Error()
		if strings.Contains(errMsg, "captchaText") || strings.Contains(errMsg, "captcha") {
			resp.Classification = spClassCaptchaFailed
			resp.Error = errMsg
		} else if strings.Contains(errMsg, "invalid credentials") {
			resp.Classification = spClassInvalidCreds
			resp.Error = errMsg
		} else {
			resp.Error = errMsg
		}
		return resp
	}

	resp.Classification = spClassAuthenticated
	resp.Cookies = client.jar.Serialized()

	if mode == spModeLogin {
		resp.Success = true
		return resp
	}

	// Login and fetch
	attendance, studentInfo, fetchErr := spFetchAttendance(client, loginSnap.URL)
	if fetchErr != nil {
		resp.Error = fetchErr.Error()
		// Login succeeded but data fetch failed — still return cookies
		resp.Success = true
		return resp
	}

	resp.Success = true
	resp.Attendance = attendance
	resp.StudentInfo = studentInfo
	resp.Cookies = client.jar.Serialized()
	return resp
}
