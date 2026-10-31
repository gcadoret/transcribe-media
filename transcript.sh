#!/bin/zsh
# Dernier MKV (par défaut), ou vidéo choisie -> MP3 -> Whisper -> Markdown IA facultatif.
# Résultats sauvegardés dans le dossier de ce script.
set -e

SCRIPT="${0:A}"
ROOT="${SCRIPT:h}"
MOVIES="$HOME/Movies"
OUTPUT="$ROOT"
MODEL="small"

# Charge les variables de .env, si présent (dans le dossier du script).
if [[ -f "$ROOT/.env" ]]; then
    set -a
    source "$ROOT/.env"
    set +a
fi

worker() {
    local video="$1" output="$2" ffmpeg="$3" whisper="$4" python="$5" use_ai="$6"
    local name="${video:t:r}"
    local mp3="$output/$name.mp3"
    local txt="$output/$name.txt"

    echo "[$(date '+%F %T')] Vidéo : $video"
    echo "[$(date '+%F %T')] Extraction MP3"
    "$ffmpeg" -hide_banner -loglevel error -nostdin -y \
        -i "$video" -map 0:a:0 -vn \
        -c:a libmp3lame -q:a 2 "$mp3"

    echo "[$(date '+%F %T')] Transcription Whisper ($MODEL)"
    "$whisper" "$mp3" \
        --model "$MODEL" \
        --language French \
        --output_format txt \
        --output_dir "$output" \
        --device cpu

    if [[ "$use_ai" == "1" ]]; then
        echo "[$(date '+%F %T')] Structuration OpenAI"
        "$python" "$ROOT/structure.py" "$txt"
    fi

    echo "[$(date '+%F %T')] Terminé. Résultats dans : $output"
}

# Mode interne de traitement détaché.
if [[ "${1:-}" == "--worker" ]]; then
    shift
    worker "$@"
    exit 0
fi

usage() {
    cat <<'HELP'
Usage : ./transcript.sh [chemin_video] [--structure]

Sans chemin : sélectionne le MKV le plus récemment modifié de ~/Movies.
Avec chemin : transcrit la vidéo désignée (MKV, MP4, MOV... selon FFmpeg).
--structure : produit aussi un Markdown via l'API OpenAI (.env).

Exemples :
  ./transcript.sh
  ./transcript.sh --structure
  ./transcript.sh "video.mkv"
  ./transcript.sh --structure "$HOME/Movies/video avec espaces.mkv"
HELP
}

USE_AI=0
VIDEO_ARG=""
for arg in "$@"; do
    case "$arg" in
        --structure)
            USE_AI=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            echo "Option inconnue : $arg" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$VIDEO_ARG" ]]; then
                echo "Erreur : indique une seule vidéo." >&2
                usage >&2
                exit 2
            fi
            VIDEO_ARG="$arg"
            ;;
    esac
done

if [[ -n "$VIDEO_ARG" ]]; then
    VIDEO="${VIDEO_ARG:A}"
    if [[ ! -f "$VIDEO" || ! -r "$VIDEO" ]]; then
        echo "Erreur : fichier vidéo introuvable ou illisible : $VIDEO" >&2
        exit 1
    fi
    echo "Vidéo choisie : $VIDEO"
else
    setopt NO_CASE_GLOB
    FILES=( "$MOVIES"/*.mkv(N.om[1]) )
    if (( ${#FILES} == 0 )); then
        echo "Aucun MKV dans $MOVIES" >&2
        exit 1
    fi
    VIDEO="${FILES[1]:A}"
    echo "Dernier MKV : $VIDEO"
fi

FFMPEG="$(command -v ffmpeg || true)"
WHISPER="$(command -v whisper || true)"
PYTHON="$(command -v python3 || true)"

if [[ -z "$FFMPEG" || -z "$WHISPER" ]]; then
    echo "Erreur : ffmpeg ou whisper introuvable dans PATH." >&2
    exit 1
fi
if [[ "$USE_AI" == "1" && -z "$PYTHON" ]]; then
    echo "Erreur : python3 introuvable dans PATH." >&2
    exit 1
fi
if [[ "$USE_AI" == "1" && -z "${OPENAI_API_KEY:-}" ]]; then
    echo "Erreur : OPENAI_API_KEY absente. Ajoute-la dans $ROOT/.env" >&2
    exit 1
fi

NAME="${VIDEO:t:r}"
LOG="$OUTPUT/$NAME.log"

echo "Destination : $OUTPUT"

# Détaché du terminal, et le Mac reste éveillé durant le traitement.
nohup /usr/bin/caffeinate -i /bin/zsh "$SCRIPT" --worker \
    "$VIDEO" "$OUTPUT" "$FFMPEG" "$WHISPER" "$PYTHON" "$USE_AI" \
    > "$LOG" 2>&1 < /dev/null &

echo "Lancé en arrière-plan (PID : $!)"
echo "Logs : tail -f \"$LOG\""
echo "MP3 : $OUTPUT/$NAME.mp3"
echo "Texte : $OUTPUT/$NAME.txt"
if [[ "$USE_AI" == "1" ]]; then
    echo "Version structurée : $OUTPUT/$NAME.structure.md"
fi
