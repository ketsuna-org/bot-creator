# Format des Commandes — Référence complète

Ce document décrit le format JSON complet des commandes tel qu'il est **stocké sur disque**,
**normalisé au chargement**, et **transmis à l'exécution**.

---

## 1. Fichier sur disque

Chaque commande est stockée dans :
```
<appDataDir>/apps/<botUserId>/<commandId>.json
```
> Écrit par `database.dart › saveAppCommand()` puis lu par `normalizeCommandData()`.

### Structure racine

```jsonc
{
  "name": "ma-commande",          // string — nom Discord de la commande
  "description": "...",           // string
  "id": "123456789",              // string (Snowflake Discord)
  "createdAt": "2025-01-01T00:00:00.000Z",   // ISO 8601 (create) | "updatedAt" (update)
  "data": { /* <CommandData> */ }
}
```

---

## 2. `CommandData` — objet `data`

```jsonc
{
  "version": 1,                          // int — toujours 1 actuellement
  "editorMode": "simple" | "advanced",   // string
  "defaultMemberPermissions": "",        // string — bitfield Discord (ex: "8" = ADMINISTRATOR)
  "simpleConfig": { /* <SimpleConfig> */ },
  "response":    { /* <Response> */ },
  "actions":     [ /* <Action>[] */ ]
}
```

### 2.1 `SimpleConfig`

Utilisé uniquement quand `editorMode == "simple"`.

```jsonc
{
  "deleteMessages":   false,   // bool
  "kickUser":         false,   // bool
  "banUser":          false,   // bool
  "muteUser":         false,   // bool
  "addRole":          false,   // bool
  "removeRole":       false,   // bool
  "sendMessage":      false,   // bool
  "sendMessageText":  ""       // string — texte à envoyer si sendMessage == true
}
```

---

### 2.2 `Response`

```jsonc
{
  "mode": "text" | "embed",         // "embed" si embeds[] non vide, sinon "text"
  "type": "normal" | "ephemeral" | "componentV2",
  "text": "Bonjour ((userName)) !",  // string — supports ((variables))
  "embed": { /* <Embed> */ },         // legacy (= embeds[0]) — conservé pour compatibilité
  "embeds": [ /* <Embed>[] */ ],      // tableau de 1 à 10 embeds
  "components": { /* <ComponentV2Definition> */ },
  "modal":    { /* <ModalDefinition> */ },
  "workflow": { /* <Workflow> */ }
}
```

#### 2.2.1 `Embed`

Tous les champs **string** supportent les `((variables))` de template.  
Les champs **URL** (`image.url`, `thumbnail.url`, `footer.icon_url`, `author.url`,
`author.icon_url`) passent en plus par `resolveEmbedUri()` qui **valide** que l'URL
résolue possède un scheme (`https://…`). Si le template produit une chaîne vide
ou une URL sans scheme, le champ est **silencieusement ignoré**.

```jsonc
{
  "title":       "((guildName)) — Stats",         // string | vide
  "description": "Bienvenue ((userName)) !",       // string | vide
  "url":         "https://exemple.com",             // string URL | vide
  "color":       "#5865F2",                         // string hex "#RRGGBB" ou int décimal
  "timestamp":   "2025-01-01T12:00:00.000Z",       // string ISO 8601 | vide
  "image": {
    "url": "((userAvatar))"                         // ⚠ doit résoudre en URL valide avec scheme
  },
  "thumbnail": {
    "url": "((opts.cible.avatar))"                  // ⚠ idem
  },
  "footer": {
    "text":     "Réponse demandée par ((userName))",
    "icon_url": "((userAvatar))"                    // ⚠ idem
  },
  "author": {
    "name":         "((userName))",
    "url":          "https://…",                    // ⚠ URL avec scheme
    "icon_url":     "((userAvatar))",               // ⚠ idem — clé alternative : author_icon_url
    "author_icon_url": "((userAvatar))"             // alias de icon_url (les deux sont lus)
  },
  "fields": [
    {
      "name":   "Champ",       // string non vide (requis)
      "value":  "Valeur",      // string non vide (requis)
      "inline": false          // bool
    }
  ]
}
```

> **Règle importante** : un field dont `name` ou `value` est vide après résolution
> est **ignoré** (Discord rejette les fields vides).

#### 2.2.2 `Workflow`

```jsonc
{
  "autoDeferIfActions": true,              // bool — defer automatique si des actions existent
  "visibility": "public" | "ephemeral",   // string
  "onError": "edit_error",                // string — comportement en cas d'erreur
  "conditional": {
    "enabled":       false,               // bool
    "variable":      "((maVariable))",    // string — variable à évaluer (truthy/falsy)
    "whenTrueType":  "normal" | "text" | "embed" | "componentV2",
    "whenFalseType": "normal" | "text" | "embed" | "componentV2",
    "whenTrueText":  "...",
    "whenFalseText": "...",
    "whenTrueEmbeds":  [ /* <Embed>[] */ ],
    "whenFalseEmbeds": [ /* <Embed>[] */ ],
    "whenTrueNormalComponents":  { /* <ComponentV2Definition> */ },
    "whenFalseNormalComponents": { /* <ComponentV2Definition> */ },
    "whenTrueComponents":        { /* <ComponentV2Definition> */ },
    "whenFalseComponents":       { /* <ComponentV2Definition> */ },
    "whenTrueModal":             { /* <ModalDefinition> */ },
    "whenFalseModal":            { /* <ModalDefinition> */ }
  }
}
```

---

### 2.3 `Action`

```jsonc
{
  "type":     "sendMessage",    // string — voir BotCreatorActionType
  "key":      "step1",         // string? — identifiant libre
  "enabled":  true,             // bool
  "depend_on": [],              // List<String> — keys des actions précédentes à attendre
  "error":    {},               // Map<String, String> — messages d'erreur personnalisés
  "payload":  { /* ... */ }     // Map<String, dynamic> — données spécifiques au type
}
```

#### Types d'actions disponibles (`BotCreatorActionType`)

| Valeur (`type`)           | Description                            |
|---------------------------|----------------------------------------|
| `deleteMessages`          | Supprimer des messages                |
| `createChannel`           | Créer un salon                        |
| `updateChannel`           | Modifier un salon                     |
| `removeChannel`           | Supprimer un salon                    |
| `sendMessage`             | Envoyer un message                    |
| `editMessage`             | Modifier un message existant          |
| `addReaction`             | Ajouter une réaction                  |
| `removeReaction`          | Retirer une réaction                  |
| `clearAllReactions`       | Vider toutes les réactions            |
| `banUser`                 | Bannir un membre                      |
| `unbanUser`               | Débannir                              |
| `kickUser`                | Expulser un membre                    |
| `muteUser`                | Rendre muet (timeout)                 |
| `unmuteUser`              | Retirer le timeout                    |
| `addRole`                 | Attribuer un rôle                     |
| `removeRole`              | Retirer un rôle                       |
| `pinMessage`              | Épingler un message                   |
| `updateAutoMod`           | Modifier l'auto-modération            |
| `updateGuild`             | Modifier le serveur                   |
| `listMembers`             | Lister des membres                    |
| `getMember`               | Récupérer un membre                   |
| `sendComponentV2`         | Envoyer des composants V2             |
| `editComponentV2`         | Modifier des composants V2            |
| `sendWebhook`             | Envoyer via webhook                   |
| `editWebhook`             | Modifier un webhook                   |
| `deleteWebhook`           | Supprimer un webhook                  |
| `listWebhooks`            | Lister les webhooks                   |
| `getWebhook`              | Récupérer un webhook                  |
| `makeList`                | Construire une liste                  |
| `httpRequest`             | Requête HTTP externe                  |
| `setGlobalVariable`       | Définir une variable globale          |
| `getGlobalVariable`       | Lire une variable globale             |
| `removeGlobalVariable`    | Supprimer une variable globale        |
| `listGlobalVariables`     | Lister les variables globales         |
| `runWorkflow`             | Exécuter un autre workflow            |
| `respondWithMessage`      | Répondre à l'interaction (texte)      |
| `respondWithComponentV2`  | Répondre avec composants V2           |
| `respondWithModal`        | Ouvrir un modal                       |
| `editInteractionMessage`  | Modifier la réponse initiale          |
| `listenForButtonClick`    | Attendre un clic de bouton            |
| `listenForModalSubmit`    | Attendre la soumission d'un modal     |

---

## 3. Cycle de vie complet

```
[Éditeur App]
    │  commandData = { version, editorMode, simpleConfig, response, actions, … }
    │
    ▼
createCommand() / updateCommand()   (bot.dart)
    │  Wrap : { name, description, id, createdAt, data: commandData }
    │
    ▼
saveAppCommand()   (database.dart)
    │  Écrit : normalizeCommandData(data) → JSON sur disque
    │
    ▼
[Fichier <commandId>.json sur disque]
    │
    ▼
normalizeCommandData()   (database.dart, au chargement dans l'éditeur)
    │  Lit   : command['data']['editorMode'], ['simpleConfig'], ['response'], ['actions']
    │  Écrit : normalized['data'] = { version, editorMode, simpleConfig, … }
    │
    ▼
[Runner — exécution de la commande]
    │  generateKeyValues(interaction)   → Map<String, String> runtimeVariables
    │  resolveTemplatePlaceholders(str, runtimeVariables)  → string résolu
    │  resolveEmbedUri(raw)             → Uri? (null si invalide/vide)
    │
    ▼
[Réponse Discord envoyée]
```

---

## 4. Points critiques & pièges

| Piège | Explication |
|-------|-------------|
| `editorMode` doit être dans `data`, **pas** à la racine | `normalizeCommandData` lit `command['data']['editorMode']`. Si absent → défaut `"advanced"`. |
| Champ URL vide après résolution → silencieusement ignoré | `resolveEmbedUri` retourne `null` si le résultat est vide ou sans scheme HTTP. |
| Variable inconnue → remplacée par `""` | `resolveTemplatePlaceholders` remplace tout `((inconnue))` par une chaîne vide (voir [template-syntax.md](./template-syntax.md)). |
| `embed` racine vs `embeds[]` | `embed` est le legacy (1 embed). `embeds` remplace. À la normalisation : si `embeds` est vide et `embed` non vide → `embed` est copié dans `embeds[0]`. |
| Limite Discord | Maximum **10 embeds** par message (`embeds.take(10)`), **25 fields** par embed. |
