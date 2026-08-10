#!/bin/bash
# Só backend + database — o frontend roda fora do Docker
# (`flutter run -d chrome` direto no Windows).
docker compose -f docker-compose.yml up -d --build