# terraform-ecs-fargate-cluster
Example config for setup ECS FARGATE Cluster with terraform

**WARNING!!!**
You need install awscli, terraformcli and setup it.
You need create IAM roes and users.
*TODO: describe roles and user rights required for this setup.*

## How to run
```
git clone {repo_url} src
cd src/deployment
make tf/init
make tf/plan
make tf/apply
```

## How to stop and destroy all created elements
```
make tf/destroy
```
