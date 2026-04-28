# DK Software Homepage

Next.js 14 · Tailwind · Framer Motion. Dark tech aesthetic with Electric Blue (#3B82F6) accent.

## Local dev
```bash
npm install
npm run dev        # http://localhost:3100
```

## Build
```bash
npm run build
npm start
```

## Docker
```bash
docker build -t dksw-homepage .
docker run --rm -p 3100:3100 dksw-homepage
```

## Production
Container name: `aiapp_dksw_homepage`  ·  Port: `3100`  ·  Network: `docker_aiapp_network`

nginx routes `dksw4.com` / `www.dksw4.com` root → this container.
