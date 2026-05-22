FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart compile exe bin/server.dart -o bin/server

FROM debian:stable-slim
WORKDIR /app
COPY --from=build /app/bin/server /app/server
EXPOSE 8080
ENTRYPOINT ["/app/server"]
