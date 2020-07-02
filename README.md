# AWS_Neo4j_Shadow
Dump AWS Schemas into Neo4j


## Provisioning the Neo4j Docker container
Run the Terraform configuration to create the cluster and security group
```sh
cd terraform
terraform init
terraform apply
```

## Developers

The following developer tools are required when working on this repository:
* terraform: Terraform must be installed and found within the path
* pre-commit: Tool for running git hooks
* detect-secrets: Tool for detecting sensitive information within the repository

# Note: detect-secrets is installed as part of the installation of pre-commit

terraform installation: Please follow the [Terraform installation guide](https://www.terraform.io/docs/enterprise/install/index.html)

Run the following commands from Mac terminal to install pre-commit:
```
> brew install pre-commit
> pre-commit --version  (should return the version number, if no version number is returned, installation may have failed)
> cd <to the root of this repository>
> pre-commit --install
```

Follow these steps to install pre-commit on Windows:
- Download and install [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- Download and install Windows version: [python](https://www.python.org/downloads/) Note: During installation, make sure to check second box "Add to path"

- Install the pre-commit tool open a terminal and run the following:
```
> pip install pre-commit
> pip install detect-secrets
> cd <to this git repository root directory>
> pre-commit install
```

### terraform_fmt: Terraform format
Terraform format is run as a pre-commit hook against this repository.  Terraform files that need formatting will be automatically formatted.  Any files that were updated as a result of the terraform format command must be re-added to the git list of files to be committed.

### Sensitive Data

Sensitive data including passwords, API keys, PHI/PII information, etc, should never be checked into the git repository.  The [detect-secrets](https://github.com/Yelp/detect-secrets) open source tool has been configured to run via pre-commit hook against this repository. (Please see the instructions on installing pre-commit above, this is required to run detect-secrets.)  If detect-secrets finds sensitive data within this repository, the "git commit" command will fail and return an error message.  Detect-secrets will output the file and line number where the sensitive data was found. The sensitive data must be remediated before committing the data.

On occasion, detect-secrets will incorrectly detect sensitive data.  When this occurs and the data has been verified not to be sensitive, there are two options to "override" detect-secrets:
* If the sensitive data is found in source code (ie. Java, bash, Python, etc), a comment statement can be added to the line number of the file where the sensitive data was found.  (This examples adds a Java comment statement): `<sensitive data>   // pragma: allowlist se
cret`
* If the sensitive data is found within a file and a comment statement can not be added, update the .secrets.baseline file with a new baseline. The new baseline will instruct detect-secrets to skip the line number within the file. To generate a new .secrets.baseliine file execute the following within the root directory of this git repository:
```
detect-secrets scan > .secrets.baseline
```
The new `.secrets.baseline` file should now contain an entry in the "results" block indicating an override of the file and line number. The new `.secerts.baseline` file must be added and commited into the git repository.

For more informaton on detect-secrets please see the website listed above.
