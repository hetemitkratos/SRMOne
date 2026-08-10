package main

import (
	"encoding/json"
)

type ScraperRequest struct {
	Mode         string        `json:"mode"`
	Username     string        `json:"username"`
	Password     string        `json:"password"`
	Token        string        `json:"token"`
	Sub          string        `json:"sub"`
	Phaveloc     int64         `json:"phaveloc"`
	Sections     []string      `json:"sections,omitempty"`
	UUID         string        `json:"uuid,omitempty"`
	JobUUID      string        `json:"jobUuid,omitempty"`
	JobID        int           `json:"jobId,omitempty"`
	FileURL      string        `json:"fileUrl,omitempty"`
	MFAToken     string        `json:"mfaToken,omitempty"`
	TOTPCode     string        `json:"totpCode,omitempty"`
	EmailOTP     string        `json:"emailOtp,omitempty"`
	Page         int           `json:"page,omitempty"`
	Size         int           `json:"size,omitempty"`
	Sort         string        `json:"sort,omitempty"`
	Filters      []Filter      `json:"filters,omitempty"`
	StartDate    string        `json:"startDate,omitempty"`
	EndDate      string        `json:"endDate,omitempty"`
	ResumeName   string        `json:"resumeName,omitempty"`
	ApplyAnswers []ApplyAnswer `json:"applyAnswers,omitempty"`
}

type ApplyAnswer struct {
	QuestionID      int      `json:"questionId"`
	ResponseOptions []string `json:"responseOptions"`
}

type Filter struct {
	Key       string      `json:"key"`
	Operation string      `json:"operation"`
	Value     interface{} `json:"value"`
}

type ScraperResponse struct {
	Success        bool                        `json:"success"`
	Error          string                      `json:"error,omitempty"`
	Token          string                      `json:"token,omitempty"`
	EncryptedToken string                      `json:"encryptedToken,omitempty"`
	Sub            string                      `json:"sub,omitempty"`
	UUID           string                      `json:"uuid,omitempty"`
	Phaveloc       int64                       `json:"phaveloc,omitempty"`
	RequiresMFA    bool                        `json:"requiresMfa,omitempty"`
	MFAToken       string                      `json:"mfaToken,omitempty"`
	PublicURL      string                      `json:"publicUrl,omitempty"`
	Data           *json.RawMessage            `json:"data,omitempty"`
	FileData       string                      `json:"fileData,omitempty"`
	FileName       string                      `json:"fileName,omitempty"`
	ContentType    string                      `json:"contentType,omitempty"`
	Sections       map[string]*json.RawMessage `json:"sections,omitempty"`
}

type LoginResponse struct {
	Token        string `json:"token"`
	PublicURL    string `json:"publicUrl"`
	RequiresTotp bool   `json:"requiresTotp"`
	MFAToken     string `json:"mfaToken"`
}
