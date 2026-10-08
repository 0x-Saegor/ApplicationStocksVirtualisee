# CarPart - TP Virtualisation

Deux API FastAPI dans des conteneurs :

- `clients` : gestion des clients, avec MySQL (port 8000)
- `stock` : gestion des produits, avec MongoDB (port 8001)

## Liens

- GitHub : https://github.com/0x-Saegor/ApplicationStocksVirtualisee
- Docker Hub : https://hub.docker.com/u/saegor
  - https://hub.docker.com/r/saegor/carpart-clients
  - https://hub.docker.com/r/saegor/carpart-stock

## Lancer le projet

```bash
git clone https://github.com/0x-Saegor/ApplicationStocksVirtualisee.git
cd ApplicationStocksVirtualisee
docker compose up -d --build
```

Pour utiliser directement les images du Docker Hub :

```bash
docker compose -f docker-compose.hub.yml up -d
```

Les docs Swagger sont sur http://localhost:8000/docs et http://localhost:8001/docs.

Pour remplir la base clients avec des données de test :

```bash
./usercommand/seed.sh
```

## CI

La CI GitHub Actions teste les deux API puis build et push les images sur Docker Hub (et sur ghcr avec buildah).
