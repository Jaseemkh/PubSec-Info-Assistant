#!/bin/bash
set -eo pipefail

# Display banner
figlet "Build Docker Container Images"

# Build the Docker image with the correct context
echo "Building Docker image: enrichmentapp"
echo -e "\n"
sudo docker build -f ./container_images/enrichment_container_image/Dockerfile -t enrichmentapp . --build-arg BUILDKIT_INLINE_CACHE=1

# Generate a unique tag for the image
tag=$(date -u +"%Y%m%d-%H%M%S")
echo "Tagging image with: $tag"
sudo docker tag enrichmentapp enrichmentapp:$tag

# Output the tag to a file to be used in deployment
echo -n "$tag" > ./container_images/enrichment_container_image/image_tag.txt

echo "Build and tagging complete. Tag: $tag"
echo -e "\n"