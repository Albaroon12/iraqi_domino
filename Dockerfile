# Multi-stage Dockerfile for the Iraqi Domino Pure-Dart Online Server.
# Compiles `bin/server.dart` into a native AOT Linux binary (~15 MB RAM footprint).
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
COPY lib ./lib
COPY bin ./bin

# Compile standalone Pure-Dart server binary:
RUN dart compile exe bin/server.dart -o /app/domino_server

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=build /app/domino_server /app/domino_server

ENV PORT=8080
ENV DOMINO_DB_PATH=/app/data/server_accounts.json
RUN mkdir -p /app/data

EXPOSE 8080
CMD ["/app/domino_server"]
