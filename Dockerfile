# Packages an already-built `flutter build web` output (see cd.yml, which
# runs the build on the Actions runner using the same Flutter toolchain as
# CI) into a static nginx image. Not a multi-stage Flutter build: third-party
# Flutter Docker images lag behind the Dart SDK version this project pins
# in pubspec.yaml, causing "version solving failed" during `pub get`.
FROM nginx:alpine

COPY build/web /usr/share/nginx/html

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
