# Fail script when a subsuquent command or pipe redirection fails
set -e
set -o pipefail

# Declare variables
PRESENT_TAGS=()
REGISTRY=wickramContainerRegistry001
REPOSITORY=hi_mom_nginx
DIGEST="sha256:a3bc946b11e888fed558dfc432ade6c626c750de52d765f32f3d1f41e2919bb0"
RETENTION_PERIOD=6
FILE="tesst.txt"
IS_LOCKED="false"

# Create state file if not exist
if [ ! -f "${FILE}" ]; then
    touch "${FILE}"
fi

# Check retention period
rg='^[0-9]+$'
if [[ ${RETENTION_PERIOD} =~ ${rg} && ${RETENTION_PERIOD} -le 12 && ! ${RETENTION_PERIOD} -eq 0 ]]; then
    RETENTION_PERIOD="${RETENTION_PERIOD} months ago"
else
    echo "Error: invalid retention period, enter months 1-12!" >&2
    exit 1
fi

# Get image tag
image_tag=$(az acr repository show-manifests --name "${REGISTRY}" --repository "${REPOSITORY}" \
    -o tsv --query "[?digest == '${DIGEST}'].[tags[0]]")

# Exit with error if digest not found in the ACR
if [ -z "${image_tag}" ]; then
    echo "Image tag not found for Digest: "${REPOSITORY}"@""${DIGEST}"
    exit 1
fi

# Read state file to an array
readarray -t PRESENT_TAGS <"${FILE}"

# Check if image tag is already available in the state file
if [[ "${PRESENT_TAGS[*]}" == *"${image_tag}"* ]]; then
    IS_LOCKED="true"
    # Report if image already in the state file
    echo "Image Digest: "${REPOSITORY}":"${DIGEST}" haven't changed!!!"
fi

if (("${#PRESENT_TAGS[@]}")); then
    for tag in "${PRESENT_TAGS[@]}"; do
        # Get older image tag and it's last updated date from the state file
        image_tag_with_date=${tag}
        # Split image last update date and tag into separate variables
        last_updated_on=$(echo "${image_tag_with_date}" | cut -d' ' -f1)
        image_tag_to_remove=$(echo "${image_tag_with_date}" | cut -d' ' -f2)
        # Check if image tag matches with current image tag to support rollback scenario
        if [[ "${image_tag_to_remove}" != "${image_tag}" ]]; then
            # Check if image retention period
            # Set retention period
            timeago="${RETENTION_PERIOD}"
            # Covert to seconds (Epoch time)
            dtSec=$(date --date "${last_updated_on}" +'%s')
            taSec=$(date --date "${timeago}" +'%s')
            # Check if image date is less than retention period
            if [ "${dtSec}" -lt "${taSec}" ]; then
                # Unlock oldest image before removing from state file
                echo "----------------------------------------------------------------------------------"
                echo "Image tag: "${REPOSITORY}":"${image_tag_to_remove}" older than "${timeago}""
                echo "Unlocking image tag: "${REPOSITORY}":""${image_tag_to_remove}"
                az acr repository update \
                    --name "${REGISTRY}" --image "${REPOSITORY}":"${image_tag_to_remove}" \
                    --delete-enabled true --write-enabled true
                echo "Unlocking image COMPLETED for tag: "${REPOSITORY}":""${image_tag_to_remove}"
                echo "----------------------------------------------------------------------------------"
                # Remove oldest image from the state file
                sed -i "/${image_tag_to_remove}/d" "${FILE}"
                echo "Removed image tag: "${REPOSITORY}":"${image_tag_to_remove}" from state file!"
            else
                echo "Image tag: "${REPOSITORY}":"${image_tag_to_remove}" not unlocked as it's not older than "${timeago}""
                #break
            fi
        else
            echo "Latest image tag is same as the image tag to remove!"
        fi
    done
else
    echo "State file doesn't have any images!"
fi

# Check and skip locking image if the image tag is already available in the state file
if [[ ! "${IS_LOCKED}" = true ]]; then
    # Lock new image tag
    echo "----------------------------------------------------------------------------------"
    echo "Locking image tag: "${REPOSITORY}":""${image_tag}"
    az acr repository update \
        --name "${REGISTRY}" --image "${REPOSITORY}":"${image_tag}" \
        --delete-enabled false --write-enabled true
    echo "Locking image COMPLETED for tag: "${REPOSITORY}":""${image_tag}"
    echo "----------------------------------------------------------------------------------"
    # Get image last update date
    last_updated_on=$(az acr repository show -n "${REGISTRY}" --image "${REPOSITORY}":"${image_tag}" \
        -o tsv --query "[lastUpdateTime]")
    # Add new image tag to state file
    echo ""${last_updated_on}" "${image_tag}"" >>"${FILE}"
    echo "Updated state file with image tag: "${REPOSITORY}":""${image_tag}"
else
    echo "Skipped image lock for image tag: "${REPOSITORY}"@""${image_tag}"" as it's found in the state file!"
fi
