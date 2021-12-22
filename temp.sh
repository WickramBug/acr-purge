# Fail script when a subsuquent command or pipe redirection fails
set -e
set -o pipefail

# Declare variables
PRESENT_TAGS=()
FILE="tesst.txt"

# Read and assign arguments
REGISTRY=wickramContainerRegistry001
REPOSITORY=hi_mom_nginx
DIGEST="sha256:169507c43862fec30cda7b4a6c6e66a4a99f5d9fd19ff5bb1ca5adca79678996"
RETENTION_PERIOD="6 days ago"

# Create state file if not exist
if [ ! -f "${FILE}" ]; then
    touch "${FILE}"
fi

# Get image tag
image_tag=$(az acr repository show-manifests --name "${REGISTRY}" --repository "${REPOSITORY}" \
    -o tsv --query "[?digest == '${DIGEST}'].[tags[0]]")

if [ ! -z "${image_tag}" ]; then

    # Read state file to an array
    readarray -t PRESENT_TAGS <"${FILE}"

    # Check if image tag is already available in the state file
    if [[ "${PRESENT_TAGS[*]}" == *"${image_tag}"* ]]; then
        # Report if image already in the state file
        echo "Image Digest: "${REPOSITORY}":"${DIGEST}" haven't changed!!!"
    fi
    if (("${#PRESENT_TAGS[@]}")); then
        for tag in "${PRESENT_TAGS[@]}"; do
            # Get older image tag
            image_to_remove=${tag}
            # Check if image tag matches with current image tag to support rollback scenario
            if [[ "${image_to_remove}" != "${image_tag}" ]]; then
                # Check if image 1 year old before unlocking the image
                # Get image last update date
                last_updated_on=$(az acr repository show -n "${REGISTRY}" --image "${REPOSITORY}":"${image_to_remove}" \
                    -o tsv --query "[lastUpdateTime]")
                # Set retention period
                timeago="${RETENTION_PERIOD}"
                # Covert to seconds (Epoch time)
                dtSec=$(date --date "${last_updated_on}" +'%s')
                taSec=$(date --date "${timeago}" +'%s')
                # Check if image date is less than retention period
                if [ "${dtSec}" -lt "${taSec}" ]; then
                    # Unlock oldest image before removing from state file
                    echo "----------------------------------------------------------------------------------"
                    echo "Image tag: "${REPOSITORY}":"${image_to_remove}" older than "${timeago}""
                    echo "Unlocking image tag: "${REPOSITORY}":""${image_to_remove}"
                    az acr repository update \
                        --name "${REGISTRY}" --image "${REPOSITORY}":"${image_to_remove}" \
                        --delete-enabled true --write-enabled true
                    echo "Unlocking image COMPLETED for tag: "${REPOSITORY}":""${image_to_remove}"
                    echo "----------------------------------------------------------------------------------"
                    # Remove oldest image from the state file
                    sed -i "/${image_to_remove}/d" "${FILE}"
                    echo "Removed image tag: "${REPOSITORY}":"${image_to_remove}" from state file!"
                else
                    echo "Image tag: "${REPOSITORY}":"${image_to_remove}" not unlocked as it's not older than "${timeago}""
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
    echo "Locking image tag: "${REPOSITORY}":""${image_tag}"
    az acr repository update \
        --name "${REGISTRY}" --image "${REPOSITORY}":"${image_tag}" \
        --delete-enabled false --write-enabled true
    echo "Locking image COMPLETED for tag: "${REPOSITORY}":""${image_tag}"
    echo "----------------------------------------------------------------------------------"
    # Add new image tag to state file
    echo "${image_tag}" >>"${FILE}"
    echo "Updated state file with image tag: "${REPOSITORY}":""${image_tag}"
else
    echo "Image tag not found for Digest: "${REPOSITORY}"@""${DIGEST}"
    exit 1
fi
