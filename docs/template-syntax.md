# Syntaxe des Templates — Référence

Le moteur de résolution de templates remplace les placeholders `((…))` dans tous les champs
texte des commandes (réponses, embeds, payloads d'actions, etc.).

> **Source** : `packages/shared/lib/utils/template_resolver.dart`

---

## 1. Syntaxe de base

```
((nomDeLaVariable))
```

- Délimiteurs : `((` et `))`
- Insensible à la casse
- La variable correspondante est recherchée dans le dictionnaire runtime (`Map<String, String>`)
- Si la variable **n'existe pas** → remplacée par `""` (chaîne vide) — **jamais** laissée telle quelle

---

## 2. Fallback (valeur de secours)

Plusieurs clés peuvent être séparées par `|`. La première clé trouvée dans le dictionnaire
est utilisée. Si aucune n'est trouvée, le résultat est `""`.

```
((opts.cible|userName))
```

→ Retourne la valeur de `opts.cible` si elle existe, sinon la valeur de `userName`.

---

## 3. Extraction JSONPath (depuis une variable contenant du JSON)

Pour une action ayant `key: "monHttp"` et dont le `body` est un JSON :

```
((monHttp.body.$.propriete))
((monHttp.body.$.liste[0].champ))
((monHttp.body.$.a.b.c))
```

Format complet : `<key>.body.$.<chemin JSONPath>`

| Segment        | Description                         |
|----------------|-------------------------------------|
| `<key>`        | Clé de l'action (champ `key`)       |
| `.body`        | Marqueur : lecteur du corps JSON    |
| `.$`           | Racine du document JSON             |
| `.propriete`   | Accès à un champ objet              |
| `[0]`          | Accès à un index de liste           |

Le résultat est :
- **string** → retourné tel quel
- **number / bool** → converti en string
- **object / array** → sérialisé en JSON
- **null / absent** → `""` (chaîne vide)

---

## 4. Comportements importants

| Situation | Résultat |
|-----------|----------|
| Variable connue | Valeur de la variable |
| Variable inconnue | `""` (chaîne vide) |
| Fallback : première clé connue | Valeur de cette clé |
| Fallback : aucune clé connue | `""` |
| JSONPath invalide / JSON malformé | `""` |
| Variable dans un champ URL (embed) | Validée en plus par `resolveEmbedUri()` — voir ci-dessous |

---

## 5. Résolution dans les champs URL (`resolveEmbedUri`)

Pour les champs URL des embeds (`image.url`, `thumbnail.url`, `footer.icon_url`,
`author.url`, `author.icon_url`), la résolution passe par une étape supplémentaire :

```
raw string
  → resolveTemplatePlaceholders()  → string résolue
  → Uri.tryParse()                 → Uri?
  → uri.hasScheme ?                → Uri (retourné) | null (champ ignoré)
```

**Conséquence** : si la variable n'existe pas (résolution → `""`), ou si l'URL résolue
n'a pas de scheme (`https://` ou `http://`), le champ est **silencieusement supprimé**
de l'embed envoyé à Discord.

---

## 6. Exemples complets

### Texte simple
```
Bonjour ((userName)), bienvenue sur ((guildName)) !
```
→ `Bonjour JohnDoe, bienvenue sur Mon Serveur !`

### Fallback
```
Utilisateur ciblé : ((opts.cible|userName))
```
→ Si l'option `cible` existe : son nom. Sinon : le nom de l'invocateur.

### URL d'image (avatar d'une option user)
```json
{ "image": { "url": "((opts.cible.avatar))" } }
```
→ `https://cdn.discordapp.com/avatars/456/def.webp?size=1024` ✅

### JSONPath
```
Résultat : ((monHttp.body.$.data.username))
```
→ Extrait `body.data.username` depuis la réponse JSON de l'action `monHttp`.

### Erreur silencieuse typique
```json
{ "thumbnail": { "url": "((user.avatar))" } }
```
→ `user.avatar` n'est **pas** une variable valide.  
→ Résolution → `""` → `resolveEmbedUri` → `null` → thumbnail absente.  
→ **Correction** : utiliser `((userAvatar))` pour l'invocateur ou `((opts.X.avatar))`
  pour une option.
