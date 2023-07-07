#!/bin/bash

# Replace the variables below with your own values
org=""
pat=""
user=""

echo "Repositorio;Path;Imagem" > FullFile.csv

# Function to search for Dockerfiles in a repository
function search_dockerfiles {
  local project=$1
  local repo=$2
  
  # Get the list of files in the repository
  files=$(curl -k -s -u $user:$pat "https://dev.azure.com/$org/$project/_apis/git/repositories/$repo/items?recursionLevel=full&api-version=7.0" | jq -r '.value[].path')
  #files=$(curl -k -s -u  $user:$pat "https://dev.azure.com/$org/$project/_apis/git/repositories/$repoId/items?recursionLevel=full&api-version=7.0" | jq -r '.value[].path')

  # Loop through the files and check if they are Dockerfiles
  for file in $files
  do
    if [[ $file == *"Dockerfile"* ]]; then
      #echo "$project/$repo/$file"
      echo "$file"
    fi
  done
}

# Function to search for and print all images used in a Dockerfile
function search_images {
  local project=$1
  local repo=$2
  local file=$3

  curl -k -s -u $user:$pat "https://dev.azure.com/$org/$project/_apis/git/repositories/$repo/items?path=$file&api-version=7.0" > tmp.txt

  base_image=$( cat tmp.txt | grep -v '^#' | grep 'BASE_IMAGE' | awk -F '=' '{print $2}')
  from=$( cat tmp.txt | grep -v '^#' | grep 'FROM' | awk -F ' ' '{print $2}')

  if [[ -z "$base_image" ]]; then 
    images=$from
    images2="`echo $images | tr '\n ' "||"`"
  else
    images=$base_image
    images2="`echo $images | tr '\n ' "||"`"
  fi

  #Send to csv file
  echo "$repo;$file;$images2"
  echo "$repo;$file;$images2" >> FullFile.csv

}

# Get the list of projects in the organization
projects="global-platform"

# Loop through the projects and get the list of repositories for each project
for project in $projects
do
  repos=$(curl -k -s -u $user:$pat "https://dev.azure.com/$org/$project/_apis/git/repositories?api-version=7.0" | jq -r '.value[].name')

  # Loop through the repositories and check if the user has access
  for repo in $repos
  do
      #echo "----------------------------------------------------------------------------------------"
      #echo "Searching for Dockerfiles in $project/$repo..."
      dockerfiles=$(search_dockerfiles $project $repo)
      # Loop through the Dockerfiles and search for images
      for dockerfile in $dockerfiles
      do
        search_images $project $repo $dockerfile
      done
  done
done
