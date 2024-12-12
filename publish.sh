#!/bin/bash

# Check if a old version was provided
if [ -z "$1" ]
then
    echo "Please provide a old version as an argument."
    exit 1
fi

# Check if a new version was provided
if [ -z "$2" ]
then
    echo "Please provide a new version as an argument."
    exit 1
fi

# Check if a release date was provided
if [ -z "$3" ]
then
    echo "Please provide a release date as an argument."
    exit 1
fi

# Old version
old_version="$1"

# New version
new_version="$2"

# Release date
release_date="$3"

# Fetch
git fetch

# Checkout to that pre branch
git checkout $old_version

# Reset to the previous commit
git reset HEAD~1

# Directory containing the YAML files
dir="manifests/w/WindRiver/studio-cli/$new_version"

# Update folder name
cd manifests/w/WindRiver/studio-cli && mv $old_version $new_version && cd -

# Loop over all YAML files in the directory
for yaml_file in $dir/Wind*.yaml
do
    # Replace the current branch name with the new version in the YAML file
    sed -i "s/$old_version/$new_version/g" $yaml_file
done

yaml_file=$dir/WindRiver.studio-cli.installer.yaml

# If a release date was provided, update the ReleaseDate field
if [ -n "$release_date" ]
then
    sed -i "s/ReleaseDate: .*/ReleaseDate: $release_date/" $yaml_file
fi

# Get the InstallerUrl from the YAML file
installer_url=$(grep 'InstallerUrl:' $yaml_file | awk '{print $2}')

# Download the file from the InstallerUrl
wget $installer_url -O temp_file

# Calculate the SHA256 of the downloaded file
new_sha256=$(sha256sum temp_file | awk '{print $1}')

# Replace the old SHA256 with the new one in the YAML file
sed -i "s/InstallerSha256: .*/InstallerSha256: $new_sha256/" $yaml_file

# Remove the downloaded file
rm temp_file

# Add all
git add .

# Commit and push
git commit -a -m "Submitting studio-cli version $new_version"

# Create a new branch with the name of the new version
git checkout -b $new_version

# Push the new branch to the remote
git push origin $new_version

echo "Done!"
