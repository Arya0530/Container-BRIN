FROM golang:1.26.4-alpine AS builder

WORKDIR /src

COPY backend-api/go.mod backend-api/go.sum ./
RUN go mod download

COPY backend-api/ ./

RUN CGO_ENABLED=0 GOOS=linux go build -o /server .

FROM alpine:3.21

WORKDIR /app

COPY --from=builder /server /app/server

EXPOSE 8080

CMD ["/app/server"]
