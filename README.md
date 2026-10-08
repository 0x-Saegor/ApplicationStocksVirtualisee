# CarPart – Application de stocks virtualisée

Deux API FastAPI conteneurisées :

- **clients** (TP2) : gestion des clients, base MySQL → http://localhost:8000/docs
- **stock** (TP1) : gestion des produits, base MongoDB → http://localhost:8001/docs

## Liens du projet

| | URL |
|---|---|
| Dépôt Git (code source + docker-compose) | https://github.com/0x-Saegor/ApplicationStocksVirtualisee |
| Docker Hub | https://hub.docker.com/u/saegor |
| Docker Hub – image clients | https://hub.docker.com/r/saegor/carpart-clients |
| Docker Hub – image stock | https://hub.docker.com/r/saegor/carpart-stock |

## Arborescence

```
.
├── clients/                 # API clients (FastAPI + MySQL) + Dockerfile
├── stock/                   # API stock (FastAPI + MongoDB) + Dockerfile
├── usercommand/seed.sh      # script pour peupler / vider la base clients via l'API
├── docker-compose.yml       # build local des images
├── docker-compose.hub.yml   # utilise les images publiées sur Docker Hub
├── .env                     # variables de connexion aux bases
└── .github/workflows/ci.yml # tests + build/push des images (Docker Hub et GHCR)
```

## Récupérer le projet

```bash
git clone https://github.com/0x-Saegor/ApplicationStocksVirtualisee.git
cd ApplicationStocksVirtualisee
```

## Lancement

Build local :

```bash
docker compose up -d --build
```

Avec les images du Docker Hub (sans build) :

```bash
docker compose -f docker-compose.hub.yml up -d
```

Peupler la base clients :

```bash
./usercommand/seed.sh
```

## CI

À chaque push sur `main`, la CI :

1. teste les deux API (CRUD complet via `curl`) contre une vraie base MySQL / MongoDB ;
2. build et pousse les images `carpart-clients` et `carpart-stock` sur Docker Hub (`docker/build-push-action`) et sur GHCR (`buildah`).
