package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5/pgconn"
)

func registerContainerMutations(db *sql.DB) {
	http.HandleFunc("POST /api/containers", func(w http.ResponseWriter, r *http.Request) {
		var input struct {
			Series      string `json:"series"`
			DeviceID    string `json:"device_id"`
			Company     string `json:"company_name"`
			Destination string `json:"destination"`
			Contents    string `json:"contents"`
			Package     string `json:"package"`
		}

		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1048576))
		decoder.DisallowUnknownFields()

		if decoder.Decode(&input) != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		if decoder.Decode(&struct{}{}) != io.EOF {
			http.Error(w, "Only one JSON object is allowed", http.StatusBadRequest)
			return
		}

		input.Series = strings.TrimSpace(input.Series)
		input.DeviceID = strings.TrimSpace(input.DeviceID)
		input.Company = strings.TrimSpace(input.Company)

		if input.Series == "" || input.DeviceID == "" || input.Company == "" {
			http.Error(w, "Series, device_id, and company_name are required", http.StatusBadRequest)
			return
		}

		tx, err := db.BeginTx(r.Context(), nil)
		if err != nil {
			http.Error(w, "Database unavailable", http.StatusInternalServerError)
			return
		}
		defer tx.Rollback()

		var companyID int64
		err = tx.QueryRowContext(r.Context(),
			`SELECT company_id FROM public.companies
             WHERE LOWER(company_name) = LOWER($1)
             ORDER BY company_id LIMIT 1`,
			input.Company,
		).Scan(&companyID)

		if errors.Is(err, sql.ErrNoRows) {
			err = tx.QueryRowContext(r.Context(),
				`INSERT INTO public.companies (company_name)
                 VALUES ($1) RETURNING company_id`,
				input.Company,
			).Scan(&companyID)
		}

		if err != nil {
			http.Error(w, "Could not resolve company", http.StatusInternalServerError)
			return
		}

		var id int64
		err = tx.QueryRowContext(r.Context(),
			`INSERT INTO public.containers
             (company_id, series, device_id, destination, contents, package, status)
             VALUES ($1, $2, $3, $4, $5, $6, 'Active')
             RETURNING container_id`,
			companyID, input.Series, input.DeviceID,
			strings.TrimSpace(input.Destination),
			strings.TrimSpace(input.Contents),
			strings.TrimSpace(input.Package),
		).Scan(&id)

		if err != nil {
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == "23505" {
				http.Error(w, "Series or device ID already registered", http.StatusConflict)
				return
			}
			http.Error(w, "Failed to create container", http.StatusInternalServerError)
			return
		}

		if tx.Commit() != nil {
			http.Error(w, "Failed to commit container", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(map[string]any{
			"container_id": id,
			"status":       "created",
		})
	})

	http.HandleFunc("DELETE /api/containers/{id}", func(w http.ResponseWriter, r *http.Request) {
		id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
		if err != nil || id <= 0 {
			http.Error(w, "Invalid container ID", http.StatusBadRequest)
			return
		}

		result, err := db.ExecContext(r.Context(),
			"DELETE FROM public.containers WHERE container_id = $1", id)

		if err != nil {
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == "23503" {
				http.Error(w, "Container has telemetry history and cannot be deleted", http.StatusConflict)
				return
			}
			http.Error(w, "Failed to delete container", http.StatusInternalServerError)
			return
		}

		affected, err := result.RowsAffected()
		if err != nil {
			http.Error(w, "Failed to confirm deletion", http.StatusInternalServerError)
			return
		}
		if affected == 0 {
			http.Error(w, "Container not found", http.StatusNotFound)
			return
		}

		w.WriteHeader(http.StatusNoContent)
	})
}
