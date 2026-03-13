# Documentation — Bot Creator

Vue d'ensemble de la documentation technique interne du projet.

---

## Index

| Document | Contenu |
|----------|---------|
| [command-format.md](./command-format.md) | Format JSON complet d'une commande (stockage, normalisation, cycle de vie) |
| [runtime-variables.md](./runtime-variables.md) | Toutes les variables `((…))` disponibles à l'exécution |
| [template-syntax.md](./template-syntax.md) | Syntaxe du moteur de templates (fallback, JSONPath, URLs) |

---

## Architecture rapide

```
packages/
├── app/           Application Flutter (éditeur de commandes)
│   ├── lib/routes/app/command.create.dart   Éditeur de commandes (UI + sauvegarde)
│   ├── lib/utils/bot.dart                   createCommand() / updateCommand()
│   └── lib/utils/database.dart              normalizeCommandData() + persistance JSON
│
├── shared/        Code partagé App + Runner
│   ├── lib/utils/global.dart                generateKeyValues() → variables runtime
│   ├── lib/utils/template_resolver.dart     resolveTemplatePlaceholders()
│   ├── lib/actions/interaction_response.dart Résolution + envoi de la réponse Discord
│   └── lib/types/action.dart               BotCreatorActionType + classe Action
│
└── runner/        Runner autonome (exécution des commandes)
    └── lib/discord_runner.dart              Point d'entrée exécution commandes
```

---

## Principe clé : où lire `editorMode` ?

```
Fichier sur disque : { name, id, data: { editorMode, response, actions, … } }
                                  ^^^^
normalizeCommandData lit : command['data']['editorMode']   ← toujours dans 'data'
```

`editorMode` est dans `command['data']`, **jamais** à la racine du command record.
