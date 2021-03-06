# Fail script when a subsuquent command or pipe redirection fails
set -e
set -o pipefail

# Validate arguments
if [ "$#" -ne 3 ]; then
    echo "Error: Insufficient arguements!" >&2
    echo "Usage: bash $0 <REGISTRY> <REPOSITORY> <DIGEST>" >&2
    exit 1
fi

# Declare variables
PRESENT_TAGS=()
FILE="acr-pord-image-tags.txt"

# Read and assign arguments
REGISTRY=$1
REPOSITORY=$2
DIGEST=$3

# Create state file if not exist
if [ ! -f "$FILE" ]; then
    >"$FILE"
fi

# Get production image tag
image_tag=$(az acr repository show-manifests --name $REGISTRY --repository $REPOSITORY \
    -o tsv --query "[?digest == '$DIGEST'].[tags[0]]")

if [ ! -z "$image_tag" ]; then

    # Read state file to an array
    readarray -t PRESENT_TAGS <"$FILE"
    # Get array size
    PRESENT_TAGS_SIZE=${#PRESENT_TAGS[@]}

    # Check if image tag is already available
    if [[ "${PRESENT_TAGS[*]}" == *"$image_tag"* ]]; then
        # Exit if image tag found
        echo "Image tag: "$REPOSITORY":"$image_tag" already in the state file!"
        exit
    else
        if ((${#PRESENT_TAGS[@]})); then
            for present_tag in "${PRESENT_TAGS[@]}"; do
                # Get older image tag
                image_to_remove=$present_tag
                # Check if removing image tag matches with latest
                if [[ "$image_to_remove" != "$image_tag" ]]; then
                    # Check if image 1 year old before unlocking the image
                    # Get image last update date
                    last_updated_on=$(az acr repository show -n $REGISTRY --image $REPOSITORY:"$image_to_remove" \
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
                            --name $REGISTRY --image $REPOSITORY:"$image_to_remove" \
                            --delete-enabled true --write-enabled true
                        echo "Unlocking image COMPLETED for tag: "$REPOSITORY":""$image_to_remove"
                        echo "----------------------------------------------------------------------------------"
                        # Remove oldest image from the state file if array size is -gt five
                        PRESENT_TAGS=("${PRESENT_TAGS[@]/"$image_to_remove"/}")
                        >"$FILE"
                        # Update state file with new tag lists
                        printf "%s\n" ${PRESENT_TAGS[@]} >>acr-pord-image-tags.txt
                        echo "Removed image tag: "$REPOSITORY":""$image_to_remove"" from state file!"
                        #PRESENT_TAGS=("${PRESENT_TAGS[@]:1}")
                    else
                        echo "Image tag: "$REPOSITORY":"$image_to_remove" not unlocked as it's not older than a year!"
                        break
                    fi
                else
                    echo "Latest image tag is same as the oldest image tag!"
                fi
            done
        else
            echo "State file doesn't have any images!"
        fi
        # Lock new image tag
        echo "----------------------------------------------------------------------------------"
        echo "Locking image tag: "$REPOSITORY":"$image_tag
        az acr repository update \
            --name $REGISTRY --image $REPOSITORY:$image_tag \
            --delete-enabled false --write-enabled true
        echo "Locking image COMPLETED for tag: "$REPOSITORY":"$image_tag
        echo "----------------------------------------------------------------------------------"
        # Add new image tag to array
        PRESENT_TAGS+=("$image_tag")
        >"$FILE"
        # Update state file with new tag lists
        printf "%s\n" ${PRESENT_TAGS[@]} >>acr-pord-image-tags.txt
        echo "Updated state file with image tag: "$REPOSITORY":"$image_tag
    fi
else
    echo "Image tag not found for Digest: "$REPOSITORY"@""$DIGEST"
    exit 1
fi
