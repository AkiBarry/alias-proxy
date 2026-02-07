# Stage 1: Generate dynamic Traefik config from mapping.json
FROM python:3-alpine AS generator
WORKDIR /app
RUN pip install pyyaml
COPY mapping.json .
COPY generate_config.py .
RUN python generate_config.py

# Stage 2: Run Traefik with the generated config
FROM traefik:v3.0
COPY traefik.yml /etc/traefik/traefik.yml
COPY --from=generator /app/dynamic.yml /etc/traefik/dynamic.yml
