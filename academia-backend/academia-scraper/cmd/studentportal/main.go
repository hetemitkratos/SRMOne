package main

import (
	"encoding/base64"
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
	if mode != spModeFetch && mode != spModePrepare && strings.TrimSpace(req.Password) == "" {
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
	case spModeLogin, spModeFetch, spModeLoginAndFetch, spModePrepare:
		return strings.ToLower(strings.TrimSpace(req.Mode))
	}
	if len(req.Cookies) > 0 && strings.TrimSpace(req.Password) == "" {
		return spModeFetch
	}
	return spModeLoginAndFetch
}

func spRun(req SPRequest, mode string) SPResponse {
	client := NewSPClient()

	// Seed cookies for fetch mode and for resuming a pending captcha login
	if (mode == spModeFetch || (req.CaptchaAnswer != "" && req.LoginState != nil)) && len(req.Cookies) > 0 {
		cookieMap := make(map[string]string)
		for _, c := range req.Cookies {
			if c.Name != "" {
				cookieMap[c.Name] = c.Value
			}
		}
		client.jar.SeedCookies(cookieMap)
	}

	resp := SPResponse{Classification: spClassUnknown}

	if mode == spModePrepare {
		// Only fetch the login page + captcha image — no form POST, so no
		// login attempt is consumed. Used to (re)issue a manual captcha.
		ctx, err := spPrepareLogin(client)
		if err != nil {
			resp.Error = err.Error()
			return resp
		}
		resp.Classification = spClassCaptchaNeeded
		resp.CaptchaImage = "data:image/png;base64," + base64.StdEncoding.EncodeToString(ctx.CaptchaImage)
		resp.Cookies = client.jar.Serialized()
		resp.LoginState = ctx.pending()
		return resp
	}

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
	var loginSnap SPRequestSnapshot
	var err error

	if req.CaptchaAnswer != "" && req.LoginState != nil {
		// Resume a pending login: the user solved the captcha manually.
		// Cookies were already seeded above; rebuild the context and POST.
		st := req.LoginState
		ctx := &spLoginContext{
			Config: spSecureConfig{
				CaptchaFieldName: st.CaptchaFieldName,
				DomainFieldName:  st.DomainFieldName,
				RandomDelimiter:  st.RandomDelimiter,
			},
			HoneypotNames: st.HoneypotNames,
			PageLoadMs:    st.PageLoadMs,
		}
		loginSnap, err = spSubmitLogin(client, ctx, req.Email, req.Password, strings.TrimSpace(req.CaptchaAnswer))
	} else {
		var pendingCtx *spLoginContext
		loginSnap, pendingCtx, err = spLogin(client, req.Email, req.Password, req.CaptchaAPIKey, req.CaptchaAPIURL)
		if err != nil && pendingCtx != nil {
			// Captcha couldn't be solved automatically — hand it to the user.
			resp.Classification = spClassCaptchaNeeded
			resp.CaptchaImage = "data:image/png;base64," + base64.StdEncoding.EncodeToString(pendingCtx.CaptchaImage)
			resp.Cookies = client.jar.Serialized()
			resp.LoginState = pendingCtx.pending()
			resp.Error = err.Error()
			return resp
		}
	}

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
