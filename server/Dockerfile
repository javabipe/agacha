# Compila (rodando os testes) e entrega um binário único numa imagem mínima, sem shell e sem root.
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY . .
RUN CGO_ENABLED=0 go vet ./... && CGO_ENABLED=0 go test ./... \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/agacha-server ./cmd/agacha-server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/agacha-server /agacha-server
USER nonroot:nonroot
ENV LISTEN_ADDR=:8080
EXPOSE 8080
ENTRYPOINT ["/agacha-server"]
