FROM golang:1.21 AS build
WORKDIR /usr/src/catgpt
COPY catgpt/ .
RUN go mod download
RUN CGO_ENABLED=0 go build -o bin/catapp

FROM gcr.io/distroless/static-debian12:latest-amd64
WORKDIR /root/
COPY --from=build /usr/src/catgpt/bin/catapp .
ENTRYPOINT [ "./catapp" ]
