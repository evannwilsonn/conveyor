#!/usr/bin/env sh
# Checks a running MagicStream stack through the front door (nginx on :8081), the way a browser
# would: the app loads, the API answers through the proxy, the seed data is there, and a new
# account can register, sign in with a cookie, and reach a protected route.
set -eu
BASE=${BASE:-http://localhost:8081}
jar=$(mktemp)
trap 'rm -f "$jar" body' EXIT
n=0
ok() { n=$((n + 1)); echo "ok $n - $1"; }
fail() { echo "not ok - $1"; exit 1; }

for i in $(seq 1 60); do curl -fs -o /dev/null "$BASE/api/hello" && break; sleep 2; done

curl -fs "$BASE/" -o body && grep -q '<div id="root">' body || fail "the app's page loads"
ok "the app's page loads"

curl -fs "$BASE/login" -o body && grep -q '<div id="root">' body || fail "client-side routes fall back to the app"
ok "client-side routes fall back to the app"

[ "$(curl -fs "$BASE/api/hello")" = "Hello, MagicStreamMovies!" ] || fail "API answers through the proxy"
ok "API answers through the proxy"

movies=$(curl -fs "$BASE/api/movies" | grep -o '"imdb_id"' | wc -l)
[ "$movies" -ge 15 ] || fail "seeded movies are served ($movies)"
ok "seeded movies are served ($movies)"

genres=$(curl -fs "$BASE/api/genres" | grep -o '"genre_id"' | wc -l)
[ "$genres" -ge 9 ] || fail "genres are served ($genres)"
ok "genres are served ($genres)"

code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/movie/tt0111161")
[ "$code" = 401 ] || fail "protected route refuses without a cookie (got $code)"
ok "protected route refuses without a cookie"

email="smoke-$(date +%s)@example.com"
body=$(printf '{"first_name":"Smoke","last_name":"Test","email":"%s","password":"smoke-pass-1","role":"USER","favourite_genres":[{"genre_id":2,"genre_name":"Drama"}]}' "$email")
code=$(curl -s -o body -w '%{http_code}' -H 'Content-Type: application/json' -d "$body" "$BASE/api/register")
[ "$code" = 201 ] || [ "$code" = 200 ] || fail "register a new account (got $code: $(cat body))"
ok "register a new account"

code=$(curl -s -o body -w '%{http_code}' -c "$jar" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$email\",\"password\":\"smoke-pass-1\"}" "$BASE/api/login")
[ "$code" = 200 ] && grep -q access_token "$jar" || fail "sign in sets the session cookie (got $code)"
ok "sign in sets the session cookie"

code=$(curl -s -o body -w '%{http_code}' -b "$jar" "$BASE/api/movie/tt0111161")
[ "$code" = 200 ] && grep -q "Shawshank" body || fail "protected route works with the cookie (got $code)"
ok "protected route works with the cookie"

code=$(curl -s -o body -w '%{http_code}' -b "$jar" "$BASE/api/recommendedmovies")
[ "$code" = 200 ] && grep -q '"imdb_id"' body || fail "recommendations for the account's genres (got $code)"
ok "recommendations for the account's genres"

echo "all $n checks passed"
