# 🚀 combo-cliproxy

**One-click deployment toolkit** for running [9Router](https://github.com/decolua/9router) on **Google Cloud Run** — the fastest, cheapest way to host your own AI model proxy in the cloud.

> **combo-cliproxy** = **Combo** (multi-provider AI combos) + **CLI** (command-line interface) + **Proxy** (AI API proxy/router)

---

## 🤔 What is this?

This project provides a **fully automated bash script** to deploy [9Router](https://github.com/decolua/9router) to Google Cloud Run with zero manual steps. No clicking through GCP Console, no copy-pasting commands — just run `./deploy.sh` and answer a few questions (or skip them all with `--fast`).

### What is 9Router?

[**9Router**](https://github.com/decolua/9router) by [**@decolua**](https://github.com/decolua) is a free, open-source **AI model router** that connects ALL your AI coding tools (Claude Code, Cursor, Antigravity, Copilot, Codex, Gemini CLI, Cline, OpenClaw...) to **40+ AI providers & 100+ models** through a single OpenAI-compatible endpoint.

**Key highlights of 9Router:**
- 🎯 **Smart 3-Tier Fallback** — Subscription → Cheap → Free, zero downtime
- 📊 **Real-Time Quota Tracking** — Token consumption, reset countdowns, cost estimation
- 🔄 **Format Translation** — OpenAI ↔ Claude ↔ Gemini, seamless conversion
- 👥 **Multi-Account Support** — Round-robin between accounts per provider
- 🔄 **Auto Token Refresh** — OAuth tokens refresh automatically
- 🎨 **Custom Combos** — Mix subscription, cheap, and free tiers into named combos
- 💾 **Cloud Sync** — Sync settings across devices

---

## 🏗️ Architecture

```
┌───────────────────────────────────────────────────────┐
│               Your AI Coding Tools                     │
│  (Claude Code, Cursor, Codex, Gemini CLI, Cline...)   │
└──────────────────────┬────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│             combo-cliproxy (Cloud Run)                │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │              9Router Engine                      │ │
│  │                                                  │ │
│  │  📡 OpenAI-compatible API (/v1)                 │ │
│  │  🎛️ Dashboard UI (/dashboard)                   │ │
│  │  🔄 Smart routing & fallback                    │ │
│  │  📊 Usage analytics & quota tracking            │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  ⚙️  Cloud Run Config:                               │
│  • Memory: 512Mi  • CPU: 1 vCPU                     │
│  • Scale: 0→2 instances (pay-per-use)               │
│  • Port: 20128                                       │
│  • Cold start: ~2-5s (scale from zero)              │
└──────────────────────┬───────────────────────────────┘
                       │
          ┌────────────┼────────────────┐
          ▼            ▼                ▼
   ┌───────────┐ ┌───────────┐  ┌───────────────┐
   │  Tier 1   │ │  Tier 2   │  │    Tier 3     │
   │SUBSCRIPTION│ │  CHEAP    │  │    FREE       │
   │           │ │           │  │               │
   │ Claude    │ │ GLM-4.7   │  │ iFlow         │
   │ Codex     │ │ $0.6/1M   │  │ Qwen          │
   │ Gemini    │ │ MiniMax   │  │ Kiro          │
   │           │ │ $0.2/1M   │  │ (unlimited)   │
   └───────────┘ └───────────┘  └───────────────┘
```

### 🌐 Recommended Access Pattern

| Access Method | URL | Latency | Use Case |
|---------------|-----|---------|----------|
| **Direct Cloud Run** | `https://combo-cliproxy-xxx.us-west1.run.app` | **~0.38s** | AI tools (Cursor, Claude Code, etc.) |
| **Custom Domain** | `https://combo.yourdomain.com` (via Tunnel) | ~0.93s | Dashboard access (browser) |

> 💡 **Pro tip**: Use the direct Cloud Run URL for AI tools to get the fastest response time. Custom domain adds ~0.55s overhead per request.

---

## ⚡ Quick Start

### Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud` CLI)
- [Git](https://git-scm.com/)
- A GCP account with billing enabled
- *(Optional)* [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) — for custom domain setup

### 1. Clone & Run

```bash
git clone https://github.com/Codek365/combo-cliproxy.git
cd combo-cliproxy
chmod +x deploy.sh
./deploy.sh
```

### 2. Choose from the menu

```
═══ Main Menu ═════════════════════════════

  1) 🏗️  Setup GCP Project (create project, enable APIs, billing)
  2) 🚀 Build & Deploy (build Docker, push, deploy Cloud Run)
  3) ⚡ Full Setup + Deploy (1 + 2 combined)
  4) 🔄 Quick Redeploy (same image, new revision)
  5) 📊 Show Status (services, VMs, revisions)
  6) 🧹 Cleanup (delete services, VMs, images)
  7) 🔄 Switch GCP Account
  8) ⚡ Deploy with all defaults (no questions, fastest)

  0) Exit
```

### 3. Zero-question deploy (fastest)

```bash
# Deploy with all defaults — no questions asked
./deploy.sh --fast
```

That's it! Your 9Router instance will be live on Cloud Run in ~3 minutes. 🎉

---

## 🔐 Google Cloud (`gcloud`) Setup Guide

If you haven't set up `gcloud` CLI yet, follow these steps:

### Install `gcloud` CLI

**macOS** (Homebrew):
```bash
brew install --cask google-cloud-sdk
```

**macOS** (Manual):
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL   # Restart shell
```

**Linux** (Debian/Ubuntu):
```bash
sudo apt-get install apt-transport-https ca-certificates gnupg curl
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update && sudo apt-get install google-cloud-cli
```

**Windows** (PowerShell):
```powershell
(New-Object Net.WebClient).DownloadFile("https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe", "$env:Temp\GoogleCloudSDKInstaller.exe")
& $env:Temp\GoogleCloudSDKInstaller.exe
```

### Login & Authenticate

```bash
# 1. Login to Google account (opens browser)
gcloud auth login

# 2. Set your project
gcloud config set project YOUR_PROJECT_ID

# 3. Verify login
gcloud auth list
#   ✓ your-email@gmail.com (ACTIVE)

# 4. Configure Docker auth (needed for pushing images)
gcloud auth configure-docker us-west1-docker.pkg.dev
```

### Multi-Account Management

```bash
# Add another Google account
gcloud auth login --no-launch-browser  # For headless/SSH

# List all accounts
gcloud auth list

# Switch between accounts
gcloud config set account your-other-email@gmail.com

# Set default project per account
gcloud config set project MY_OTHER_PROJECT

# Quick check: who am I?
gcloud config get account
gcloud config get project
```

### Common `gcloud` Commands

```bash
# List all projects you have access to
gcloud projects list

# Create a new project
gcloud projects create my-new-project --name="My Project"

# List billing accounts
gcloud billing accounts list

# Link billing to project
gcloud billing projects link my-new-project --billing-account=XXXXXX-YYYYYY-ZZZZZZ

# List Cloud Run services
gcloud run services list --project=YOUR_PROJECT

# View logs
gcloud run services logs read combo-cliproxy --region=us-west1 --limit=50

# Delete a service
gcloud run services delete combo-cliproxy --region=us-west1
```

---

## 🌐 Cloudflare Tunnel (`cloudflared`) Setup Guide

Use Cloudflare Tunnel to map a **custom domain** (e.g. `combo.yourdomain.com`) to your Cloud Run service — with free SSL, DDoS protection, and no open ports needed.

### Why use a Tunnel?

| | Direct Cloud Run URL | Custom Domain (Tunnel) |
|---|---|---|
| **URL** | `combo-cliproxy-xxx.us-west1.run.app` | `combo.yourdomain.com` |
| **Latency** | ~0.38s ✅ | ~0.93s |
| **Memorable** | ❌ Long, auto-generated | ✅ Short, custom |
| **SSL** | ✅ Auto (Google) | ✅ Auto (Cloudflare) |
| **Use for** | AI tools (API calls) | Dashboard (browser) |

> 💡 **Best practice**: Use Cloud Run URL for AI tools (fastest), Tunnel for dashboard access only.

### Install `cloudflared`

**macOS:**
```bash
brew install cloudflared
```

**Linux (Debian/Ubuntu):**
```bash
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install cloudflared
```

**Linux (Generic):**
```bash
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

**Windows:**
```powershell
winget install Cloudflare.cloudflared
```

### Step 1: Login to Cloudflare

```bash
cloudflared tunnel login
# → Opens browser → Select your domain → Authorizes
# → Saves cert.pem to ~/.cloudflared/
```

### Step 2: Create a Tunnel

```bash
# Create tunnel (pick a name)
cloudflared tunnel create combo-tunnel

# Note the Tunnel ID (e.g. abcd1234-5678-...)
# Credentials saved to ~/.cloudflared/<TUNNEL_ID>.json
```

### Step 3: Configure the Tunnel

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: abcd1234-5678-xxxx-yyyy-zzzzzzzzzzzz  # Your Tunnel ID
credentials-file: /home/user/.cloudflared/abcd1234-5678-xxxx-yyyy-zzzzzzzzzzzz.json

ingress:
  # Route custom domain to Cloud Run
  - hostname: combo.yourdomain.com
    service: https://combo-cliproxy-XXXXXXXXXX.us-west1.run.app
    originRequest:
      httpHostHeader: combo-cliproxy-XXXXXXXXXX.us-west1.run.app
      noTLSVerify: false

  # Catch-all (required)
  - service: http_status:404
```

> ⚠️ **Important**: Replace the Cloud Run URL and hostname with your actual values.

> 💡 **`httpHostHeader`** is critical — it tells Cloud Run which service to route to. Without it, you'll get 404 errors.

### Step 4: Add DNS Record

```bash
# Create CNAME record pointing to your tunnel
cloudflared tunnel route dns combo-tunnel combo.yourdomain.com
# → Creates CNAME: combo.yourdomain.com → <TUNNEL_ID>.cfargotunnel.com
```

Or manually in Cloudflare Dashboard:
- **Type:** CNAME
- **Name:** `combo`
- **Target:** `<TUNNEL_ID>.cfargotunnel.com`
- **Proxy:** ☁️ Proxied

### Step 5: Run the Tunnel

```bash
# Test run (foreground)
cloudflared tunnel run combo-tunnel

# Run as background service
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared  # Start on boot
```

### Step 6: Verify

```bash
# Check tunnel status
cloudflared tunnel info combo-tunnel

# Test your custom domain
curl -I https://combo.yourdomain.com
# Should return HTTP 200 or 302
```

### Performance Optimization (Cloudflare Dashboard)

To minimize latency through the tunnel, disable these on your domain zone:

1. **Speed → Optimization → Rocket Loader** → ❌ Off
2. **Speed → Optimization → Auto Minify** → ❌ Uncheck all (JS, CSS, HTML)
3. **Email → Email Routing → Email Obfuscation** → ❌ Off

These features inject JavaScript that can break API responses and add latency.

### Tunnel Architecture

```
┌──────────────┐        ┌───────────────┐        ┌─────────────────┐
│   Browser    │───────→│  Cloudflare   │───────→│   Cloud Run     │
│              │  HTTPS │   Edge/CDN    │ Tunnel │                 │
│ combo.your   │        │   (global)    │        │ combo-cliproxy  │
│ domain.com   │        │               │        │ :20128          │
└──────────────┘        └───────────────┘        └─────────────────┘
                         ↑
                    Free SSL + DDoS
                    + Caching + WAF
```

---

## 📖 What the Script Does

### 🏗️ Option 1: Setup GCP Project

Automates the entire GCP project initialization:

| Step | What it does |
|------|-------------|
| **Create Project** | Creates a new GCP project (or uses existing) |
| **Link Billing** | Lists available billing accounts and links one |
| **Enable APIs** | Enables Cloud Run, Cloud Build, Artifact Registry, Container Registry |
| **Create Registry** | Creates an Artifact Registry Docker repository |
| **Configure Auth** | Sets up Docker authentication for the registry |

### 🚀 Option 2: Build & Deploy

Handles the full Docker build and Cloud Run deployment:

| Step | What it does |
|------|-------------|
| **Source Code** | 3 options: clone from Git, use local path, or npm package |
| **Build Strategy** | Cloud Build (no local Docker needed) or local Docker build |
| **Push Image** | Pushes to Artifact Registry with `latest` + timestamp tags |
| **Deploy** | Deploys to Cloud Run with all env vars and scaling config |
| **Health Check** | Verifies the service is responding after deployment |
| **Cleanup** | Optionally removes the build directory |

### 📋 Full Configuration Options

Every setting has a sensible default — just press Enter to accept:

```
? GCP Project ID [maxai-omi-2026]:
? Region [us-west1]:
? Service name [combo-cliproxy]:
? Docker image name [combo-cliproxy]:
? Application port [20128]:
? Memory [512Mi]:
? CPU [1]:
? Min instances [0]:
? Max instances [2]:
? Initial password [123456]:
? Source repo URL [https://github.com/decolua/9router]:
? Dockerfile path [/tmp/9router-deploy/Dockerfile]:
```

---

## 🐳 Dockerfiles

This project includes two Dockerfile strategies:

### Strategy 1: Full Build (recommended for production)

Clones the 9Router source, builds a standalone Next.js app with multi-stage Docker build. Smaller image, faster startup.

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --no-audit --no-fund
COPY . ./
# Fix testUtils import path
RUN find src/app/api/providers -name "testUtils.js" -exec cp {} src/lib/testUtils.js \;
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production PORT=20128 HOSTNAME=0.0.0.0
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 20128
CMD ["node", "server.js"]
```

### Strategy 2: NPM Package (simplest)

Installs 9Router globally from npm. Just 14 lines, works anywhere.

```dockerfile
FROM node:20-alpine
WORKDIR /app
RUN npm install -g 9router
ENV NODE_ENV=production PORT=20128 HOSTNAME=0.0.0.0
EXPOSE 20128
CMD ["9router"]
```

---

## 🔧 CLI Flags

Run non-interactively with flags:

```bash
./deploy.sh --fast       # Deploy with all defaults (no questions)
./deploy.sh --deploy     # Build & deploy (with config questions)
./deploy.sh --setup      # Setup GCP project only
./deploy.sh --status     # Show current status
./deploy.sh --cleanup    # Cleanup resources
./deploy.sh --help       # Show help
```

### Environment Variable Overrides

Override defaults without editing the script:

```bash
PROJECT_ID=my-project SERVICE_NAME=my-router ./deploy.sh --fast
```

---

## 💰 Cost Estimation

Cloud Run with this configuration is essentially **free** for personal use:

| Resource | Cost | Notes |
|----------|------|-------|
| Cloud Run | ~$0/month | Scale to zero, 2M free requests/month |
| Artifact Registry | ~$0/month | 500MB free storage |
| Cloud Build | ~$0/month | 120 build-minutes free/day |
| **Total** | **~$0/month** | Within GCP free tier |

> ⚠️ **Cold Start**: With `min-instances: 0`, the first request after idle takes ~2-5 seconds. Set `min-instances: 1` to eliminate cold starts (~$10-15/month).

---

## 📂 Project Structure

```
combo-cliproxy/
├── deploy.sh           # 🚀 Main deployment script (interactive menu)
└── README.md           # 📖 This file
```

---

## 🛡️ Security Notes

- Change the default password (`INITIAL_PASSWORD`) after first deployment
- Cloud Run services are set to `--allow-unauthenticated` for API access
- Consider using [Cloud IAM](https://cloud.google.com/run/docs/authenticating/overview) for production
- The 9Router dashboard has its own password protection

---

## 🙏 Acknowledgments & Credits

This project would not exist without the incredible work of:

### [9Router](https://github.com/decolua/9router) by [@decolua](https://github.com/decolua)

**A massive thank you to the 9Router team** for building such an amazing, free, open-source AI router. 9Router is the **core engine** that powers everything — our `combo-cliproxy` project is simply a deployment wrapper to make it easy to run 9Router on Google Cloud Run.

> *"Connect All AI Code Tools to 40+ AI Providers & 100+ Models"*

9Router's smart 3-tier fallback system, real-time quota tracking, and seamless format translation are what make this whole thing possible. If you find this project useful, please:

- ⭐ **Star** the [9Router repo](https://github.com/decolua/9router)
- 🐛 **Report issues** to [9Router Issues](https://github.com/decolua/9router/issues)
- 💬 **Join** the 9Router community
- 🌐 Visit [9router.com](https://9router.com)

### [CLIProxyAPI](https://github.com/niceparable/CLIProxyAPI)

Special thanks to CLIProxyAPI — the original Go implementation that inspired the JavaScript port that became 9Router.

### Contributors

Thanks to all [38+ contributors](https://github.com/decolua/9router/graphs/contributors) who helped make 9Router better!

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

This project uses [9Router](https://github.com/decolua/9router) which is also licensed under MIT.

---

<div align="center">

**Made with ❤️ for the AI coding community**

[9Router](https://github.com/decolua/9router) · [Report Bug](https://github.com/Codek365/combo-cliproxy/issues) · [Request Feature](https://github.com/Codek365/combo-cliproxy/issues)

</div>
