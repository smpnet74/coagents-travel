# CoAgents Travel

This example contains a Travel Planner application with search capabilities using CoAgents.

**These instructions assume you are in the `coagents-travel/` directory**

## ⚠️ **Quick Setup for Your Own Repository**

This project contains references to specific GitHub usernames and domains that you need to customize:

### **Required Customizations:**

1. **GitHub Container Registry Images** (in `k8s/*/deployment.yaml`):
   ```yaml
   # Change from:
   image: ghcr.io/smpnet74/coagents-travel-backend:latest
   # To:
   image: ghcr.io/YOUR-USERNAME/coagents-travel-backend:latest
   ```

2. **Domain Name** (in `k8s/frontend/httproute.yaml`):
   ```yaml
   # Change from:
   hostnames: ["travelexample.timbersedgearb.com"]
   # To:
   hostnames: ["your-domain.com"]
   ```

3. **GitHub Organization** (in `.github/workflows/ci-cd.yml`):
   - The workflow automatically uses your repository name, but verify the image names match your desired naming convention

## Deployment Modes

This application supports multiple deployment modes with intelligent GitOps:

- **Local Development Mode**: Run locally with hot-reload for development
- **Manual Kubernetes Deployment**: Deploy using automated scripts (`scripts/deploy-k8s.sh`)
- **GitOps Mode**: Automated CI/CD deployment that handles both fresh deployments and updates

### GitOps Toggle

**GitOps is disabled by default** to prevent accidental deployments during development.

Current state: `.github/workflows/ci-cd.yml.disabled` (GitOps disabled)

```bash
# Enable GitOps mode (when ready for automated deployments)
mv .github/workflows/ci-cd.yml.disabled .github/workflows/ci-cd.yml

# Disable GitOps mode (safe for development)
mv .github/workflows/ci-cd.yml .github/workflows/ci-cd.yml.disabled
```

**⚠️ Important**: Only enable GitOps after setting up GitHub secrets and testing manual deployment.

When GitOps is enabled, every push to the `main` branch will trigger automated build and deployment.

## Prerequisites

### Required Software

- **Docker** and **Docker Compose**: For containerized deployment
- **kubectl**: For Kubernetes deployment
- **Node.js** and **pnpm**: For frontend development
- **Python** and **Poetry**: For backend development
- **Git**: For version control

### API Keys Setup

You'll need to obtain the following API keys:

1. **OpenAI API Key**:
   - Visit [OpenAI API Keys](https://platform.openai.com/api-keys)
   - Create a new API key
   - Ensure it has access to GPT-4o

2. **Google Maps API Key**:
   - Visit [Google Cloud Console](https://console.cloud.google.com/)
   - Enable the Maps JavaScript API
   - Create an API key

3. **GitHub Personal Access Token** (for GitOps):
   - Visit [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/personal-access-tokens/new)
   - Create a token with `packages:write` permission
   - This allows pushing to GitHub Container Registry

## Local Development

### Environment Setup

Create a `.env` file in the project root with your API keys:

```env
# OpenAI API Configuration
OPENAI_API_KEY=sk-your-actual-openai-key-here

# Google Maps API Configuration  
GOOGLE_MAPS_API_KEY=your-actual-google-maps-key-here

# CopilotKit Configuration (optional)
NEXT_PUBLIC_CPK_PUBLIC_API_KEY=your-copilotkit-api-key-here

# Development Configuration
NODE_ENV=development
PORT=3000

# Backend Configuration
BACKEND_PORT=8000
BACKEND_HOST=0.0.0.0
```

**⚠️ Important**: Never commit the `.env` file to version control. It contains sensitive API keys.

### Method 1: Running Services Individually (Inner Loop Development)

**Best for**: Fast development iteration with hot-reload

#### Running the Agent (Backend)

Install dependencies and run the backend:

```bash
cd agent
poetry install
poetry run demo
```

The agent will be available at [http://localhost:8000](http://localhost:8000)
API documentation: [http://localhost:8000/docs](http://localhost:8000/docs)

#### Running the UI (Frontend)

**Important**: The frontend must be configured to connect to localhost backend.

In a new terminal:

```bash
cd ui
pnpm install

# Set backend URL for individual services
export REMOTE_ACTION_URL=http://localhost:8000/copilotkit

pnpm run dev
```

The UI will be available at [http://localhost:3000](http://localhost:3000)

**Note**: When running individually, the frontend connects to `localhost:8000`. In containerized environments, it connects via service names.

### Method 2: Docker Compose (Recommended for Local Testing)

**Best for**: Testing containerized environment locally

This method runs both services in containers with proper networking:

```bash
# Build and run both services
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

The application will be available at [http://localhost:3000](http://localhost:3000)

#### Docker Compose Benefits:
- **Consistent environment**: Same containers as production
- **Service discovery**: Frontend connects to backend via container names (`backend:8000`)
- **Health checks**: Automatic service health monitoring
- **Easy cleanup**: `docker-compose down` removes everything

### Method 3: Automated Kubernetes Deployment (Recommended)

**Best for**: Production-ready deployment with automated scripts

**Prerequisites**: 
- Kubernetes cluster access
- `.env` file with API keys
- Images will be pulled from GHCR (script guides you through building/pushing if needed)

```bash
# Use the automated deployment script
./scripts/deploy-k8s.sh
```

**The script automatically:**
- ✅ Validates prerequisites (kubectl, .env file, API keys)
- ✅ Creates namespace if it doesn't exist
- ✅ Creates secrets securely from .env file
- ✅ Deploys all manifests in correct order
- ✅ Waits for pods to be ready
- ✅ Shows deployment status and troubleshooting info

### Method 4: Manual Kubernetes Deployment (Advanced)

**Best for**: Understanding the deployment process or custom requirements

**Prerequisites**: 
- Kubernetes cluster access
- Images available in GHCR (build/push first)

```bash
# 1. Apply Kubernetes manifests
kubectl apply -f k8s/

# 2. Create secrets from your .env file
kubectl create secret generic travel-secrets \
  --from-literal=OPENAI_API_KEY="$(grep OPENAI_API_KEY .env | cut -d'=' -f2)" \
  --from-literal=GOOGLE_MAPS_API_KEY="$(grep GOOGLE_MAPS_API_KEY .env | cut -d'=' -f2)" \
  --namespace=app-travelexample \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Create GHCR image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=your-github-username \
  --docker-password=your-github-token \
  --namespace=app-travelexample

# 4. Check deployment status
kubectl get pods -n app-travelexample

# 5. Access via port forwarding (if no ingress)
kubectl port-forward -n app-travelexample service/travel-frontend-service 8080:3000

# 6. Access application
open http://localhost:8080
```

**Note**: This method requires images to be pushed to GHCR first. The k8s manifests reference GHCR images, not local images.

## Manual Production Deployment

### Build and Push Docker Images

**When to use**: Before manual Kubernetes deployment or to prepare for GitOps

```bash
# 1. Build backend image
docker build -t ghcr.io/your-username/coagents-travel-backend:latest ./agent

# 2. Build frontend image
docker build -t ghcr.io/your-username/coagents-travel-frontend:latest ./ui

# 3. Login to GHCR (set GHCR_TOKEN environment variable first)
echo $GHCR_TOKEN | docker login ghcr.io -u your-username --password-stdin

# 4. Push images
docker push ghcr.io/your-username/coagents-travel-backend:latest
docker push ghcr.io/your-username/coagents-travel-frontend:latest
```

**Note**: Replace `your-username` with your actual GitHub username.

## GitOps Deployment

### Prerequisites

1. Kubernetes cluster with kubectl access
2. GitHub repository with Actions enabled
3. GitHub Container Registry (GHCR) access
4. GitHub Personal Access Token with `packages:write` permission

### GitHub Repository Secrets

Configure the following secrets in your GitHub repository as **Repository secrets** (not Environment secrets):

**Navigation**: GitHub repository → Settings → Secrets and variables → Actions → **Repository secrets** → "New repository secret"

#### Required Repository Secrets:

1. **`OPENAI_API_KEY`**
   - Description: OpenAI API key for AI functionality
   - Value: Your OpenAI API key

2. **`GOOGLE_MAPS_API_KEY`**
   - Description: Google Maps API key for location services
   - Value: Your Google Maps API key

3. **`GHCR_TOKEN`**
   - Description: GitHub Personal Access Token for container registry
   - Value: GitHub PAT with `packages:write` permission

4. **`KUBECONFIG`**
   - Description: Base64-encoded kubeconfig for cluster access
   - Value: Run `base64 -i /path/to/kubeconfig` and paste the output

**Important Notes:**
- Use **Repository secrets** (available to all workflows in the repository)
- **Do not use Environment secrets** (those are for specific deployment environments)
- These secrets will be available to the GitHub Actions workflow when it runs
- Never commit these values to your repository - they are sensitive credentials

### CI/CD Workflow

The GitHub Actions workflow (`.github/workflows/ci-cd.yml`) is **intelligent and idempotent**, automatically handling both fresh deployments and updates:

#### **For Fresh Deployments** (destroyed/new clusters):
1. **Detects** missing namespace and creates it
2. **Builds** Docker images for backend and frontend  
3. **Pushes** images to GitHub Container Registry (GHCR)
4. **Applies** all Kubernetes manifests
5. **Creates/Updates** secrets 
6. **Waits** for deployments to become available
7. **Verifies** deployment success

#### **For Updates** (existing deployments):
1. **Detects** existing namespace and skips creation
2. **Builds** new Docker images with latest code
3. **Pushes** updated images to GHCR with `:latest` tag
4. **Applies** manifest updates (if any)
5. **Triggers** rolling restart to pull new images
6. **Verifies** rollout completion

#### **GitOps Pipeline Features:**
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Intelligent**: Adapts to fresh vs. existing deployments  
- ✅ **Automated**: No manual intervention required
- ✅ **Safe**: Validates each step before proceeding
- ✅ **Fast**: Only updates what's changed
- ✅ **Robust**: Handles deployment timing issues automatically
- ✅ **Image Management**: Uses `:latest` tags with rolling restarts for updates

### Deployment Process

1. **Enable GitOps mode** (if not already enabled)
2. **Configure GitHub secrets** as described above
3. **Push to main branch** to trigger deployment

```bash
git add .
git commit -m "Deploy to production"
git push origin main
```

4. **Monitor deployment** in GitHub Actions tab
5. **Access application** at your configured domain

### Manual Production Deployment

For manual deployment to production Kubernetes cluster:

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/

# Create secrets from environment variables or direct input
kubectl create secret generic travel-secrets \
  --from-literal=OPENAI_API_KEY="your-openai-key" \
  --from-literal=GOOGLE_MAPS_API_KEY="your-google-maps-key" \
  --namespace=app-travelexample \
  --dry-run=client -o yaml | kubectl apply -f -

# Create GHCR image pull secret for production images
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=your-github-username \
  --docker-password=your-github-token \
  --namespace=app-travelexample

# Check deployment status
kubectl get pods -n app-travelexample

# Check service status
kubectl get services -n app-travelexample

# Check HTTPRoute (if using Gateway API)
kubectl get httproute -n app-travelexample

# View logs
kubectl logs -n app-travelexample -l app=travel-frontend
kubectl logs -n app-travelexample -l app=travel-backend
```

## 🚀 **Deployment Scenarios Explained**

Understanding when to use each deployment method:

### **Scenario 1: Fresh Development Setup**
**Situation**: New repository, first time setup  
**Goal**: Get development environment running quickly  
**Method**: Local Development (Method 1 or 2)
```bash
# Quick start for development
cp .env.example .env  # Add your API keys
docker-compose up --build
```

### **Scenario 2: Testing Production Deployment**  
**Situation**: Want to test Kubernetes deployment before GitOps  
**Goal**: Validate manifests work correctly  
**Method**: Automated Kubernetes Deployment (Method 3)
```bash
./scripts/deploy-k8s.sh
```

### **Scenario 3: Fresh Cluster Deployment**
**Situation**: New/destroyed Kubernetes cluster, nothing exists  
**Goal**: Deploy application via GitOps automation  
**Method**: GitOps Mode
- Pipeline automatically creates namespace and all resources
- Handles complete fresh deployment

### **Scenario 4: Development Updates**
**Situation**: Existing deployment, making code changes  
**Goal**: Update running application  
**Method**: GitOps Mode
- Pipeline detects existing resources and updates them
- Only rebuilds/redeploys what changed

### **Scenario 5: Emergency Rollback**
**Situation**: Something went wrong with latest deployment  
**Goal**: Quick return to working state  
**Method**: Manual rollback
```bash
kubectl rollout undo deployment/travel-backend -n app-travelexample
kubectl rollout undo deployment/travel-frontend -n app-travelexample
```

## Architecture

### Application Components

- **Backend**: Python LangGraph agent with FastAPI (port 8000)
- **Frontend**: Next.js application with CopilotKit (port 3000)
- **Communication**: Frontend connects to backend via service discovery

### Container Images

- **Backend**: `ghcr.io/owner/repo-backend:latest`
- **Frontend**: `ghcr.io/owner/repo-frontend:latest`

### Kubernetes Resources

- **Namespace**: `app-travelexample`
- **Backend**: Deployment + Service (1 replica, port 8000)
- **Frontend**: Deployment + Service (2 replicas, port 3000)
- **Ingress**: HTTPRoute for external access
- **Secrets**: API keys stored as Kubernetes secrets

## Development Workflow

### **Recommended Development Process** 🎯

#### **Phase 1: Inner Loop Development**

**Goal**: Fast iteration with hot-reload

1. **Customize for your repository** (one-time setup):
   ```bash
   # Update image references in k8s/*/deployment.yaml
   # Update domain in k8s/frontend/httproute.yaml  
   # See "Required Customizations" section above
   ```

2. **Ensure GitOps is disabled** (default state):
   ```bash
   # Verify GitOps is disabled
   ls .github/workflows/ci-cd.yml.disabled  # Should exist
   ```

3. **Set up environment**:
   ```bash
   # Create .env file from template and add your actual API keys
   cp .env.example .env
   # Edit .env file with your actual API keys
   ```

4. **Start development** (choose your preferred method):
   ```bash
   # Method 1: Individual services (fastest)
   cd agent && poetry run demo &
   cd ui && REMOTE_ACTION_URL=http://localhost:8000/copilotkit pnpm run dev

   # Method 2: Docker Compose (containerized)
   docker-compose up --build
   ```

5. **Develop and test** at `http://localhost:3000`

#### **Phase 2: Pre-Production Testing**

**Goal**: Test in production-like environment with automated tools

6. **Test Kubernetes deployment** using automated script:
   ```bash
   # This handles everything: namespace, secrets, deployment
   ./scripts/deploy-k8s.sh
   ```

   **Script benefits:**
   - ✅ Validates prerequisites automatically
   - ✅ Creates namespace if missing
   - ✅ Handles secrets securely
   - ✅ Shows detailed deployment status
   - ✅ Provides troubleshooting info

#### **Phase 3: Production Deployment**

**Goal**: Automated deployment via intelligent GitOps

7. **Set up GitHub secrets** (one-time setup):
   - `OPENAI_API_KEY`: Your OpenAI API key
   - `GOOGLE_MAPS_API_KEY`: Your Google Maps API key  
   - `GHCR_TOKEN`: GitHub PAT with `packages:write` permission
   - `KUBECONFIG`: Base64-encoded kubeconfig (`base64 -i kubeconfig`)

8. **Enable GitOps**:
   ```bash
   mv .github/workflows/ci-cd.yml.disabled .github/workflows/ci-cd.yml
   ```

9. **Deploy to production**:
   ```bash
   git add .
   git commit -m "Deploy to production"
   git push origin main
   ```

10. **Pipeline automatically handles**:
    - 🔍 Detects fresh vs. existing deployment
    - 🏗️ Creates namespace if needed
    - 🐳 Builds and pushes images with `:latest` tag
    - 🚀 Deploys new applications OR triggers rolling restarts for updates
    - ⏱️ Handles deployment timing and readiness automatically
    - ✅ Validates deployment success

11. **Monitor deployment** in GitHub Actions tab

### **Development Best Practices** ⭐

- **Start with Local Development** for fastest iteration cycles
- **Use automated deployment script** (`./scripts/deploy-k8s.sh`) for reliable Kubernetes testing
- **Customize repository settings** before first deployment (images, domain)
- **Test with automated script** before enabling GitOps
- **Keep GitOps disabled** during active development to prevent accidental deployments
- **Use feature branches** for experimental changes
- **Leverage intelligent GitOps** - it handles fresh deployments and updates automatically
- **Monitor GitHub Actions** for deployment status and troubleshooting
- **Use rollback commands** for quick recovery if needed

### Rollback

If deployment fails, rollback to previous version:

```bash
# Rollback deployments
kubectl rollout undo deployment/travel-backend -n app-travelexample
kubectl rollout undo deployment/travel-frontend -n app-travelexample

# Verify rollback
kubectl rollout status deployment/travel-backend -n app-travelexample
kubectl rollout status deployment/travel-frontend -n app-travelexample
```

## LangGraph Studio

Run LangGraph studio, then load the `./agent` folder into it.

Make sure to create the `.env` files mentioned above first!

## Troubleshooting

### Local Development Issues

#### Service Issues
- **Port conflicts**: Make sure no other application is using ports 3000 or 8000
- **API connectivity**: In `/agent/travel/demo.py`, change `0.0.0.0` to `127.0.0.1` if needed
- **Environment variables**: Ensure `.env` file is properly configured and in project root

#### Docker Compose Issues
- **Container build fails**: Check Dockerfile syntax and dependencies
- **Services don't communicate**: Verify network configuration and service names
- **Health checks fail**: Check service startup time and health check endpoints
- **Port binding errors**: Ensure ports 3000 and 8000 are available

```bash
# Debug Docker Compose
docker-compose ps                    # Check service status
docker-compose logs backend          # View backend logs
docker-compose logs frontend         # View frontend logs
docker-compose down --volumes        # Clean up everything
```

#### Individual Service Issues
- **Poetry dependencies**: Run `poetry install` in agent directory
- **Node dependencies**: Run `pnpm install` in ui directory
- **Python path issues**: Ensure you're in the agent directory when running poetry commands

### Kubernetes Deployment Issues

#### Local Kubernetes Testing
- **Namespace errors**: Ensure `app-travelexample` namespace exists
- **Image pull failures**: Check if images exist and secrets are configured
- **Service discovery**: Verify service names and namespaces match manifests

```bash
# Debug Kubernetes deployment
kubectl get pods -n app-travelexample                    # Check pod status
kubectl describe pod -n app-travelexample <pod-name>     # Detailed pod info
kubectl logs -n app-travelexample -l app=travel-frontend # View logs
kubectl get events -n app-travelexample                  # Check events
```

#### Production Kubernetes Issues
- **Pod stuck in Pending**: Check resource limits and node capacity
- **ImagePullBackOff**: Verify GHCR credentials and image tags
- **Service unreachable**: Check service configuration and network policies

### GitOps Deployment Issues

#### Most Common Issues (Both Fixed!)

**Error 1**: `Error from server (NotFound): error when creating "STDIN": namespaces "app-travelexample" not found`

**Cause**: Deploying to a fresh/destroyed cluster where the namespace doesn't exist.

**Solution**: ✅ **Fixed!** Pipeline now automatically detects and creates missing namespaces.

**Error 2**: `Error from server (NotFound): deployments.apps "travel-backend" not found`

**Cause**: Pipeline trying to update deployments before they're fully created on fresh deployments.

**Solution**: ✅ **Fixed!** Pipeline now intelligently handles both scenarios:
- **Fresh deployments**: Waits for deployments to become available
- **Existing deployments**: Triggers rolling restart to pull new images

**If you see these errors**: Your pipeline version is outdated. Ensure you have the latest `.github/workflows/ci-cd.yml` from this repository.

#### GitHub Actions Issues
- **Workflow not triggering**: Check if workflow file is enabled (not .disabled)
- **Build failures**: Check GitHub Actions logs for specific error messages  
- **Push to GHCR fails**: Verify GHCR_TOKEN permissions and repository settings

```bash
# Check GitHub Actions from CLI (if gh CLI installed)
gh workflow list
gh run list
gh run view <run-id>
```

#### Secret Configuration Issues
- **API key errors**: Verify secrets are properly configured in GitHub UI
- **kubectl access denied**: Ensure KUBECONFIG is properly base64 encoded
- **Image pull errors**: Check GHCR_TOKEN has `packages:write` permission

#### Deployment Scenarios Troubleshooting

| Scenario | Expected Behavior | Troubleshooting |
|----------|------------------|-----------------|
| **Fresh Cluster** | Pipeline creates namespace, applies manifests, deploys images | Check GitHub Actions logs for manifest application errors |
| **Existing Development** | Pipeline skips namespace creation, updates deployments | Verify existing deployments can be updated |
| **Failed Previous Deploy** | Pipeline recreates failed resources | Check for stuck resources: `kubectl get all -n app-travelexample` |

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **Namespace "app-travelexample" not found** | Fresh cluster, namespace doesn't exist | ✅ Fixed in latest GitOps pipeline - update your workflow file |
| **Deployments "travel-backend" not found** | Pipeline trying to update non-existent deployments | ✅ Fixed in latest GitOps pipeline - update your workflow file |
| **Port 3000 already in use** | Another service using port | `lsof -ti:3000 \| xargs kill -9` |
| **Backend not accessible** | Wrong host binding | Change `0.0.0.0` to `127.0.0.1` in demo.py |
| **Frontend can't reach backend** | Network configuration | Check REMOTE_ACTION_URL in docker-compose.yml |
| **Docker build fails** | Missing dependencies | Check Dockerfile and run `docker system prune` |
| **kubectl command fails** | Wrong context/config | Verify `kubectl config current-context` |
| **GitHub Actions fails** | Missing secrets | Check all required secrets are configured |
| **Image pull fails** | Authentication issue | Verify GHCR_TOKEN and image permissions |
| **Pod crash loop** | Application error | Check pod logs with `kubectl logs` |
| **GitOps pipeline stuck** | Resource conflicts | Check for existing resources and clean up manually |

### Getting Help

1. **Check logs first**: Always start with service/pod logs
2. **Verify environment**: Ensure `.env` file is properly configured
3. **Test step by step**: Start with individual services, then Docker Compose, then Kubernetes
4. **Use health checks**: Monitor service health endpoints
5. **Check GitHub Actions**: Review workflow logs for deployment issues

## Production Considerations

- **Scaling**: Frontend can be scaled to multiple replicas
- **Backend state**: Current implementation uses in-memory state (single replica)
- **Monitoring**: Add health checks and monitoring for production use
- **Security**: Rotate API keys regularly and use proper RBAC

test