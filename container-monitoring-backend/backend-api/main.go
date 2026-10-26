package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
)

// Container represents a container returned by the API.
type Container struct {
	ContainerID int64  `json:"container_id"`
	Series      string `json:"series"`
	DeviceID    string `json:"device_id"`
	CompanyName string `json:"company_name"`
	Destination string `json:"destination"`
	Contents    string `json:"contents"`
	Package     string `json:"package"`
	Status      string `json:"status"`
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Allow requests from the Flutter development server.
		origin := r.Header.Get("Origin")

		if origin == "http://localhost:3000" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		}

		// Handle CORS preflight requests.
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func main() {
	// Load environment variables from the project root.
	_ = godotenv.Load("../.env")

	// Construct a PostgreSQL connection URL.
	dbHost := os.Getenv("POSTGRES_HOST")
	if dbHost == "" {
		dbHost = "127.0.0.1"
	}

	dbPort := os.Getenv("POSTGRES_PORT")
	if dbPort == "" {
		dbPort = "55433"
	}
	databaseURL := &url.URL{
		Scheme: "postgres",
		User: url.UserPassword(
			os.Getenv("POSTGRES_USER"),
			os.Getenv("POSTGRES_PASSWORD"),
		),
		Host: dbHost + ":" + dbPort,
		Path: "/container_monitoring",
	}

	// Open the database connection pool.
	db, err := sql.Open("pgx", databaseURL.String())
	if err != nil {
		log.Fatal("Database initialization failed: ", err)
	}
	defer db.Close()

	// Verify that PostgreSQL is reachable.
	if err := db.Ping(); err != nil {
		log.Fatal("PostgreSQL connection failed: ", err)
	}

	log.Println("PostgreSQL connected successfully")

	// Register the health-check endpoint.
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"status":  "ok",
			"service": "container-monitoring-api",
		})
	})

	// Register the container listing endpoint.
	http.HandleFunc("/api/containers", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		rows, err := db.QueryContext(r.Context(), `
			SELECT
				c.container_id,
				c.series,
				COALESCE(c.device_id, ''),
				COALESCE(co.company_name, ''),
				COALESCE(c.destination, ''),
				COALESCE(c.contents, ''),
				COALESCE(c.package, ''),
				COALESCE(c.status, '')
			FROM public.containers c
			LEFT JOIN public.companies co
				ON c.company_id = co.company_id
			ORDER BY c.container_id
		`)

		if err != nil {
			http.Error(w, "Failed to fetch containers", http.StatusInternalServerError)
			log.Println("Query error:", err)
			return
		}
		defer rows.Close()

		containers := make([]Container, 0)

		for rows.Next() {
			var container Container

			if err := rows.Scan(
				&container.ContainerID,
				&container.Series,
				&container.DeviceID,
				&container.CompanyName,
				&container.Destination,
				&container.Contents,
				&container.Package,
				&container.Status,
			); err != nil {
				http.Error(w, "Failed to read container data", http.StatusInternalServerError)
				log.Println("Scan error:", err)
				return
			}

			containers = append(containers, container)
		}

		if err := rows.Err(); err != nil {
			http.Error(w, "Failed to read query results", http.StatusInternalServerError)
			return
		}

		// Return the container list as JSON.
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(containers)
	})

	// Return the latest telemetry records for a container.
	registerContainerMutations(db)

	http.HandleFunc("GET /api/containers/{id}/telemetry", func(w http.ResponseWriter, r *http.Request) {
		containerID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)

		if err != nil || containerID <= 0 {
			http.Error(w, "Invalid container ID", http.StatusBadRequest)
			return
		}

		startTime, endTime, pageLimit, pageOffset, err := parseTelemetryPeriod(r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// Store nullable sensor values as pointers.
		type Telemetry struct {
			PacketCounter *int64   `json:"packet_counter"`
			RecordedAt    string   `json:"recorded_at"`
			Latitude      *float64 `json:"latitude"`
			Longitude     *float64 `json:"longitude"`
			DoorStatus    *string  `json:"door_status"`
			RSSI          *int     `json:"rssi"`
			SNR           *float64 `json:"snr"`
		}

		rows, err := db.QueryContext(r.Context(), `
			SELECT
				packet_counter,
				TO_CHAR(recorded_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
				latitude::double precision,
				longitude::double precision,
				door_status,
				rssi,
				snr::double precision
			FROM public.telemetry_clean
			WHERE container_id = $1
                          AND ($2::timestamp IS NULL OR recorded_at >= $2::timestamp)
                          AND ($3::timestamp IS NULL OR recorded_at < $3::timestamp)
                        ORDER BY recorded_at DESC, telemetry_id DESC
                        LIMIT $4 OFFSET $5
                `, containerID, startTime, endTime, pageLimit, pageOffset)

		if err != nil {
			log.Println("Telemetry query error:", err)
			http.Error(w, "Failed to fetch telemetry", http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		telemetry := make([]Telemetry, 0)

		for rows.Next() {
			var item Telemetry

			err := rows.Scan(
				&item.PacketCounter,
				&item.RecordedAt,
				&item.Latitude,
				&item.Longitude,
				&item.DoorStatus,
				&item.RSSI,
				&item.SNR,
			)

			if err != nil {
				log.Println("Telemetry scan error:", err)
				http.Error(w, "Failed to read telemetry", http.StatusInternalServerError)
				return
			}

			telemetry = append(telemetry, item)
		}

		if err := rows.Err(); err != nil {
			log.Println("Telemetry iteration error:", err)
			http.Error(w, "Failed to read telemetry", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")

		if err := json.NewEncoder(w).Encode(telemetry); err != nil {
			log.Println("JSON encoding error:", err)
		}
	})

	// Return the most recent telemetry for a container.
	http.HandleFunc("GET /api/containers/{id}/latest", func(w http.ResponseWriter, r *http.Request) {
		containerID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)

		if err != nil || containerID <= 0 {
			http.Error(w, "Invalid container ID", http.StatusBadRequest)
			return
		}

		type LatestTelemetry struct {
			ContainerID   int64    `json:"container_id"`
			PacketCounter *int64   `json:"packet_counter"`
			RecordedAt    string   `json:"recorded_at"`
			Latitude      *float64 `json:"latitude"`
			Longitude     *float64 `json:"longitude"`
			DoorStatus    *string  `json:"door_status"`
			RSSI          *int     `json:"rssi"`
			SNR           *float64 `json:"snr"`
		}

		var latest LatestTelemetry

		// Read only the newest validated telemetry record.
		err = db.QueryRowContext(r.Context(), `
			SELECT
				container_id,
				packet_counter,
				TO_CHAR(recorded_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
				latitude::double precision,
				longitude::double precision,
				door_status,
				rssi,
				snr::double precision
			FROM public.telemetry_clean
			WHERE container_id = $1
			ORDER BY recorded_at DESC, telemetry_id DESC
			LIMIT 1
		`, containerID).Scan(
			&latest.ContainerID,
			&latest.PacketCounter,
			&latest.RecordedAt,
			&latest.Latitude,
			&latest.Longitude,
			&latest.DoorStatus,
			&latest.RSSI,
			&latest.SNR,
		)

		if err == sql.ErrNoRows {
			http.Error(w, "Telemetry not found", http.StatusNotFound)
			return
		}

		if err != nil {
			log.Println("Latest telemetry error:", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(latest)
	})

	log.Println("Backend API running on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", corsMiddleware(http.DefaultServeMux)))
}
