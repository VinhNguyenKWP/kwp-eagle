param(
  [string]$CommitMsg = "kwp_eagle: Update code",
  [switch]$NoCommit,            # skip creating a new commit
  [switch]$NoPush,              # skip pushing to remote
  [string]$Remote     = "origin",
  [string]$Branch     = "",     # empty -> auto-detect or create 'main' on init
  [string]$RemoteUrl  = ""      # if provided and remote missing, set it
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Exec($cmd, [switch]$Quiet) {
  if (-not $Quiet) { Write-Host ("> " + $cmd) -ForegroundColor DarkGray }
  $out = Invoke-Expression $cmd 2>&1
  $code = $LASTEXITCODE
  if ($code -ne 0) { throw ($out | Out-String) }
  return $out
}

function Run-Push([string]$args) {
  $out = & git $args 2>&1
  $code = $LASTEXITCODE
  $out | ForEach-Object { Write-Host $_ }
  if ($code -ne 0) { throw "git $args failed with exit code $code" }
}

# 0) Ensure git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "Git is not installed or not found in PATH. Install Git for Windows and restart VS Code."
}
Exec "git --version" -Quiet | Out-Null

# 1) Ensure repo exists; if not, init
$inside = ""
try { $inside = (Exec "git rev-parse --is-inside-work-tree" -Quiet | Out-String).Trim() } catch { $inside = "" }
if ($inside -ne "true") {
  Write-Host "Current folder is not a Git repository. Initializing ..."
  Exec "git init" | Out-Null
  if ([string]::IsNullOrWhiteSpace($Branch)) { $Branch = "main" }
  Exec ("git checkout -b {0}" -f $Branch) | Out-Null
  if (-not [string]::IsNullOrWhiteSpace($RemoteUrl)) {
    Exec ("git remote add {0} {1}" -f $Remote, $RemoteUrl) | Out-Null
  } else {
    Write-Host ("No remote configured. You can set it with: git remote add {0} <url>" -f $Remote)
  }
} else {
  if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = (Exec "git rev-parse --abbrev-ref HEAD" -Quiet | Out-String).Trim()
    if ($Branch -eq "HEAD") { throw "Repository is in DETACHED HEAD state. Please checkout a branch first." }
  }
}

# 2) Ensure .gitattributes (normalize line endings)
$gitattributes = ".gitattributes"
$createdGitAttr = $false
if (-not (Test-Path $gitattributes)) {
  "* text=auto eol=lf`n" | Out-File -FilePath $gitattributes -Encoding utf8
  $createdGitAttr = $true
  # Renormalize only when creating for the first time
  Write-Host "Renormalizing line endings (LF) ..."
  & git add --renormalize . 2>$null | Out-Null
}

# 3) Prepare ignore rules; prefer .gitignore, fallback to .git/info/exclude if locked
$gitignorePath = Join-Path (Get-Location) ".gitignore"
$excludePath   = ".git\info\exclude"
$ignorePatterns = @(
  ".venv/",
  "__pycache__/",
  ".pytest_cache/",
  "*.pyc",
  ".env",
  ".env.*",
  "token.json",
  "credentials.json",
  "service_account.json",
  ".vscode/",
  ".idea/",
  ".DS_Store",
  ".mypy_cache/",
  ".ruff_cache/",
  ".ipynb_checkpoints/",
  ".coverage",
  "coverage.xml",
  "build/",
  "dist/",
  ".python-version",
  "logs/"
)

Write-Host "Clean and update ignore rules ..."
function Add-Line-Safe([string]$filePath, [string]$line) {
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  if (-not (Test-Path $filePath)) { New-Item -ItemType File -Path $filePath -Force | Out-Null }
  $existing = @()
  try {
    $existing = Get-Content -LiteralPath $filePath -ErrorAction Stop
    if ($existing -is [string]) { $existing = @($existing) }
  } catch {
    throw
  }
  if ($existing -notcontains $line) {
    [System.IO.File]::AppendAllText($filePath, $line + [Environment]::NewLine, $utf8)
  }
}

$wroteToGitignore = $true
try {
  foreach ($p in $ignorePatterns) { Add-Line-Safe $gitignorePath $p }
} catch {
  Write-Host ".gitignore is locked; writing to .git/info/exclude instead."
  New-Item -ItemType Directory -Force ".git\info" | Out-Null
  foreach ($p in $ignorePatterns) { Add-Line-Safe $excludePath $p }
  $wroteToGitignore = $false
}

# 4) Untrack junk only if tracked (avoid pathspec errors)
function Untrack-IfTracked([string]$path, [switch]$Recursive) {
  $tracked = & git ls-files --cached -- "$path" 2>$null
  if ($tracked) {
    if ($Recursive) {
      & git rm -r -f --cached -- "$path" 2>$null | Out-Null
    } else {
      & git rm -f --cached -- "$path" 2>$null | Out-Null
    }
  }
}

Untrack-IfTracked ".venv"           -Recursive
Untrack-IfTracked "__pycache__"     -Recursive
Untrack-IfTracked ".pytest_cache"   -Recursive
Untrack-IfTracked "build"           -Recursive
Untrack-IfTracked "dist"            -Recursive
Untrack-IfTracked ".vscode"         -Recursive
Untrack-IfTracked ".idea"           -Recursive

Untrack-IfTracked ".env"
# Add specific .env.* variants if needed:
# Untrack-IfTracked ".env.local"
# Untrack-IfTracked ".env.dev"
Untrack-IfTracked "token.json"
Untrack-IfTracked "credentials.json"
Untrack-IfTracked "service_account.json"
Untrack-IfTracked ".DS_Store"

# 5) Stage and commit (if needed)
Write-Host "Stage changes (including new files) ..."
Exec "git add -A" | Out-Null
$staged = (Exec "git diff --cached --name-only" -Quiet | Out-String).Trim()

if (-not $NoCommit) {
  if (-not [string]::IsNullOrWhiteSpace($staged)) {
    if ($createdGitAttr) {
      Write-Host "Commit will include .gitattributes and renormalized files."
    }
    Write-Host ("Commit with message: " + $CommitMsg)
    Exec ("git commit -m ""{0}""" -f $CommitMsg) | Out-Null
  } else {
    Write-Host "No staged changes to commit."
  }
} else {
  Write-Host "Skip commit step (--NoCommit)."
}

# 6) Push (if allowed)
if (-not $NoPush) {
  Write-Host "Push to remote ..."
  $hasRemote = $true
  try {
    $null = Exec ("git remote get-url {0}" -f $Remote) -Quiet
  } catch {
    $hasRemote = $false
  }

  if (-not $hasRemote) {
    if (-not [string]::IsNullOrWhiteSpace($RemoteUrl)) {
      Exec ("git remote add {0} {1}" -f $Remote, $RemoteUrl) | Out-Null
    } else {
      Write-Host ("Remote '{0}' not configured. Set it with: git remote add {0} <url>" -f $Remote)
      throw "Cannot push without a configured remote."
    }
  }

  $hasUpstream = $true
  try {
    Exec "git rev-parse --abbrev-ref --symbolic-full-name @{u}" -Quiet | Out-Null
  } catch {
    $hasUpstream = $false
  }

  if ($hasUpstream) {
    Run-Push ("push {0} {1}" -f $Remote, $Branch)
  } else {
    Run-Push ("push -u {0} {1}" -f $Remote, $Branch)
  }
  Write-Host "Done."
} else {
  Write-Host "Skip push step (--NoPush)."
}

# 7) Short status
Write-Host ""
Write-Host "Short status:"
Exec "git status -sb"
