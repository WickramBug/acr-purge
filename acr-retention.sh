REGISTRY=wickramContainerRegistry001
REPOSITORY=hi_mom_nginx
PURGE_CMD=""
PRESENT_TAGS=()
FILE="acr-image-state.txt"

# Check state file availability
if [ -f "$FILE" ]; then
    # Read state file to an array
    readarray -t PRESENT_TAGS <"$FILE"

    # Get array size
    PRESENT_TAGS_SIZE=${#PRESENT_TAGS[@]}

    # Check array size
    if ((${#PRESENT_TAGS[@]})); then
        for present_tag in "${PRESENT_TAGS[@]}"; do
            echo "----------------------------------------------------------------------------------"
            echo "Locking image tag: "$REPOSITORY":"$present_tag
            az acr repository update \
                --name wickramContainerRegistry001 --image hi_mom_nginx:$present_tag \
                --delete-enabled false --write-enabled false
            echo "Locking image COMPLETED for tag: "$REPOSITORY":"$present_tag
            echo "----------------------------------------------------------------------------------"
        done
    else
        echo "State file doesn't have any images!"
    fi
fi
