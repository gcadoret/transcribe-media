# Transcription locale + structuration facultative

Mac Apple Silicon / zsh. Nécessite `ffmpeg`, `openai-whisper`, `python3` et l'accès à Internet uniquement pour la première récupération du modèle Whisper et pour l'option OpenAI.

Les fichiers obtenus sont dans **le même dossier que `transcript.sh`**.

## Installation

```bash
brew install ffmpeg openai-whisper
chmod +x transcript.sh
```

## Transcription seule, locale

```bash
./transcript.sh
```

Cette commande trouve le MKV le plus récemment modifié dans `~/Movies`, extrait sa première piste audio en MP3, puis transcrit en français avec `whisper --model small`.

## Transcription + réécriture structurée (API OpenAI)

Entrez la clé sans l'inscrire dans l'historique du terminal :

```zsh
read -rs "OPENAI_API_KEY?Clé OpenAI : "
echo
export OPENAI_API_KEY
./transcript.sh --structure
```

La clé reste dans l'environnement du terminal et est transmise au processus en arrière-plan. La transcription est envoyée à l'API OpenAI uniquement pour l'étape de mise en forme. L'usage de l'API est facturé séparément de ChatGPT.

## Structurer une transcription déjà existante sans relancer Whisper

```bash
python3 structure.py "2026-10-28 15-27-27.txt"
```

## Suivre un traitement

```bash
tail -f "2026-10-28 15-27-27.log"
```

Remplacez le nom par celui du dernier MKV. `Ctrl+C` quitte seulement le suivi des logs, pas la transcription.

## Résultats

- `<nom-du-mkv>.mp3` : MP3 extrait
- `<nom-du-mkv>.txt` : transcription brute
- `<nom-du-mkv>.structure.md` : version structurée (option `--structure` ou script manuel)
- `<nom-du-mkv>.log` : journal

## Personnalisation

- Modèle Whisper : modifier `MODEL="small"` dans `transcript.sh`.
- Modèle de rédaction : `export OPENAI_MODEL="gpt-6-luna"` (valeur par défaut).
- Pour utiliser le **répertoire courant du terminal** plutôt que le répertoire du script : remplacer `OUTPUT="$ROOT"` par `OUTPUT="$PWD"` dans `transcript.sh`.

Ne mettez jamais la clé API dans le script ou dans un dépôt Git. Le Mac doit rester allumé ; `caffeinate` évite la veille automatique, sans empêcher celle provoquée par la fermeture du capot d'un MacBook.
