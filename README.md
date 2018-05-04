## Infra CI (WIP)

Terraform CI with no external dependencies to AWS. This does not actually apply the changes currently.

### Bootstrap

Currently this expects `cloudflare_parameter_name` and `fastly_parameter_name` to be references to SSM parameter store
items containing `CLOUDFLARE_TOKEN` and `FASTLY_API_KEY`. Later this would likely be referenced cross account. You can
use the following to set these in AWS.

```bash
aws ssm put-parameter --type SecureString --name '/CodeBuild/FASTLY_API_KEY' --value "$(echo -n 'enter secret: ' 1>&2; read s; echo -n $s)"
aws ssm put-parameter --type SecureString --name '/CodeBuild/CLOUDFLARE_TOKEN' --value "$(echo -n 'enter secret: ' 1>&2; read s; echo -n $s)"
```

With docker installed run the following 
```
# <profile> is the profile to load from ~/.aws/credentials

./scripts/tf.sh <profile> init
./scripts/tf.sh <profile> apply
```


Worth noting `./scripts/tf.sh` passes arguments to terraform so can run any other tf commands as well.
