# Multi-stage build: compiles Flutter web, then serves the static output
# with nginx. Build args carry the Appwrite endpoint/project id (public
# client config, not secrets - the real access control lives in Appwrite's
# own permission model, not in hiding these values).
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

ARG APPWRITE_ENDPOINT
ARG APPWRITE_PROJECT_ID

RUN flutter pub get && \
    flutter build web --release \
      --dart-define=APPWRITE_ENDPOINT=${APPWRITE_ENDPOINT} \
      --dart-define=APPWRITE_PROJECT_ID=${APPWRITE_PROJECT_ID}

FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

# Flutter web uses client-side routing (GoRouter); unknown paths must fall
# back to index.html instead of nginx's default 404.
RUN printf 'server {\n\
    listen 80;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
