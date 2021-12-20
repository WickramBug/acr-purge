#!/bin/bash

# WARNING! This script deletes data!
# Run only if you do not have systems
# that pull images via manifest digest.

# Change to 'true' to enable image lock
LOCK_ENABLED=true

# Change to 'true' to enable tag and manifest deletion
DELETE_ENABLED=true

# TIMESTAMP can be a date-time string such as 2019-03-15T17:55:00.
REGISTRY=wickramContainerRegistry001
REPOSITORY=hi_mom_nginx
TIMESTAMP="2021-12-16T10:05:31.1581706Z"
PURGE_CMD=""

if [ $LOCK_ENABLED = true ]; then
    image_tags=$(az acr repository show-manifests --name $REGISTRY --repository $REPOSITORY \
        --top 5 --orderby time_desc -o tsv --query "[?timestamp <= '$TIMESTAMP'].[tags[0]]")

    if [ ! -z "${image_tags}" ]; then
        for image_tag in $image_tags; do
            echo "----------------------------------------------------------------------------------"
            echo "Locking image tag: "$REPOSITORY":"$image_tag
            az acr repository update \
                --name wickramContainerRegistry001 --image hi_mom_nginx:$image_tag \
                --delete-enabled false --write-enabled false
            echo "Locking image COMPLETED for tag: "$REPOSITORY":"$image_tag
            echo "----------------------------------------------------------------------------------"
        done

        # Delete all images older than specified timestamp.
        if [ $DELETE_ENABLED = true ]; then
            PURGE_CMD="acr purge --filter 'hi_mom_nginx:.*' \
            --ago 0d --keep 2 --untagged --dry-run"

            echo "Purging task initiated... "
            az acr run \
                --cmd "$PURGE_CMD" \
                --registry wickramContainerRegistry001 \
                /dev/null

        else
            echo "No data deleted."
            echo "Set DELETE_ENABLED=true to enable tags and manifests deletion in repository: $REPOSITORY"
        fi

    else
        echo "No images found to be deleted!!!"
    fi

else
    echo "Set LOCK_ENABLED=true to enable image locking in repository: $REPOSITORY"
    echo "----------------------------------------------------------------------------------"
    az acr repository show-manifests --name $REGISTRY --repository $REPOSITORY \
        --top 5 --orderby time_asc --query "[?timestamp <= '$TIMESTAMP'].[digest, tags[0], timestamp]" -o tsv
fi
