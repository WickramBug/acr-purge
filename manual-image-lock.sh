# add the login command here from the keep

REGISTRY=<registry>.azurecr.io
REPOSITORY=""
FILE="tesst.txt"
readarray -t image_tags_arr <"${FILE}"

for tag in "${image_tags_arr[@]}"; do
    # Get older image tag and it's last updated date from the state file
    image_tag_with_date=${tag}
    # Split image last update date and tag into separate variables
    image_tag_to_remove=$(echo "${image_tag_with_date}" | cut -d' ' -f2)
    echo "----------------------------------------------------------------------------------"
    echo "Locking image tag: "${REPOSITORY}":""${image_tag_to_remove}"
    az acr repository update \
        --name "${REGISTRY}" --image "${REPOSITORY}":"${image_tag_to_remove}" \
        --delete-enabled false --write-enabled true
    echo "Locking image COMPLETED for tag: "${REPOSITORY}":""${image_tag_to_remove}"
    echo "----------------------------------------------------------------------------------"
done
