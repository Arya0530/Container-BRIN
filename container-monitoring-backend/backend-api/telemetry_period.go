package main

import (
	"fmt"
	"net/http"
	"strconv"
	"time"
)

// Parse a UTC date range and pagination parameters.
// The end timestamp is exclusive.
func parseTelemetryPeriod(r *http.Request) (any, any, int, int, error) {
	q := r.URL.Query()
	startText := q.Get("start")
	endText := q.Get("end")

	if (startText == "") != (endText == "") {
		return nil, nil, 0, 0, fmt.Errorf("start and end must be provided together")
	}

	var startValue any
	var endValue any

	limit := 50

	if startText != "" {
		start, err := time.Parse(time.RFC3339Nano, startText)
		if err != nil {
			return nil, nil, 0, 0, fmt.Errorf("invalid start timestamp")
		}

		end, err := time.Parse(time.RFC3339Nano, endText)
		if err != nil {
			return nil, nil, 0, 0, fmt.Errorf("invalid end timestamp")
		}

		if !start.Before(end) {
			return nil, nil, 0, 0, fmt.Errorf("start must be before end")
		}

		// PostgreSQL stores these telemetry timestamps as UTC without timezone.
		startValue = start.UTC().Format("2006-01-02 15:04:05.999999")
		endValue = end.UTC().Format("2006-01-02 15:04:05.999999")
		limit = 500
	}

	if value := q.Get("limit"); value != "" {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed < 1 || parsed > 1000 {
			return nil, nil, 0, 0, fmt.Errorf("limit must be between 1 and 1000")
		}
		limit = parsed
	}

	offset := 0
	if value := q.Get("offset"); value != "" {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed < 0 {
			return nil, nil, 0, 0, fmt.Errorf("offset must be zero or greater")
		}
		offset = parsed
	}

	return startValue, endValue, limit, offset, nil
}
