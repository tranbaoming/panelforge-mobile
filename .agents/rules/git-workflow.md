---
trigger: always_on
---
# Git Branch & Multi-Agent Workflow — PanelForge Mobile (`baominh`)

Áp dụng cho mọi agent làm việc trong repo này (Antigravity / agy, Claude Code, ...). Bản giống hệt nằm ở mục "Git workflow" của `CLAUDE.md`.

## Nhánh
- **Nhánh làm việc: `baominh`.** Mọi thay đổi đi vào `baominh`; không commit thẳng lên `main`.
- `main` chỉ nhận code qua merge từ `baominh` sau khi task xong và đã kiểm tra.

## Một agent
- Làm trực tiếp trên `baominh`: `git checkout baominh && git pull --ff-only origin baominh`.

## Nhiều agent (multi-agent / subagent / session song song)
- Mỗi agent làm việc **tách biệt trong git worktree riêng**, tách nhánh con từ `baominh`:
  - `git worktree add ../.worktrees/panelforge-mobile-<task> -b baominh-<task> baominh`
- Mỗi agent chỉ sửa file thuộc task của mình; hai agent không sửa cùng một file.
- Không agent nào sửa working tree chính khi agent khác đang chạy.

## Xong mỗi task
1. Kiểm tra: `flutter analyze` (0 issue) và `flutter test` (tất cả pass).
2. Commit (Conventional Commits: `<type>(<scope>): <mô tả>`, ví dụ `feat(mobile): ...`).
3. Nếu làm trong worktree: `git checkout baominh && git merge --no-ff baominh-<task>`, giải quyết conflict, chạy lại analyze + test.
4. `git push origin baominh`.
5. Merge vào `main`:
   - `git checkout main && git pull --ff-only origin main`
   - `git merge --no-ff baominh` → chạy lại `flutter analyze` + `flutter test`
   - `git push origin main`
   - `git checkout baominh` (quay lại nhánh làm việc).
6. Dọn worktree (nếu có): `git worktree remove ../.worktrees/panelforge-mobile-<task>` và `git branch -d baominh-<task>`.

## Cấm
- Không force-push, không rebase lại lịch sử đã push trên `baominh` / `main`.
- Không dùng `--no-verify`.
- Không push khi analyze còn lỗi hoặc test còn fail.
