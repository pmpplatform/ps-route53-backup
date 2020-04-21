#!/bin/bash -e

# Initialize git repo
[ -z "$DRY_RUN" ] && [ -z "$GIT_REPO" ] && echo "Need to define GIT_REPO environment variable" && exit 1
GIT_REPO_PATH="${GIT_REPO_PATH:-"/backup/git"}"
GIT_PREFIX_PATH="${GIT_PREFIX_PATH:-"."}"
GIT_USERNAME="${GIT_USERNAME:-"route53-backup"}"
GIT_EMAIL="${GIT_EMAIL:-"route53-backup@example.com"}"
GIT_BRANCH="${GIT_BRANCH:-"master"}"
GITCRYPT_ENABLE="${GITCRYPT_ENABLE:-"false"}"
GITCRYPT_PRIVATE_KEY="${GITCRYPT_PRIVATE_KEY:-"/secrets/gpg-private.key"}"
GITCRYPT_SYMMETRIC_KEY="${GITCRYPT_SYMMETRIC_KEY:-"/secrets/symmetric.key"}"

if [ -z $AWS_ACCESS_KEY_ID ] || [ -z $AWS_SECRET_ACCESS_KEY ]; then
  echo "Missing AWS access key id or secret access key. Set environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
  exit 1
fi

if [[ ! -f /backup/.ssh/id_rsa ]]; then
    git config --global credential.helper '!aws codecommit credential-helper $@'
    git config --global credential.UseHttpPath true
fi
[ -z "$DRY_RUN" ] && git config --global user.name "$GIT_USERNAME"
[ -z "$DRY_RUN" ] && git config --global user.email "$GIT_EMAIL"

[ -z "$DRY_RUN" ] && (test -d "$GIT_REPO_PATH" || git clone --depth 1 "$GIT_REPO" "$GIT_REPO_PATH" --branch "$GIT_BRANCH" || git clone "$GIT_REPO" "$GIT_REPO_PATH")
cd "$GIT_REPO_PATH"
[ -z "$DRY_RUN" ] && (git checkout "${GIT_BRANCH}" || git checkout -b "${GIT_BRANCH}")

mkdir -p "$GIT_REPO_PATH/$GIT_PREFIX_PATH"
cd "$GIT_REPO_PATH/$GIT_PREFIX_PATH"

if [ "$GITCRYPT_ENABLE" = "true" ]; then
    if [ -f "$GITCRYPT_PRIVATE_KEY" ]; then
        gpg --allow-secret-key-import --import "$GITCRYPT_PRIVATE_KEY"
        git-crypt unlock
    elif [ -f "$GITCRYPT_SYMMETRIC_KEY" ]; then
        git-crypt unlock "$GITCRYPT_SYMMETRIC_KEY"
    else
        echo "[ERROR] Please verify your env variables (GITCRYPT_PRIVATE_KEY or GITCRYPT_SYMMETRIC_KEY)"
        exit 1
    fi
fi

[ -z "$DRY_RUN" ] && git rm -r '*.txt' --ignore-unmatch -f

# Get zones or bail out
zones=$(cli53 list -f json | jq -r '. | keys[] as $k | "\(.[$k] | .Name)"')
if [ ! -z "$zones" ]; then
  # Export zones
  for zone in $zones;
  do
    # Zone ends with a . (so extension dot is not required here)
    cli53 export $zone --output $GIT_REPO_PATH/${zone}txt;
  done
else
  echo "Error listing zones - check your cli53 configuration/aws keys"
  exit 1
fi

[ -z "$DRY_RUN" ] || exit

cd "${GIT_REPO_PATH}"
git add .

if ! git diff-index --quiet HEAD --; then
  git commit -m "Automatic backup at $(date)"
  git push origin "${GIT_BRANCH}"
else
  echo "No change"
fi



