from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pymongo import MongoClient
from bson import ObjectId
from dataclasses import dataclass, asdict

app = FastAPI()
client = MongoClient()
db = client.products_database

# Schéma d'un produit
@dataclass
class Product:
    nom: str
    description: str
    quantite: int
    prix: float

# Création d'un produit
@app.post("/product")
def create_product(product: dict):
    new_product = Product(**product)
    result = db.products.insert_one(asdict(new_product))
    return JSONResponse(
        status_code=201,
        content={"message": "Product created", "id": str(result.inserted_id)},
    )

# Liste des produits
@app.get("/products")
def list_products():
    products = []
    for product in db.products.find():
        product["_id"] = str(product["_id"])
        products.append(product)
    return JSONResponse(status_code=200, content=products)

# Mise à jour d'un produit
@app.put("/product/{product_id}")
def update_product(product_id: str, product: dict):
    updated_product = Product(**product)
    db.products.update_one({"_id": ObjectId(product_id)}, {"$set": asdict(updated_product)})
    return JSONResponse(status_code=200, content={"message": "Product updated"})

# Suppression d'un produit
@app.delete("/product/{product_id}")
def delete_product(product_id: str):
    db.products.delete_one({"_id": ObjectId(product_id)})
    return JSONResponse(status_code=200, content={"message": "Product deleted"})

# Récupération de la description d'un produit
@app.get("/product/description/{id}")
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
    uvicorn.run(app, host="127.0.0.1", port=8000)