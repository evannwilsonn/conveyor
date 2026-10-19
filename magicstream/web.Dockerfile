# MagicStream's React client. Build context: ./src (see fetch.sh).
#   dev   the Vite dev server, talking to the API directly on :8080
#   build compiles the app with the API at /api on the same origin
#   run   nginx serving the compiled app and passing /api/* to the API container
#
# The course bakes the API's address into the bundle at build time and then rewrites it at start
# with envsubst. Serving the client and proxying the API from one origin avoids that: the bundle
# always calls /api, so one image works on any host, and the login cookies are first-party.
FROM node:22-alpine AS deps
WORKDIR /app
COPY Client/magic-stream-client/package.json Client/magic-stream-client/package-lock.json ./
RUN npm ci --no-audit --no-fund

FROM deps AS dev
COPY Client/magic-stream-client/ ./
ENV VITE_API_BASE_URL=http://localhost:8080
EXPOSE 5173
CMD ["npx", "vite", "--host", "0.0.0.0"]

FROM deps AS build
COPY Client/magic-stream-client/ ./
ENV VITE_API_BASE_URL=/api
RUN npx vite build

FROM nginx:1.27-alpine AS run
COPY --from=build /app/dist /usr/share/nginx/html
# nginx.conf lives beside this file, outside the app's source: compose passes this folder in as
# the "conf" build context (docker build --build-context conf=magicstream).
COPY --from=conf nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
