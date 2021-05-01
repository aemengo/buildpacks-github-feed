FROM golang:1.16
COPY . /src
RUN curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz \
  && gunzip elm.gz \
  && chmod +x elm \
  && mv elm /usr/local/bin/elm
RUN cd /src/web \
  && elm make src/Main.elm --output elm.js --optimize
RUN cd /src \
  && CGO_ENABLED=0 go build -o /app .

FROM alpine:latest
ENV PORT=8080 GITHUB_TOKEN=""
RUN apk --no-cache add ca-certificates
COPY --from=0 /app /app
COPY --from=0 /src/web /web
CMD ["/app"]