# Multi-arch build. Compiles on the build platform and cross-compiles to the
# target platform, so `docker buildx build --platform linux/amd64,linux/arm64`
# produces a manifest that runs on both amd64 and arm64 clusters.
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /out/order-processor .

FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/order-processor /order-processor
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/order-processor"]
