#!/usr/bin/env bash
#
# Petit utilitaire pour peupler / vider la base de produits via l'API.
# On passe par les endpoints HTTP plutôt que d'attaquer Mongo directement,
# comme ça on teste aussi l'API au passage.

# URL de l'API, surchargeable : API_URL=http://autre:8000 ./seed.sh
API_URL="${API_URL:-http://localhost:8000}"

# Couleurs (désactivées automatiquement si la sortie n'est pas un terminal).
if [ -t 1 ]; then
  ROUGE=$'\033[31m'; VERT=$'\033[32m'; JAUNE=$'\033[33m'; BLEU=$'\033[34m'; GRAS=$'\033[1m'; RESET=$'\033[0m'
else
  ROUGE=''; VERT=''; JAUNE=''; BLEU=''; GRAS=''; RESET=''
fi

# Marqueurs de résultat réutilisés partout.
ok()   { echo "${VERT}[OK]${RESET}   $*"; }
ko()   { echo "${ROUGE}[KO]${RESET}   $*"; }
info() { echo "${BLEU}[..]${RESET}   $*"; }

# Quelques pièces de départ pour avoir de quoi tester (stock automobile).
# Format : nom|description|quantite|prix
PRODUITS=(
  "Liquide de frein|Liquide de frein DOT 4 - 1L|40|8.90"
  "Plaquettes de frein|Jeu de plaquettes avant|25|34.50"
  "Filtre à huile|Filtre à huile moteur essence/diesel|60|6.75"
  "Bougie d'allumage|Bougie iridium longue durée|120|12.30"
  "Batterie 12V|Batterie 60Ah 540A|15|89.00"
  "Essuie-glace|Balai d'essuie-glace 60cm|50|9.99"
)

# Vérifie que curl est dispo, sinon on ne peut rien faire.
if ! command -v curl >/dev/null 2>&1; then
  echo "curl est requis mais introuvable. Installe-le puis relance."
  exit 1
fi

# Petit test de connexion avant de proposer le menu.
verifier_api() {
  if ! curl -s -o /dev/null "$API_URL/products"; then
    echo "Impossible de joindre l'API sur $API_URL."
    echo "Vérifie que les conteneurs tournent (docker compose up)."
    return 1
  fi
  return 0
}

# Échappe les caractères spéciaux JSON (\ et ") d'une chaîne.
json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

# Ajoute un produit à partir de ses champs.
ajouter_produit() {
  local nom="$1" description="$2" quantite="$3" prix="$4"

  curl -s -X POST "$API_URL/product" \
    -H "Content-Type: application/json" \
    -d "{\"nom\": \"$(json_escape "$nom")\", \"description\": \"$(json_escape "$description")\", \"quantite\": $quantite, \"prix\": $prix}" \
    >/dev/null

  echo "  + $nom"
}

# Compte le nombre de produits en base.
compter_produits() {
  curl -s "$API_URL/products" | grep -o '"_id"' | wc -l | tr -d ' '
}

# Injecte le jeu de test complet puis vérifie que le compte est bon.
lancer_jeu_de_test() {
  info "Injection du jeu de test..."
  for ligne in "${PRODUITS[@]}"; do
    IFS='|' read -r nom description quantite prix <<< "$ligne"
    ajouter_produit "$nom" "$description" "$quantite" "$prix"
  done

  local attendu=${#PRODUITS[@]}
  local reel
  reel=$(compter_produits)

  if [ "$reel" -eq "$attendu" ]; then
    ok "$reel produits en base (attendu : $attendu)."
  else
    ko "$reel produits en base alors qu'on en attendait $attendu."
    return 1
  fi
}

# Récupère la liste des produits et l'affiche.
lister_produits() {
  echo "Produits actuellement en base :"
  # On formate le JSON avec python si dispo, sinon brut.
  if command -v python3 >/dev/null 2>&1; then
    curl -s "$API_URL/products" | python3 -m json.tool
  else
    curl -s "$API_URL/products"
    echo
  fi
}

# Supprime tous les produits un par un (l'API n'a pas de "delete all").
vider_base() {
  echo "Suppression de tous les produits..."
  local ids
  ids=$(curl -s "$API_URL/products" | grep -o '"_id":[[:space:]]*"[^"]*"' | cut -d'"' -f4)

  if [ -z "$ids" ]; then
    echo "La base est déjà vide."
    return
  fi

  local total=0
  for id in $ids; do
    curl -s -X DELETE "$API_URL/product/$id" >/dev/null
    total=$((total + 1))
  done
  echo "Terminé : $total produits supprimés."
}

# Ajout manuel d'un produit via saisie.
ajout_manuel() {
  read -r -p "Nom : " nom
  read -r -p "Description : " description
  read -r -p "Quantité : " quantite
  read -r -p "Prix : " prix

  if [ -z "$nom" ] || [ -z "$quantite" ] || [ -z "$prix" ]; then
    echo "Nom, quantité et prix sont obligatoires. Annulé."
    return
  fi

  ajouter_produit "$nom" "$description" "$quantite" "$prix"
}

# Réinitialise : on vide puis on recharge le jeu de test.
reinitialiser() {
  vider_base
  lancer_jeu_de_test
}

# Check complet : vide la base, injecte le jeu de test et déroule un CRUD
# de bout en bout (create / read / update / delete) sur un produit témoin.
check_complet() {
  local echecs=0

  echo "${GRAS}=== Check complet ===${RESET}"

  # 1) Base propre au départ.
  vider_base >/dev/null
  if [ "$(compter_produits)" -eq 0 ]; then
    ok "Base vidée."
  else
    ko "La base n'est pas vide après suppression."; echecs=$((echecs + 1))
  fi

  # 2) Jeu de test et bon décompte.
  if lancer_jeu_de_test; then
    ok "Jeu de test injecté et compté."
  else
    ko "Le décompte du jeu de test est incorrect."; echecs=$((echecs + 1))
  fi

  # 3) Création d'un produit témoin et récupération de son id.
  local reponse id
  reponse=$(curl -s -X POST "$API_URL/product" \
    -H "Content-Type: application/json" \
    -d '{"nom": "Produit test", "description": "temoin CRUD", "quantite": 1, "prix": 1.0}')
  id=$(echo "$reponse" | grep -o '"id":[[:space:]]*"[^"]*"' | cut -d'"' -f4)

  if [ -n "$id" ]; then
    ok "Création : id renvoyé ($id)."
  else
    ko "Création : aucun id renvoyé."
    echo "${GRAS}Bilan : $((echecs + 1)) échec(s).${RESET}"
    return 1
  fi

  # 4) Lecture de la description.
  local desc
  desc=$(curl -s "$API_URL/product/description/$id" | grep -o '"description":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  if [ "$desc" = "temoin CRUD" ]; then
    ok "Lecture : description conforme."
  else
    ko "Lecture : description inattendue ('$desc')."; echecs=$((echecs + 1))
  fi

  # 5) Mise à jour du produit.
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$API_URL/product/$id" \
    -H "Content-Type: application/json" \
    -d '{"nom": "Produit test", "description": "maj", "quantite": 2, "prix": 2.0}')
  if [ "$code" = "200" ]; then
    ok "Mise à jour : HTTP 200."
  else
    ko "Mise à jour : HTTP $code."; echecs=$((echecs + 1))
  fi

  # 6) Suppression du produit témoin.
  code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/product/$id")
  if [ "$code" = "200" ]; then
    ok "Suppression : HTTP 200."
  else
    ko "Suppression : HTTP $code."; echecs=$((echecs + 1))
  fi

  echo
  if [ "$echecs" -eq 0 ]; then
    echo "${VERT}${GRAS}Bilan : tout est vert.${RESET}"
  else
    echo "${ROUGE}${GRAS}Bilan : $echecs échec(s).${RESET}"
    return 1
  fi
}

afficher_menu() {
  echo
  echo "${GRAS}=== Gestion des produits ($API_URL) ===${RESET}"
  echo "  ${JAUNE}1${RESET}) Lancer le jeu de test"
  echo "  ${JAUNE}2${RESET}) Vider la base"
  echo "  ${JAUNE}3${RESET}) Réinitialiser (vider + jeu de test)"
  echo "  ${JAUNE}4${RESET}) Lister les produits"
  echo "  ${JAUNE}5${RESET}) Ajouter un produit manuellement"
  echo "  ${JAUNE}6${RESET}) Check complet (CRUD de bout en bout)"
  echo "  ${JAUNE}q${RESET}) Quitter"
  echo
}

# Boucle principale du menu interactif.
if ! verifier_api; then
  exit 1
fi

while true; do
  afficher_menu
  read -r -p "Choix : " choix
  case "$choix" in
    1) lancer_jeu_de_test ;;
    2) vider_base ;;
    3) reinitialiser ;;
    4) lister_produits ;;
    5) ajout_manuel ;;
    6) check_complet ;;
    q|Q) echo "À bientôt."; break ;;
    *) echo "Choix invalide." ;;
  esac
done
