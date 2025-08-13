param(
  [string]$remote = "origin",
  [string]$branch = ""   # de trong se tu lay
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function G { param([string[]]$a) & git @a; if ($LASTEXITCODE -ne 0) { throw "git $($a -join ' ') failed ($LASTEXITCODE)" } }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git chua cai hoac khong co trong PATH." }
& git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { throw "Thu muc hien tai khong phai git repo. Dung: git clone <url>" }

if ([string]::IsNullOrWhiteSpace($branch)) {
  $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
  if ($branch -eq "HEAD") { throw "Dang o DETACHED HEAD. Vui long checkout mot branch truoc." }
}

# Stash neu co thay doi local
$dirty = (& git status --porcelain)
if ($dirty) {
  Write-Host "Stashing local changes ..."
  G @("stash","push","-u","-m","auto: pull.ps1")
}

# Dam bao co upstream
& git rev-parse --abbrev-ref --symbolic-full-name "@{u}" *> $null
if ($LASTEXITCODE -ne 0) { G @("branch","--set-upstream-to",$remote + "/" + $branch,$branch) }

G @("fetch","--prune",$remote)
G @("pull","--rebase",$remote,$branch)

Write-Host "Done. Neu ban da stash, xem: git stash list  (pop lai: git stash pop)"
