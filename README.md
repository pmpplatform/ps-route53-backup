# ps-route53-backup

A tool that makes backups of AWS Route53 records and stores them in github, designed to be ran as kubernetes Job.

* [barnybug/cli53](https://github.com/barnybug/cli53)
* [git-crypt](https://github.com/AGWA/git-crypt)

## Running ps-route53-backup

### Setup 

Use the deployment example ([ssh](cronjob-ssh.yaml) authentication) and deploy a kubernetes `CronJob` primitive in your kubernetes (1.5 and up) cluster ensuring backups of route53 records to your private git repo. Docker examples can be found below.

Define the following environment parameters:
  * `GIT_REPO` - GIT repo url. **Required**
  * `GIT_PREFIX_PATH` - Path to the subdirectory in your repository. Default: `.`
  * `AWS_ACCESS_KEY_ID` - Route53 access key id
  * `AWS_SECRET_ACCESS_KEY` - Route53 secret access key
  * `GIT_USERNAME` - Display name of git user. Default: `kube-backup`
  * `GIT_EMAIL` - Email address of git user. Default: `kube-backup@example.com`
  * `GIT_BRANCH` - Use a specific git branch . Default: `master`
  * `GITCRYPT_ENABLE` - Use git-crypt for data encryption. See [git-crypt section](#git-crypt) for details. Default: `false`
  * `GITCRYPT_PRIVATE_KEY` - Path to private gpg key for git-crypt. See [git-crypt section](#git-crypt) for details. Default: `/secrets/gpg-private.key`
  * `GITCRYPT_SYMMETRIC_KEY` - Path to shared symmetric key for git-crypt. See [git-crypt section](#git-crypt). Default: `/secrets/symmetric.key`

### Running in Docker by setting AWS credentials through environment variables

```bash
docker run --rm \
  -v <path-to-your-git-crypt-symmetric-key>:/secrets/symmetric.key \
  -v <path-to-your-ssh-directory>/:/backup/.ssh/ \
  -e AWS_ACCESS_KEY_ID=<your-access-key-id> \
  -e AWS_SECRET_ACCESS_KEY=<your-secret-access-key> \
  -e GIT_REPO=git@github.com:<your-git-repo> \
  -e GIT_BRANCH=<your-branch-name> \
  -e GITCRYPT_ENABLE=true \
  habitissimo/route53-backup
```

### Running in Docker by setting AWS credentials through credentials file
Create a file containing your credentials:

```ini
[default]
aws_access_key_id=<your-access-key-id>
aws_secret_access_key=<your-secret-access-key>
```

``` bash
docker run --rm \
  -v $(pwd)/credentials:/root/.aws/config \
  -v <path-to-your-git-crypt-symmetric-key>:/secrets/symmetric.key \
  -v <path-to-your-ssh-directory>/:/backup/.ssh/ \
  -e AWS_CONFIG_FILE=/root/.aws/config \
  -e GIT_REPO=git@github.com:<your-git-repo> \
  -e GIT_BRANCH=<your-branch-name> \
  -e GITCRYPT_ENABLE=true \
  habitissimo/route53-backup
```

## AWS IAM permissions
The IAM user must have the following policies attached.

### Route 53
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "route53:GetHostedZone",
                "route53:ListResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:GetHostedZoneCount",
                "route53:ListHostedZonesByName"
            ],
            "Resource": "*"
        }
    ]
}
```

# git-crypt

Store your zones safely using the [git-crypt project](https://github.com/AGWA/git-crypt).

### Prerequisites
Your repository has to be already initialized with git-crypt. Minimal configuration is listed below. For details and full information see [using git-crypt](https://github.com/AGWA/git-crypt#using-git-crypt).

```
cd repo
git-crypt init
cat <<EOF > .gitattributes
*.txt filter=git-crypt diff=git-crypt
.gitattributes !filter !diff
EOF
git-crypt add-gpg-user <USER_ID>
git add -A
git commit -a -m "initialize git-crypt"
```

Optional:
  * You may choose any subdirectory for storing .gitattributes file (useful when using `GIT_PREFIX_PATH`).
  * You may encrypt additional files other than <zone>.txt. Add additional lines before the .gitattribute filter. You may also use wildcard `*` to encrypt all files within the directory.

### Enable git-crypt
To enable encryption feature:
  * Set pod environment variable `GITCRYPT_ENABLE` to `true`
    ```
    spec:
      containers:
      - env:
        - name: GITCRYPT_ENABLE
          value: "true"
    ```
  * Create additional `Secret` object containing **either** gpg-private or symmetric key
    ```
    apiVersion: v1
    kind: Secret
    metadata:
      name: kube-backup-gpg
      namespace: kube-system
    data:
      gpg-private.key: <base64_encoded_key>
      symmetric.key: <base64_encoded_key>
    ```
  * Mount keys from `Secret` as additional volume
    ```
    spec:
      containers:
      - volumeMounts:
        - mountPath: /secrets
          name: gpgkey
      volumes:
      - name: gpgkey
        secret:
          defaultMode: 420
          secretName: kube-backup-gpg
    ```

  * (Optional): `$GITCRYPT_PRIVATE_KEY` and `$GITCRYPT_SYMMETRIC_KEY` variables are the combination of path where `Secret` volume is mounted and the name of item key from that object. If you change any value of them from the above example you may need to set this variables accordingly.

# cli53 - Command line tool for Amazon Route 53

[barnybug/cli53](https://github.com/barnybug/cli53)

## Installation

Installation is easy, just download the binary from the github releases page (builds are available for Linux, Mac and Windows):
https://github.com/barnybug/cli53/releases/latest

    $ sudo mv cli53-my-platform /usr/local/bin/cli53
    $ sudo chmod +x /usr/local/bin/cli53

Alternatively, on Mac you can install it using homebrew

    $ brew install cli53

To configure your Amazon credentials, either place them in a file `~/.aws/credentials`:

	[default]
	aws_access_key_id = AKID1234567890
	aws_secret_access_key = MY-SECRET-KEY

Or set the environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

### Using cli53 to import a zone backup from ps-route53-backup

Import a BIND zone file:

	$ cli53 import --file zonefile.txt example.com

Replace with an imported zone, waiting for completion:

	$ cli53 import --file zonefile.txt --replace --wait example.com

Also you can 'dry-run' import, to check what will happen:

	$ cli53 import --file zonefile.txt --replace --wait --dry-run example.com