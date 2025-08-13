param(
  [string]$CommitMsg = "kwp_eagle: Update code",
  [switch]$NoCommit,      # only push if you already have commits
  [switch]$NoPush,        # do clean + commit only, no push
  [string]$Remote = "origin",
  [string]$Branch = ""    # empty -> auto-detect current branch
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Exec($cmd, [switch]$Quiet) {
  if (-not $Quiet) { Write-Host ("> " + $cmd) -ForegroundColor DarkGray }
  $out = Invoke-Expression $cmd 2>&1
  if ($LASTEXITCODE -ne 0) { throw ($out | Out-String) }
  return $out
}

# 0) Check git & repo
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "Git is not installed or not found in PATH. Please install Git for Windows and restart VS Code."
}
Exec "git --version" -Quiet | Out-Null

$inside = (Exec "git rev-parse --is-inside-work-tree" -Quiet | Out-String).Trim()
if ($inside -ne "true") { throw "Current directory is not a Git repository." }

# 1) Detect branch
if ([string]::IsNullOrWhiteSpace($Branch)) {
  $Branch = (Exec "git rev-parse --abbrev-ref HEAD" -Quiet | Out-String).Trim()
  if ($Branch -eq "HEAD") { throw "Repository is in DETACHED HEAD state. Please checkout a branch first." }
}

# 2) Update .gitignore safely
if (-not (Test-Path .gitignore)) { New-Item -ItemType File -Path .gitignore -Force | Out-Null }
function Add-GitignoreLine([string]$Line) {
  if (-not (Select-String -Path .gitignore -Pattern "^\Q$Line\E$" -SimpleMatch -Quiet)) {
    Add-Content -Path .gitignore -Value $Line
  }
}
Write-Host "Clean and update .gitignore ..."
$patterns = @(
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
$patterns | ForEach-Object { Add-GitignoreLine $_ }

# 3) Untrack previously added junk (ignore errors if files do not exist)
try {
  & git rm -r --cached .venv/ __pycache__/ .pytest_cache/ build/ dist/ 2>$null
  & git rm --cached .env .env.* token.json credentials.json service_account.json .DS_Store 2>$null
} catch { }

# 4) Add & Commit if needed
Write-Host "Stage changes (including new files) ..."
Exec "git add -A" | Out-Null
$staged = (Exec "git diff --cached --name-only" -Quiet | Out-String).Trim()

if (-not $NoCommit) {
  if (-not [string]::IsNullOrWhiteSpace($staged)) {
    Write-Host ("Commit with message: " + $CommitMsg)
    Exec ("git commit -m ""{0}""" -f $CommitMsg) | Out-Null
  } else {
    Write-Host "No staged changes to commit."
  }
} else {
  Write-Host "Skip commit step (--NoCommit)."
}

# 5) Push if allowed
if (-not $NoPush) {
  Write-Host "Push to remote ..."
  try {
    $null = Exec "git remote get-url $Remote" -Quiet
  } catch {
    Write-Host ("Remote '" + $Remote + "' is not configured.")
    Write-Host ("Add it with: git remote add " + $Remote + " https://github.com/<user>/<repo>.git")
    throw
  }

  try {
    # Has upstream?
    Exec "git rev-parse --abbrev-ref --symbolic-full-name @{u}" -Quiet | Out-Null
    Exec "git push $Remote $Branch" | Out-Null
  } catch {
    Exec "git push -u $Remote $Branch" | Out-Null
  }

  Write-Host "Done."
} else {
  Write-Host "Skip push step (--NoPush)."
}

# 6) Short status
Write-Host ""
Write-Host "Short status:"
Exec "git status -sb"
