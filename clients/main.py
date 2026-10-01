import os
import time

import mysql.connector
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel, EmailStr, Field

app = FastAPI(
    title="API Clients",
    description="API de gestion des clients (CRUD) reliée à MySQL.",
    version="1.0.0",
    contact={"name": "IUT - Virtualisation TP2"},
)

# Paramètres de connexion lus depuis les variables d'environnement.
DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "mysql"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "carpart"),
    "password": os.getenv("MYSQL_PASSWORD", "carpart"),
    "database": os.getenv("MYSQL_DATABASE", "clients_database"),
}


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


def init_database():
    # MySQL peut mettre quelques secondes à démarrer : on réessaie.
    for _ in range(30):
        try:
            conn = get_connection()
            cursor = conn.cursor()
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS clients (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    nom VARCHAR(255) NOT NULL,
                    prenom VARCHAR(255) NOT NULL,
                    email VARCHAR(255) NOT NULL,
                    nb_commande INT NOT NULL DEFAULT 0
                )
                """
            )
            conn.commit()
            cursor.close()
            conn.close()
            return
        except mysql.connector.Error:
            time.sleep(2)
    raise RuntimeError("Impossible de se connecter à MySQL.")


@app.on_event("startup")
def on_startup():
    init_database()


# Schéma d'un client
class Client(BaseModel):
    nom: str = Field(..., description="Nom du client", examples=["Durand"])
    prenom: str = Field(..., description="Prénom du client", examples=["Marie"])
    email: EmailStr = Field(..., description="Adresse mail du client", examples=["marie.durand@mail.com"])
    nb_commande: int = Field(0, ge=0, description="Nombre de commandes effectuées", examples=[3])


# Création d'un client
@app.post(
    "/client",
    tags=["Clients"],
    summary="Ajouter un client",
    description="Insère un nouveau client dans la base et retourne son identifiant.",
    status_code=201,
    responses={201: {"description": "Client créé avec succès"}},
)
def create_client(client: Client):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO clients (nom, prenom, email, nb_commande) VALUES (%s, %s, %s, %s)",
        (client.nom, client.prenom, client.email, client.nb_commande),
    )
    conn.commit()
    new_id = cursor.lastrowid
    cursor.close()
    conn.close()
    return JSONResponse(
        status_code=201,
        content={"message": "Client created", "id": new_id},
    )


# Liste des clients
@app.get(
    "/clients",
    tags=["Clients"],
    summary="Lister les clients",
    description="Retourne la liste de tous les clients.",
    responses={200: {"description": "Liste des clients"}},
)
def list_clients():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT id, nom, prenom, email, nb_commande FROM clients")
    clients = cursor.fetchall()
    cursor.close()
    conn.close()
    return JSONResponse(status_code=200, content=clients)


# Récupération d'une fiche client
@app.get(
    "/client/{client_id}",
    tags=["Clients"],
    summary="Accéder à une fiche client",
    description="Retourne la fiche d'un client identifié par son `client_id`.",
    responses={
        200: {"description": "Fiche client trouvée"},
        404: {"description": "Client introuvable"},
    },
)
def get_client(client_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT id, nom, prenom, email, nb_commande FROM clients WHERE id = %s",
        (client_id,),
    )
    client = cursor.fetchone()
    cursor.close()
    conn.close()
    if client:
        return JSONResponse(status_code=200, content=client)
    return JSONResponse(status_code=404, content={"message": "Client not found"})


# Mise à jour d'une fiche client
@app.put(
    "/client/{client_id}",
    tags=["Clients"],
    summary="Modifier une fiche client",
    description="Met à jour une fiche client existante identifiée par son `client_id`.",
    responses={
        200: {"description": "Fiche client mise à jour"},
        404: {"description": "Client introuvable"},
    },
)
def update_client(client_id: int, client: Client):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE clients SET nom = %s, prenom = %s, email = %s, nb_commande = %s WHERE id = %s",
        (client.nom, client.prenom, client.email, client.nb_commande, client_id),
    )
    conn.commit()
    updated = cursor.rowcount
    cursor.close()
    conn.close()
    if updated:
        return JSONResponse(status_code=200, content={"message": "Client updated"})
    return JSONResponse(status_code=404, content={"message": "Client not found"})


# Suppression d'un client
@app.delete(
    "/client/{client_id}",
    tags=["Clients"],
    summary="Supprimer un client",
    description="Supprime un client identifié par son `client_id`.",
    responses={
        200: {"description": "Client supprimé"},
        404: {"description": "Client introuvable"},
    },
)
def delete_client(client_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM clients WHERE id = %s", (client_id,))
    conn.commit()
    deleted = cursor.rowcount
    cursor.close()
    conn.close()
    if deleted:
        return JSONResponse(status_code=200, content={"message": "Client deleted"})
    return JSONResponse(status_code=404, content={"message": "Client not found"})


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
