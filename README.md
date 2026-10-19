# Conveyor

[![magicstream](https://github.com/evannwilsonn/conveyor/actions/workflows/magicstream.yml/badge.svg)](https://github.com/evannwilsonn/conveyor/actions/workflows/magicstream.yml)
[![footnote](https://github.com/evannwilsonn/footnote/actions/workflows/pipeline.yml/badge.svg)](https://github.com/evannwilsonn/footnote/actions/workflows/pipeline.yml)
[![barometer](https://github.com/evannwilsonn/barometer/actions/workflows/pipeline.yml/badge.svg)](https://github.com/evannwilsonn/barometer/actions/workflows/pipeline.yml)

The production pipeline, project 12 of my AI project roadmap: Docker and GitHub Actions around three apps (six since project 13), so every push is tested, packed into a container and shipped.

**Live board:** [evannwilsonn.github.io/conveyor](https://evannwilsonn.github.io/conveyor/) reads the pipelines' runs from GitHub when it opens and draws each latest run as a pictogram chart, one square per five seconds of work, coloured by stage (getting ready, checking, packing, shipping), with every step listed and the last 20 runs marked pass or fail.

| App | Pipeline | Tests | Ships to |
|---|---|---|---|
| [Footnote](https://github.com/evannwilsonn/footnote) (Go, pgvector, Ollama) | [`pipeline.yml`](https://github.com/evannwilsonn/footnote/blob/main/.github/workflows/pipeline.yml) | gofmt, vet, `go test -race` with a pgvector Postgres beside the tests, a check that the results page matches the results, image smoke test | `ghcr.io/evannwilsonn/footnote`, results page on GitHub Pages |
| [Barometer](https://github.com/evannwilsonn/barometer) (Next.js, MongoDB, Inngest) | [`pipeline.yml`](https://github.com/evannwilsonn/barometer/blob/main/.github/workflows/pipeline.yml) | typecheck, unit tests, build, then a real browser through every account flow (20 checks) against MongoDB, a mail catcher and the Inngest dev server; image smoke test | `ghcr.io/evannwilsonn/barometer`, site on Vercel |
| MagicStream (React, Go, MongoDB), in this repo | [`magicstream.yml`](.github/workflows/magicstream.yml) | both images build, the four-container stack starts, 10 checks through nginx | built and tested, not published (see below) |

## Where it came from

freeCodeCamp's [Full-Stack Docker & CI/CD course](https://www.youtube.com/watch?v=lEcULR30-GM) takes Gavin Lon's MagicStream app from bare metal to containers, then to a Hostinger VPS deployed by GitHub Actions. This repo follows the course on MagicStream, then applies the same ideas to two of my own apps. It changes a few things on the way:

- **Tests gate everything.** The course's workflow builds and deploys without testing (it says so). Here nothing is published until tests pass and the built image has been started and probed.
- **One image runs anywhere.** The course bakes the API's address into the React bundle and rewrites it with `envsubst` when the container starts. Here nginx serves the app and proxies `/api` to the Go API, so the bundle always calls `/api` on its own origin, and the login cookies are first-party.
- **GitHub's registry instead of Docker Hub.** Images push with the workflow's own token: no account, no access token to rotate. Each is tagged `latest` and with its commit, so any version can be run again.
- **No paid server.** Barometer deploys on Vercel and Footnote's page on GitHub Pages, both free. The images run anywhere with `docker compose -f … -f compose.prod.yml up -d`, the same command the course runs over SSH. Footnote's question box needs Ollama running a model, which needs more memory than free hosts give.
- **The seed job doesn't duplicate.** It fills only empty collections, so restarting the stack is safe.

## MagicStream

```sh
cd magicstream
./fetch.sh                                          # the app at the pinned commit, into src/
docker compose up -d --build                        # http://localhost:8081
./smoke.sh                                          # the checks CI runs
docker compose -f compose.yml -f compose.dev.yml watch   # Vite :5173 and go run :8080, live
```

- `api.Dockerfile`: Go 1.24 on Alpine. A dev stage runs `go run`; the runtime stage is the static binary alone as a non-root user, about 33 MB.
- `web.Dockerfile`: a dev stage runs Vite. The build stage compiles with the API at `/api`, and the runtime stage is nginx with `nginx.conf`, about 76 MB.
- `compose.yml`: web, api, MongoDB with a health check, and a one-shot `seed` job (mongosh reading the course's JSON). The API waits for the seed to finish, and the web waits for the API's health check.
- `smoke.sh`: the app loads and its client routes fall back to it, the API answers through nginx, the seeded movies and genres are there, a protected route refuses without a cookie, and a new account registers, signs in, reaches a protected route and gets recommendations.

The admin review feature calls OpenAI; set `OPENAI_API_KEY` to use it. Everything else works without it.

**Why its images aren't published:** MagicStream's repository has no license, so its code isn't mine to redistribute, and a published image would contain it. `fetch.sh` builds from the author's own repository at a fixed commit instead of copying the code here, and the pipeline builds and tests the images without pushing them.

## Layout

```
magicstream/            the course app's containers, compose files and checks
.github/workflows/      magicstream.yml (the other two pipelines live in their own repos)
docs/index.html         the live board (GitHub Pages)
```

## Design

The board is an Isotype chart, after Otto and Marie Neurath's pictogram statistics: counts are drawn as repeated squares rather than bars, so a reader can count them. One square is five seconds of work. Four stage colours on warm chart paper (`#f1ede2`): grey for getting ready, blue (`#2a5591`) for checking, ochre (`#d39a17`) for packing images, red (`#c13a2c`) for shipping, each with its own pictogram. Jost (a Futura revival, the face Isotype was set in) for headings and text, Courier Prime for figures. Dark mode is its own palette, not an inversion. The board makes six API calls per visit and keeps answers for five minutes, inside GitHub's 60-an-hour limit for visitors who aren't signed in.

## Project 13

The capstone's three Elixir apps (Lure, Recall and Squiggle) run the same line. Each one is formatted, compiled with warnings as errors and tested, built into an image that has to start and serve on port 7860, published to GHCR, and deployed to Google Cloud Run. `cloudrun-setup.sh` is the one-time Google Cloud setup they share: an image registry, a deployer account and keyless login from GitHub Actions.
