#!/usr/bin/bash

echo "Branch: $BRANCH; pull request: $PULL_REQUEST"
if [[ "$BRANCH" = "master" && "$PULL_REQUEST" = "None" ]]; then
  echo "Deploying to production"

  echo "Updating client files on S3..."
  cd client
  printenv AWS_CREDENTIALS >aws-credentials.json
  s3-upload
  echo "Client update done."

  echo "Checking server fingerprint..."
  cd ../server
  rm -f learnful-server-*.tgz
  rm -f fingerprint
  npm pack
  # md5 of the packed .tgz is inconsistent for some reason, so compute it on the original files that
  # are included in the package.
  local_fingerprint="$(tar tf learnful-server-*.tgz | sed 's|^package/||g' | xargs cat | md5sum | cut -d' ' -f1)"
  remote_fingerprint="$(curl learnful-server.jit.su)"
  rm -f learnful-server-*.tgz
  echo "local=$local_fingerprint, remote=$remote_fingerprint"
  if [[ "$local_fingerprint" != "$remote_fingerprint" ]]; then
    echo "Fingerprint mismatch, deploying to Nodejitsu"
    echo "$fingerprint" >fingerprint
    cat fingerprint
    echo "{\"username\": \"piotrk\", \"apiTokenName\": \"shippable\", \"apiToken\": \"$JITSU_TOKEN\"}" >~.jitsuconf
    jitsu deploy --release "0.1.0-$BUILD_NUMBER" --confirm
    rm -f fingerprint
  fi
else
  echo "Not deploying"
fi
