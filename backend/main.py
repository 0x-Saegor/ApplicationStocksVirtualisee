from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from pymongo import MongoClient
from bson import ObjectId

app = FastAPI(
    title="API Produits",
    description="API de gestion de produits (CRUD) reliée à MongoDB.",
    version="1.0.0",
    contact={"name": "IUT - Virtualisation TP1"},
)
client = MongoClient("mongodb://mongo:27017/")
db = client.products_database

# Schéma d'un produit
class Product(BaseModel):
    nom: str = Field(..., description="Nom du produit", examples=["Clavier"])
    description: str = Field(..., description="Description du produit", examples=["Clavier mécanique"])
    quantite: int = Field(..., ge=0, description="Quantité en stock", examples=[10])
    prix: float = Field(..., ge=0, description="Prix unitaire en euros", examples=[49.99])


# Création d'un produit
@app.post(
    "/product",
    tags=["Produits"],
    summary="Créer un produit",
    description="Insère un nouveau produit dans la base et retourne son identifiant.",
    status_code=201,
    responses={201: {"description": "Produit créé avec succès"}},
)
def create_product(product: Product):
    result = db.products.insert_one(product.model_dump())
    return JSONResponse(
        status_code=201,
        content={"message": "Product created", "id": str(result.inserted_id)},
    )

# Liste des produits
@app.get(
    "/products",
    tags=["Produits"],
    summary="Lister les produits",
    description="Retourne la liste de tous les produits avec leur identifiant.",
    responses={200: {"description": "Liste des produits"}},
)
def list_products():
    products = []
    for product in db.products.find():
        product["_id"] = str(product["_id"])
        products.append(product)
    return JSONResponse(status_code=200, content=products)

# Mise à jour d'un produit
@app.put(
    "/product/{product_id}",
    tags=["Produits"],
    summary="Mettre à jour un produit",
    description="Met à jour un produit existant identifié par son `product_id`.",
    responses={200: {"description": "Produit mis à jour"}},
)
def update_product(product_id: str, product: Product):
    db.products.update_one({"_id": ObjectId(product_id)}, {"$set": product.model_dump()})
    return JSONResponse(status_code=200, content={"message": "Product updated"})

# Suppression d'un produit
@app.delete(
    "/product/{product_id}",
    tags=["Produits"],
    summary="Supprimer un produit",
    description="Supprime un produit identifié par son `product_id`.",
    responses={200: {"description": "Produit supprimé"}},
)
def delete_product(product_id: str):
    db.products.delete_one({"_id": ObjectId(product_id)})
    return JSONResponse(status_code=200, content={"message": "Product deleted"})

# Récupération de la description d'un produit
@app.get(
    "/product/description/{id}",
    tags=["Produits"],
    summary="Récupérer la description d'un produit",
    description="Retourne la description d'un produit identifié par son `id`.",
    responses={
        200: {"description": "Description trouvée"},
        404: {"description": "Produit introuvable"},
    },
)
def get_product_description(id: str):
    product = db.products.find_one({"_id": ObjectId(id)})
    if product:
        return JSONResponse(
            status_code=200,
            content={"description": product.get("description", "")},
        )
    return JSONResponse(status_code=404, content={"message": "Product not found"})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)