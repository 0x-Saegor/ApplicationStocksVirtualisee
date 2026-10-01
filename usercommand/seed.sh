#!/usr/bin/env bash
#
# Petit utilitaire pour peupler / vider la base de clients via l'API.
# On passe par les endpoints HTTP plutôt que d'attaquer MySQL directement,
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

# Quelques clients de départ pour avoir de quoi tester.
# Format : nom|prenom|email|nb_commande
CLIENTS=(
  "Durand|Marie|marie.durand@mail.com|3"
  "Martin|Paul|paul.martin@mail.com|1"
  "Bernard|Sophie|sophie.bernard@mail.com|0"
  "Petit|Luc|luc.petit@mail.com|7"
  "Robert|Julie|julie.robert@mail.com|2"
  "Richard|Thomas|thomas.richard@mail.com|5"
)

# Vérifie que curl est dispo, sinon on ne peut rien faire.
if ! command -v curl >/dev/null 2>&1; then
  echo "curl est requis mais introuvable. Installe-le puis relance."
  exit 1
fi

# Petit test de connexion avant de proposer le menu.
verifier_api() {
  if ! curl -s -o /dev/null "$API_URL/clients"; then
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

# Ajoute un client à partir de ses champs.
ajouter_client() {
  local nom="$1" prenom="$2" email="$3" nb_commande="$4"

  curl -s -X POST "$API_URL/client" \
    -H "Content-Type: application/json" \
    -d "{\"nom\": \"$(json_escape "$nom")\", \"prenom\": \"$(json_escape "$prenom")\", \"email\": \"$(json_escape "$email")\", \"nb_commande\": $nb_commande}" \
    >/dev/null

  echo "  + $prenom $nom"
}

# Compte le nombre de clients en base.
compter_clients() {
  curl -s "$API_URL/clients" | grep -o '"id"' | wc -l | tr -d ' '
}

# Injecte le jeu de test complet puis vérifie que le compte est bon.
lancer_jeu_de_test() {
  info "Injection du jeu de test..."
  for ligne in "${CLIENTS[@]}"; do
    IFS='|' read -r nom prenom email nb_commande <<< "$ligne"
    ajouter_client "$nom" "$prenom" "$email" "$nb_commande"
  done

  local attendu=${#CLIENTS[@]}
  local reel
  reel=$(compter_clients)

  if [ "$reel" -eq "$attendu" ]; then
    ok "$reel clients en base (attendu : $attendu)."
  else
    ko "$reel clients en base alors qu'on en attendait $attendu."
    return 1
  fi
}

# Récupère la liste des clients et l'affiche.
lister_clients() {
  echo "Clients actuellement en base :"
  # On formate le JSON avec python si dispo, sinon brut.
  if command -v python3 >/dev/null 2>&1; then
    curl -s "$API_URL/clients" | python3 -m json.tool
  else
    curl -s "$API_URL/clients"
    echo
  fi
}

# Supprime tous les clients un par un (l'API n'a pas de "delete all").
vider_base() {
  echo "Suppression de tous les clients..."
  local ids
  ids=$(curl -s "$API_URL/clients" | grep -o '"id":[[:space:]]*[0-9]*' | grep -o '[0-9]*')

  if [ -z "$ids" ]; then
    echo "La base est déjà vide."
    return
  fi

  local total=0
  for id in $ids; do
    curl -s -X DELETE "$API_URL/client/$id" >/dev/null
    total=$((total + 1))
  done
  echo "Terminé : $total clients supprimés."
}

# Ajout manuel d'un client via saisie.
ajout_manuel() {
  read -r -p "Nom : " nom
  read -r -p "Prénom : " prenom
  read -r -p "Email : " email
  read -r -p "Nombre de commandes : " nb_commande

  if [ -z "$nom" ] || [ -z "$prenom" ] || [ -z "$email" ]; then
    echo "Nom, prénom et email sont obligatoires. Annulé."
    return
  fi
  # Valeur par défaut si le champ est laissé vide.
  nb_commande="${nb_commande:-0}"

  ajouter_client "$nom" "$prenom" "$email" "$nb_commande"
}

# Réinitialise : on vide puis on recharge le jeu de test.
reinitialiser() {
  vider_base
  lancer_jeu_de_test
}

# Check complet : vide la base, injecte le jeu de test et déroule un CRUD
# de bout en bout (create / read / update / delete) sur un client témoin.
check_complet() {
  local echecs=0

  echo "${GRAS}=== Check complet ===${RESET}"

  # 1) Base propre au départ.
  vider_base >/dev/null
  if [ "$(compter_clients)" -eq 0 ]; then
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

  # 3) Création d'un client témoin et récupération de son id.
  local reponse id
  reponse=$(curl -s -X POST "$API_URL/client" \
    -H "Content-Type: application/json" \
    -d '{"nom": "Test", "prenom": "Temoin", "email": "temoin@mail.com", "nb_commande": 1}')
  id=$(echo "$reponse" | grep -o '"id":[[:space:]]*[0-9]*' | grep -o '[0-9]*')

  if [ -n "$id" ]; then
    ok "Création : id renvoyé ($id)."
  else
    ko "Création : aucun id renvoyé."
    echo "${GRAS}Bilan : $((echecs + 1)) échec(s).${RESET}"
    return 1
  fi

  # 4) Lecture de la fiche client.
  local email
  email=$(curl -s "$API_URL/client/$id" | grep -o '"email":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
  if [ "$email" = "temoin@mail.com" ]; then
    ok "Lecture : fiche conforme."
  else
    ko "Lecture : email inattendu ('$email')."; echecs=$((echecs + 1))
  fi

  # 5) Mise à jour de la fiche client.
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$API_URL/client/$id" \
    -H "Content-Type: application/json" \
    -d '{"nom": "Test", "prenom": "Temoin", "email": "temoin@mail.com", "nb_commande": 9}')
  if [ "$code" = "200" ]; then
    ok "Mise à jour : HTTP 200."
  else
    ko "Mise à jour : HTTP $code."; echecs=$((echecs + 1))
  fi

  # 6) Suppression du client témoin.
  code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/client/$id")
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
  echo "${GRAS}=== Gestion des clients ($API_URL) ===${RESET}"
  echo "  ${JAUNE}1${RESET}) Lancer le jeu de test"
  echo "  ${JAUNE}2${RESET}) Vider la base"
  echo "  ${JAUNE}3${RESET}) Réinitialiser (vider + jeu de test)"
  echo "  ${JAUNE}4${RESET}) Lister les clients"
  echo "  ${JAUNE}5${RESET}) Ajouter un client manuellement"
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
    4) lister_clients ;;
    5) ajout_manuel ;;
    6) check_complet ;;
    q|Q) echo "À bientôt."; break ;;
    *) echo "Choix invalide." ;;
  esac
done
