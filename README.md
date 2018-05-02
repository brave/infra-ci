## Infra CI

This is a hack thrown together to support terraform CI with no external dependencies to AWS. Idea is that this might
be run from AWS organizations later to support spin up of new accounts.

Terraform is used here just to make this useful without digging to much into how CloudFormation works.

Currently this expects `cloudflare_parameter_name` and `fastly_parameter_name` to be references to SSM parameter store
items containing `CLOUDFLARE_TOKEN` and `FASTLY_API_KEY`. Later this would likely be referenced cross account. You can
use the following to set these in AWS.

```bash
aws ssm put-parameter --type SecureString --name '/CodeBuild/FASTLY_API_KEY' --value "$(echo -n 'enter secret: ' 1>&2; read s; echo -n $s)"
aws ssm put-parameter --type SecureString --name '/CodeBuild/CLOUDFLARE_TOKEN' --value "$(echo -n 'enter secret: ' 1>&2; read s; echo -n $s)"
```

### Notes
Right now the linter is actually meant for CloudFormation, this doesn't cause any issues however since there are no
cloudformation templates.
