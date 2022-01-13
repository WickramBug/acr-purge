image_tags=("")
# add the login command here from the keep

for tag in "${image_tags[@]}"; do
    az acr repository show --name <registry> --image <repository>:"${tag}" \
            --query "[lastUpdateTime]"
done
