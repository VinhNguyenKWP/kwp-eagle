param(
  [string]$m = "kwp_eagle: update",
  [string]$remote = "origin",
  [string]$branch = ""     # để trống sẽ tự lấy
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Helper ngắn: gọi git với mảng tham số và fail nếu lỗi
function G { param([string[]]$a) & git @a; if ($LASTEXITCODE -ne 0) { throw "git $($a -join ' ') failed ($LASTEXITCODE)" } }

# 0) Kiểm tra git và repo
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git chưa cài hoặc không có trong PATH." }
& git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { throw "Thư mục hiện tại không phải git repo." }

# 1) Xác định branch
if ([string]::IsNullOrWhiteSpace($branch)) {
  $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
  if ($branch -eq "HEAD") { throw "Đang ở DETACHED HEAD. Hãy checkout một branch trước." }
}

# 2) Add & commit nếu có thay đổi
G @("add","-A")
$staged = (& git diff --cached --name-only)
if ($staged) {
  G @("commit","-m",$m)
} else {
  Write-Host "Không có thay đổi để commit."
}

# 3) Push (tự set upstream nếu cần)
& git rev-parse --abbrev-ref --symbolic-full-name "@{u}" *> $null
if ($LASTEXITCODE -eq 0) {
  G @("push")
} else {
  G @("push","-u",$remote,$branch)
}

Write-Host ("✅ Done: {0} -> {1}" -f $branch, $remote)
