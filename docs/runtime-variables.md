# Variables de Template — Référence complète

Les variables sont utilisées dans tous les champs texte des commandes via la syntaxe
`((nomDeLaVariable))`. Elles sont résolues au moment de l'exécution par le Runner.

> **Source** : `packages/shared/lib/utils/global.dart` — `generateKeyValues()`  
> **Résolution** : `packages/shared/lib/utils/template_resolver.dart` — `resolveTemplatePlaceholders()`

---

## 1. Variables globales (toujours disponibles)

Ces variables sont générées à partir de l'interaction Discord, quelle que soit la commande.

| Variable              | Valeur                                                          | Exemple                                              |
|-----------------------|-----------------------------------------------------------------|------------------------------------------------------|
| `((userName))`        | Nom d'utilisateur du membre qui a exécuté la commande           | `JohnDoe`                                            |
| `((userId))`          | ID Snowflake du membre                                          | `123456789012345678`                                 |
| `((userUsername))`    | Username Discord (identique à `userName`)                       | `johndoe`                                            |
| `((userTag))`         | Discriminant (ex-tag) `#0000`                                   | `0` (vide pour nouveaux comptes)                     |
| `((userAvatar))`      | URL CDN complète de l'avatar du membre                          | `https://cdn.discordapp.com/avatars/…/….webp?size=1024` |
| `((guildName))`       | Nom du serveur                                                  | `Mon Serveur`                                        |
| `((guildId))`         | ID Snowflake du serveur                                         | `987654321098765432`                                 |
| `((guildCount))`      | Nombre de membres approximatif                                  | `142`                                                |
| `((guildIcon))`       | URL CDN de l'icône du serveur                                   | `https://cdn.discordapp.com/icons/…/….webp?size=1024`|
| `((channelName))`     | Nom du salon                                                    | `général`                                            |
| `((channelId))`       | ID Snowflake du salon                                           | `111122223333444455`                                 |
| `((channelType))`     | Type de salon (`GuildTextChannel`, `DmChannel`, …)              | `GuildTextChannel`                                   |
| `((commandName))`     | Nom de la commande slash exécutée                               | `stats`                                              |
| `((commandId))`       | ID Snowflake de la commande                                     | `555566667777888899`                                 |

---

## 2. Variables d'options de commande

Pour chaque option de commande slash définie, des variables préfixées `opts.` sont générées.

### Préfixe `opts.<nomOption>`

Le préfixe `opts.` est **toujours présent**, y compris pour les sous-commandes.

#### Option de type `string`, `integer`, `number`, `boolean`

| Variable                    | Valeur                          |
|-----------------------------|---------------------------------|
| `((opts.<nomOption>))`      | Valeur de l'option (string)     |

#### Option de type `user`

| Variable                         | Valeur                                                    |
|----------------------------------|-----------------------------------------------------------|
| `((opts.<nomOption>))`           | Nom d'utilisateur Discord                                 |
| `((opts.<nomOption>.id))`        | ID Snowflake de l'utilisateur                             |
| `((opts.<nomOption>.avatar))`    | URL CDN complète de l'avatar — **valide avec scheme** ✅  |

#### Option de type `channel`

| Variable                         | Valeur                        |
|----------------------------------|-------------------------------|
| `((opts.<nomOption>))`           | Nom du salon                  |
| `((opts.<nomOption>.id))`        | ID Snowflake du salon         |
| `((opts.<nomOption>.type))`      | Type du salon (string)        |

#### Option de type `role`

| Variable                         | Valeur                        |
|----------------------------------|-------------------------------|
| `((opts.<nomOption>))`           | Nom du rôle                   |
| `((opts.<nomOption>.id))`        | ID Snowflake du rôle          |

#### Option de type `mentionable`

| Variable                         | Valeur                                                    |
|----------------------------------|-----------------------------------------------------------|
| `((opts.<nomOption>))`           | Nom d'utilisateur                                         |
| `((opts.<nomOption>.id))`        | ID Snowflake                                              |
| `((opts.<nomOption>.avatar))`    | URL CDN complète de l'avatar — **valide avec scheme** ✅  |

### Sous-commandes & groupes de sous-commandes

Les options des sous-commandes sont également préfixées `opts.` (le nom de la sous-commande
elle-même est stocké dans `listOfArgs[subCommandName]` **sans** le préfixe `opts.`).

---

## 3. Variables issues d'actions (runtime)

Certaines actions stockent leurs résultats dans des variables accessibles aux actions suivantes
(via `key` de l'action). Consultez la documentation de chaque action pour les clés générées.

Exemple pour `httpRequest` avec `key: "monHttp"` :

| Variable                                | Valeur                                  |
|-----------------------------------------|-----------------------------------------|
| `((monHttp.body))`                      | Corps de la réponse HTTP (string brut)  |
| `((monHttp.body.$.champ))`              | Extraction JSONPath depuis le corps     |
| `((monHttp.body.$.liste[0].propriete))` | Extraction JSONPath avec index de liste |

---

## 4. Cas d'usage pour les URLs d'embed

Les champs URL (`image.url`, `thumbnail.url`, `footer.icon_url`, `author.url`,
`author.icon_url`) sont traités par `resolveEmbedUri()` qui **exige que l'URL résolue
possède un scheme** (`https://` ou `http://`).

### ✅ Exemples valides

```
((userAvatar))
  → https://cdn.discordapp.com/avatars/123/abc.webp?size=1024   ✓ scheme présent

((opts.cible.avatar))
  → https://cdn.discordapp.com/avatars/456/def.webp?size=1024   ✓ scheme présent

https://exemple.com/image.png
  → https://exemple.com/image.png                               ✓ URL statique
```

### ❌ Exemples invalides (champ ignoré silencieusement)

```
((mauvaise))
  → ""                    ✗ variable inconnue → chaîne vide → ignoré

cdn.discordapp.com/…
  → cdn.discordapp.com/…  ✗ pas de scheme → ignoré

((user.avatar))           ✗ MAUVAIS NOM — la variable correcte est ((userAvatar))
((avatar))                ✗ MAUVAIS NOM — la variable correcte est ((userAvatar))
```

---

## 5. Récapitulatif rapide (cheat sheet)

```
Invocateur de la commande :
  ((userName))        nom d'utilisateur
  ((userId))          ID Snowflake
  ((userAvatar))      URL de l'avatar

Serveur :
  ((guildName))       nom du serveur
  ((guildId))         ID du serveur
  ((guildCount))      nombre de membres
  ((guildIcon))       icône du serveur

Salon :
  ((channelName))     nom du salon
  ((channelId))       ID du salon

Commande :
  ((commandName))     /nomdelacommande

Option <X> de type user :
  ((opts.X))          nom d'utilisateur
  ((opts.X.id))       ID
  ((opts.X.avatar))   URL avatar ← UTILISER POUR LES IMAGES

Option <X> de type string/int/bool/number :
  ((opts.X))          valeur brute

Fallback (séparateur |) :
  ((opts.X|userName)) → opts.X si défini, sinon userName
```
