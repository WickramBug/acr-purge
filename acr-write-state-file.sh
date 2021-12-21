# Declare variables
PRESENT_TAGS=()
FILE="acr-image-state.txt"
REGISTRY=wickramContainerRegistry001
REPOSITORY=hi_mom_nginx
DIGEST="sha256:5ef43aba3beef6f73965d6ce357e041af0174e3739ae110693d4c363cf2028ac"

# Get the production image tag
image_tag=$(az acr repository show-manifests --name $REGISTRY --repository $REPOSITORY \
    -o tsv --query "[?digest == '$DIGEST'].[tags[0]]")

# Create file if not exist
if [ ! -f "$FILE" ]; then
    >"$FILE"
fi

# Read state file to an array
readarray -t PRESENT_TAGS <"$FILE"

# Get array size
PRESENT_TAGS_SIZE=${#PRESENT_TAGS[@]}

# Check if image tag is already available
if [[ "${PRESENT_TAGS[*]}" == *"$image_tag"* ]]; then
    # Exit if image tag found
    exit
else
    # Check array size
    if [[ "$PRESENT_TAGS_SIZE" < 5 ]]; then
        # Add new image tag if array size is -le to five
        PRESENT_TAGS+=("$image_tag")
        # Empty state file
        >"$FILE"
        # Update state file with new tag lists
        printf "%s\n" ${PRESENT_TAGS[@]} >>acr-image-state.txt
        echo "Updated state file with image tag: "$REPOSITORY":"$image_tag
    else
        # Get older image tag
        image_to_remove=${PRESENT_TAGS[0]}
        # Check if removing image tag matches with latest
        if [[ "$image_to_remove" != "$image_tag" ]]; then
            # Check if image 1 year old before unlocking the image
            # Get image last update date
            last_updated_on=$(az acr repository show -n wickramContainerRegistry001 --image hi_mom_nginx:v2 \
                -o tsv --query "[lastUpdateTime]")
            # Set retention period
            timeago='365 days ago'
            # Covert to seconds (Epoch time)
            dtSec=$(date --date "$last_updated_on" +'%s')
            taSec=$(date --date "$timeago" +'%s')
            # Check if image date is less than retention period
            if [ $dtSec -lt $taSec ]; then
                # Unlock oldest image before removing from state file
                echo "----------------------------------------------------------------------------------"
                echo "Unlocking image tag: "$REPOSITORY":""$image_to_remove"
                az acr repository update \
                    --name wickramContainerRegistry001 --image hi_mom_nginx:"$image_to_remove" \
                    --delete-enabled true --write-enabled true
                echo "Unlocking image COMPLETED for tag: "$REPOSITORY":""$image_to_remove"
                echo "----------------------------------------------------------------------------------"
                # Remove oldest image from the state file if array size is -gt five
                PRESENT_TAGS=("${PRESENT_TAGS[@]:1}")
                # Add new image tag to array
                PRESENT_TAGS+=("$image_tag")
                >"$FILE"
                # Update state file with new tag lists
                printf "%s\n" ${PRESENT_TAGS[@]} >>acr-image-state.txt
            else
                echo "Image not unlocked as it's not older than a year!"
            fi
        else
            echo "Latest image tag is same as the oldest image tag!"
        fi
    fi
    # Lock new image tag
    echo "----------------------------------------------------------------------------------"
    echo "Locking image tag: "$REPOSITORY":"$image_tag
    az acr repository update \
        --name wickramContainerRegistry001 --image hi_mom_nginx:$image_tag \
        --delete-enabled false --write-enabled true
    echo "Locking image COMPLETED for tag: "$REPOSITORY":"$image_tag
    echo "----------------------------------------------------------------------------------"
fi
