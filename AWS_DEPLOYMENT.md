# Sprintly AWS Deployment Guide

This guide shows how to deploy Sprintly on AWS with a no-NAT VPC, static frontend hosting on S3/CloudFront, and backend deployment on EC2 via CodeDeploy.

## What is included
- `cloudformation/vpc.yml` — VPC with public and private subnets plus the required private VPC endpoints.
- `cloudformation/backend.yml` — EC2 Auto Scaling Group, ALB, PostgreSQL RDS, Secrets Manager, and CodeDeploy resources.
- `cloudformation/frontend.yml` — private S3 bucket and CloudFront distribution for the React frontend.
- `cloudformation/pipeline.yml` — GitHub CodeStar connection, CodeBuild project, and CodePipeline that builds artifacts and deploys backend to EC2.
- `buildspec.yml` — CodeBuild specification that packages backend artifacts, builds frontend assets, uploads S3 assets, and invalidates CloudFront.
- `appspec.yml` and `scripts/` — CodeDeploy hooks to stop/start the Spring Boot app on EC2 instances.

## Notes
- The design explicitly avoids NAT gateways.
- Backend servers run in private subnets behind an Application Load Balancer.
- Backend deployments use CodeDeploy on EC2 instances.
- Frontend assets are hosted on S3 and served through CloudFront.

## Prerequisites
1. AWS CLI configured with permissions for CloudFormation, IAM, S3, VPC, EC2, RDS, CloudFront, CodeBuild, CodePipeline, CodeDeploy, Secrets Manager, and CodeStar Connections.
2. GitHub repository for the project.
3. AWS region that supports the required services.

## Deployment order

### 1. Deploy using nested stacks (recommended)
The root nested stack is `cloudformation/root.yml`. It deploys the VPC, backend, frontend, and pipeline stacks in the correct order.

```bash
aws cloudformation package \
  --template-file cloudformation/root.yml \
  --s3-bucket <your-deployment-bucket> \
  --output-template-file packaged-root.yml

aws cloudformation deploy \
  --template-file packaged-root.yml \
  --stack-name sprintly-root \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    GitHubRepository='owner/repo' \
    GitHubBranch='main' \
    DBPassword='YourSecureDbPassword' \
    JWTSecret='YourStrongJwtSecret'
```

### 2. Deploy child stacks individually (optional)
If you prefer deploying each stack separately, use the following commands in this order.

#### Deploy the VPC stack
```bash
aws cloudformation deploy \
  --template-file cloudformation/vpc.yml \
  --stack-name sprintly-vpc \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

#### Deploy the backend stack
Replace `DBPassword` and `JWTSecret` with strong values.

```bash
aws cloudformation deploy \
  --template-file cloudformation/backend.yml \
  --stack-name sprintly-backend \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    VpcId=$(aws cloudformation describe-stacks --stack-name sprintly-vpc --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text) \
    PublicSubnetIds=$(aws cloudformation describe-stacks --stack-name sprintly-vpc --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnetIds`].OutputValue' --output text) \
    PrivateSubnetIds=$(aws cloudformation describe-stacks --stack-name sprintly-vpc --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetIds`].OutputValue' --output text) \
    DBPassword='YourSecureDbPassword' \
    JWTSecret='YourStrongJwtSecret'
```

#### Deploy the frontend stack
```bash
aws cloudformation deploy \
  --template-file cloudformation/frontend.yml \
  --stack-name sprintly-frontend \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

#### Deploy the pipeline stack
Replace `GitHubRepository` with the repository owner/name (for example: `copduh/sprintly-aws`).

```bash
aws cloudformation deploy \
  --template-file cloudformation/pipeline.yml \
  --stack-name sprintly-cicd \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    GitHubRepository='owner/repo' \
    GitHubBranch='main'
```

## Deploy using the AWS Console (GUI)

### Nested stack deployment using the AWS Console
For the root nested stack, you can upload `root.yml` directly if child templates are already uploaded to an S3 bucket and `root.yml` uses S3 URLs.

1. Upload the child templates to your S3 bucket under `cloudformation/`:
   - `vpc.yml`
   - `backend.yml`
   - `frontend.yml`
   - `pipeline.yml`
2. Open `cloudformation/root.yml` and set `DeploymentBucket` to the bucket name you uploaded the child templates to.
3. Open the AWS Console.
4. Navigate to **CloudFormation**.
5. Click **Create stack** > **With new resources (standard)**.
6. Under **Specify template**, choose **Amazon S3 URL**.
7. Enter the S3 URL for `root.yml`:
   - `https://<your-deployment-bucket>.s3.<region>.amazonaws.com/cloudformation/root.yml`
8. Click **Next**.
9. On the **Specify stack details** page, enter:
   - **Stack name**: `sprintly-root`
   - **DeploymentBucket**: `<your-deployment-bucket>`
   - **GitHubRepository**: `owner/repo` (replace with your GitHub repository)
   - **GitHubBranch**: `main`
   - **DBPassword**: a strong database password
   - **JWTSecret**: a strong random secret
   - **DBUsername**: leave as `postgres` unless you require a different name
10. Click **Next**.
11. On the **Configure stack options** page, you can optionally add tags, IAM role, and notifications.
12. Click **Next**.
13. On the **Review** page, expand **Capabilities** and check the boxes for **CAPABILITY_IAM** and **CAPABILITY_NAMED_IAM**.
14. Click **Create stack**.
15. Wait for the stack to finish creating. The root stack will create nested child stacks automatically.
16. To inspect nested stacks, open `sprintly-root` and click the **Stacks** tab inside the root stack details.

### What to do if the root stack fails
1. Open the `sprintly-root` stack details.
2. Review the **Events** tab to identify the failing nested stack.
3. Click the failing nested stack name to view its events and error message.
4. Fix the input parameter or resource issue, then retry the deployment.

### Deploy individual nested stacks using the console
If you need to deploy one stack at a time instead of nested deployment:

#### Deploy the VPC stack
1. Open **CloudFormation**.
2. Click **Create stack** > **With new resources (standard)**.
3. Upload `cloudformation/vpc.yml`.
4. Enter stack name `sprintly-vpc`.
5. Click **Next**, then **Next**.
6. Expand **Capabilities** and check **CAPABILITY_IAM** and **CAPABILITY_NAMED_IAM**.
7. Click **Create stack**.

#### Deploy the backend stack
1. Open **CloudFormation**.
2. Click **Create stack** > **With new resources (standard)**.
3. Upload `cloudformation/backend.yml`.
4. Enter stack name `sprintly-backend`.
5. Provide parameters:
   - `VpcId`, `PublicSubnetIds`, `PrivateSubnetIds` from the `sprintly-vpc` stack outputs
   - `DBPassword` and `JWTSecret`
6. Click **Next**, then **Next**.
7. Check **CAPABILITY_IAM** and **CAPABILITY_NAMED_IAM**.
8. Click **Create stack**.

#### Deploy the frontend stack
1. Open **CloudFormation**.
2. Click **Create stack** > **With new resources (standard)**.
3. Upload `cloudformation/frontend.yml`.
4. Enter stack name `sprintly-frontend`.
5. Click **Next**, then **Next**.
6. Check **CAPABILITY_IAM** and **CAPABILITY_NAMED_IAM**.
7. Click **Create stack**.

#### Deploy the pipeline stack
1. Open **CloudFormation**.
2. Click **Create stack** > **With new resources (standard)**.
3. Upload `cloudformation/pipeline.yml`.
4. Enter stack name `sprintly-cicd`.
5. Provide parameters:
   - `GitHubRepository` = `owner/repo`
   - `GitHubBranch` = `main`
6. Click **Next**, then **Next**.
7. Check **CAPABILITY_IAM** and **CAPABILITY_NAMED_IAM**.
8. Click **Create stack**.

### Update stack parameters by console
1. Open **CloudFormation**.
2. Select the stack name.
3. Click **Update**.
4. Choose **Use current template** and click **Next**.
5. Modify parameters and click **Next**, then **Update stack**.

## Authorize GitHub connection
1. Open the AWS Console.
2. Go to **Developer Tools** > **Connections** (or **CodeStar Connections**).
3. Locate the connection created by the `sprintly-cicd` stack.
4. Click the connection name and choose **Connect to GitHub**.
5. Authorize access to the repository when prompted.
6. Return to **CodePipeline** and verify the pipeline is in the **Succeeded** or **In progress** state.

## GUI checks after each deployment

### Verify the VPC stack
1. Open **CloudFormation**.
2. Select `sprintly-vpc`.
3. Review the **Outputs** tab for `VpcId`, `PublicSubnetIds`, and `PrivateSubnetIds`.

### Verify the backend stack
1. Open **CloudFormation**.
2. Select `sprintly-backend`.
3. Review the **Events** tab for stack creation progress.
4. After success, review the **Outputs** tab for `BackendLoadBalancerDns`, `DBEndpointAddress`, and CodeDeploy resource names.

### Verify the frontend stack
1. Open **CloudFormation**.
2. Select `sprintly-frontend`.
3. Review the **Outputs** tab for `CloudFrontDomainName`.

### Verify the pipeline stack
1. Open **CodePipeline**.
2. Select `sprintly-ci-pipeline`.
3. Review the latest execution stage for Source, Build, and Deploy status.
4. If the build fails, click the CodeBuild project link and inspect the logs.

## Pipeline behavior
- Pulls source from GitHub.
- Builds the Spring Boot backend JAR and packages CodeDeploy artifacts.
- Builds the React frontend and syncs `Frontend/dist` to the S3 bucket.
- Invalidates the CloudFront distribution.
- Deploys backend artifacts to EC2 instances in the Auto Scaling Group via CodeDeploy.

## Accessing the app
- Backend URL: output `BackendLoadBalancerDns` from the `sprintly-backend` stack.
- Frontend URL: output `CloudFrontDomainName` from the `sprintly-frontend` stack.

## Optional improvements
- Add Route53 recordsets and ACM for a custom domain.
- Add AWS WAF to the CloudFront distribution.
- Add an RDS proxy or Redis/ElastiCache if caching or connection pooling is needed.
- Add a more robust service manager on EC2 (systemd or Supervisor) instead of `nohup`.

## Troubleshooting
- If the pipeline does not start, verify CodeStar Connection status in the AWS Console.
- If backend instances fail to start, check the CodeDeploy deployment logs and `/opt/sprintly/app.log` on the instance.
- If CloudFront assets are stale, verify invalidation success in the CodeBuild logs.
